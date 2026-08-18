import Foundation
import os.log

private let log = OSLog(subsystem: "com.easytier.bar", category: "ServiceManager")

class ServiceManager {
    static let shared = ServiceManager()

    let cliPath: String?
    let corePath: String?
    private(set) var lastError: String?
    var onStatusChanged: ((DaemonStatus) -> Void)?

    /// 守护进程标识（launchd Label）。与 app 的 bundle id (com.easytier.menubar) 故意不同：
    /// 一个标识菜单栏 app，一个标识系统级 LaunchDaemon，二者职责分离。
    private let launchdLabel = "com.easytier.core"
    private let launchdPlistPath = "/Library/LaunchDaemons/com.easytier.core.plist"
    /// daemon 的 HOME 目录。launchd 启动的系统服务默认无 HOME 环境变量，
    /// 而 core 解析 machine-id state 目录依赖 HOME（config-server 模式必需），故显式设置。
    private let daemonHome = "/Library/Application Support/EasyTierBar"
    /// daemon 持久化网络配置的目录（由 web 配置中心下发的 .toml 存于此）。
    private let configDir = "/Library/Application Support/EasyTierBar/configs"
    /// sudoers 免密规则文件：允许当前用户免密执行对本 plist 的 launchctl load/unload，
    /// 使日常「启动/停止 VPN」无需每次弹管理员密码（安装时随 daemon 一并写入）。
    private let sudoersPath = "/etc/sudoers.d/easytierbar"

    private init() {
        cliPath = Bundle.main.path(forResource: "easytier-cli", ofType: nil)
        corePath = Bundle.main.path(forResource: "easytier-core", ofType: nil)
        os_log("init: cliPath=%{public}@, corePath=%{public}@", log: log, type: .info,
               cliPath ?? "nil", corePath ?? "nil")
    }

    var isReady: Bool { corePath != nil && cliPath != nil }

    // MARK: - Daemon Status

    enum DaemonStatus {
        case notInstalled
        case stopped               // 已安装但未运行（stopVPN 后；重启电脑会自动恢复）
        case installedNotReachable
        case noNetwork      // RPC 可达但无对端 peer（core 活着，网络层未连通）
        case running
    }

    /// 综合状态：plist 是否安装 + core RPC 是否可达。
    func checkStatus(completion: @escaping (DaemonStatus) -> Void = { _ in }) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let status: DaemonStatus
            if !self.isDaemonInstalled() {
                status = .notInstalled
            } else if !self.isCoreRunningSync() {
                status = .stopped
            } else if !self.coreReachableSync() {
                status = .installedNotReachable
            } else {
                // RPC 可达：再看是否有对端 peer（本机之外的节点），
                // 否则只是 core 进程活着、网络层实际未连通。
                status = self.hasPeerSync() ? .running : .noNetwork
            }
            os_log("checkStatus: %{public}@", log: log, type: .info, String(describing: status))
            DispatchQueue.main.async {
                self.onStatusChanged?(status)
                completion(status)
            }
        }
    }

    /// 检查 plist 是否存在（普通用户可读，无密码）。
    func isDaemonInstalled() -> Bool {
        FileManager.default.fileExists(atPath: launchdPlistPath)
    }

    /// 同步测试 core RPC 可达性（跑 `easytier-cli node info`，退出码 0 即可达）。
    /// 必须在后台队列调用。
    private func coreReachableSync() -> Bool {
        guard let path = cliPath else { return false }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["-o", "json", "node", "info"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// 进程是否在跑（供 UI 判断 stopped 展示）。pgrep 很轻量，可在主线程调用。
    func isCoreRunning() -> Bool { isCoreRunningSync() }

    /// 同步检测 core 进程是否在跑（pgrep）。安装时用：core 刚启动、RPC 尚未监听，
    /// 只要进程在即视为守护进程已成功拉起。
    private func isCoreRunningSync() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-x", "easytier-core"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    /// 同步检测是否有对端 peer（本机之外）。RPC 可达但无 peer，说明 core 活着但
    /// 网络层未连通（如配置中心 session 断开、对端全失联）。必须在后台队列调用。
    private func hasPeerSync() -> Bool {
        guard let path = cliPath else { return false }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["-o", "json", "peer", "list"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return false }
            let data = try pipe.fileHandleForReading.readToEnd() ?? Data()
            // peer 列表含本机（cost=Local），数组长度 > 1 表示还有其他 peer
            guard let peers = try? JSONDecoder().decode([Peer].self, from: data) else { return false }
            return peers.count > 1
        } catch {
            return false
        }
    }

    // MARK: - Install / Uninstall (one-time, sudo)

    func installDaemon(completion: @escaping (Bool) -> Void = { _ in }) {
        guard let core = corePath else { completion(false); return }
        guard let center = ConfigManager.shared.center else {
            lastError = "未配置配置中心地址"
            completion(false)
            return
        }
        lastError = nil
        os_log("installDaemon: configServerUrl=%{public}@", log: log, type: .info, center.configServerUrl)

        let tmpPlist = "/tmp/\(launchdLabel).plist"
        let plistXML = generatePlist(corePath: core, configServerUrl: center.configServerUrl)
        do {
            try plistXML.write(toFile: tmpPlist, atomically: true, encoding: .utf8)
        } catch {
            let msg = "写入临时 plist 失败: \(error.localizedDescription)"
            lastError = msg
            os_log("installDaemon: %{public}@", log: log, type: .error, msg)
            completion(false)
            return
        }

        // 一次性 sudo：清手动 core -> 建配置目录 -> 卸载旧的 -> 拷贝新 plist -> 加载
        //            -> 写 sudoers 免密规则（visudo 校验通过才安装，日常启停 VPN 免密）
        let cmd = "pkill -x easytier-core 2>/dev/null; mkdir -p '\(configDir)'; launchctl unload '\(launchdPlistPath)' 2>/dev/null; cp '\(tmpPlist)' '\(launchdPlistPath)' && launchctl load -w '\(launchdPlistPath)' && printf '%s\\n' '\(sudoersContent())' > /tmp/easytierbar.sudoers && /usr/sbin/visudo -cf /tmp/easytierbar.sudoers && cp /tmp/easytierbar.sudoers \(sudoersPath) && chmod 0440 \(sudoersPath) && rm -f /tmp/easytierbar.sudoers"
        os_log("installDaemon: cmd=%{public}@", log: log, type: .info, cmd)
        let (ok, err) = runAppleScriptSudo(command: cmd)

        guard ok else {
            lastError = err
            completion(false)
            return
        }

        // 等待 core 进程启动（load 后启动需几秒），进程在跑即视为安装成功。
        // config-server 模式下 core 需先连上配置中心才监听 RPC，故安装成功不以 RPC 可达为标准；
        // RPC 与配置中心连接状态由状态栏三态体现。
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var running = false
            for _ in 0..<10 {
                Thread.sleep(forTimeInterval: 1.0)
                if self?.isCoreRunningSync() == true { running = true; break }
            }
            DispatchQueue.main.async {
                if !running {
                    self?.lastError = "守护进程加载后进程未启动，请检查 /tmp/easytier-core.log"
                }
                completion(running)
            }
        }
    }

    func uninstallDaemon(removeConfigs: Bool, completion: @escaping (Bool) -> Void = { _ in }) {
        lastError = nil
        let rmConfigs = removeConfigs ? "; rm -rf '\(configDir)'" : ""
        let cmd = "launchctl unload '\(launchdPlistPath)' 2>/dev/null; rm -f '\(launchdPlistPath)' \(sudoersPath); pkill -x easytier-core 2>/dev/null; true\(rmConfigs)"
        os_log("uninstallDaemon: cmd=%{public}@, removeConfigs=%{public}@", log: log, type: .info, cmd, String(removeConfigs))
        let (ok, err) = runAppleScriptSudo(command: cmd)
        if ok {
            completion(true)
        } else if !isDaemonInstalled() {
            // AppleScript 失败（用户取消或出错）但 plist 已不在，视为成功
            completion(true)
        } else {
            lastError = err ?? "无法卸载守护进程"
            completion(false)
        }
    }

    /// 重启守护进程（保留配置，只重启 core 进程）。用于网络层卡死、配置中心
    /// session 失联等场景——重启后 core 会重新连配置中心、重新协商 peer。
    /// 走 AppleScript sudo（system domain 的 kickstart 需要 root）。
    func restartDaemon(completion: @escaping (Bool) -> Void = { _ in }) {
        guard isDaemonInstalled() else {
            lastError = "守护进程未安装"
            completion(false)
            return
        }
        lastError = nil
        let cmd = "launchctl kickstart -k system/\(launchdLabel)"
        os_log("restartDaemon: cmd=%{public}@", log: log, type: .info, cmd)
        let (ok, err) = runAppleScriptSudo(command: cmd)
        guard ok else {
            lastError = err
            completion(false)
            return
        }
        // 轮询等待 core 重启后 RPC 恢复（重启需几秒）
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var reachable = false
            for _ in 0..<15 {
                Thread.sleep(forTimeInterval: 1.0)
                if self?.coreReachableSync() == true { reachable = true; break }
            }
            DispatchQueue.main.async {
                if !reachable {
                    self?.lastError = "守护进程重启后未响应，请检查 /tmp/easytier-core.log"
                }
                completion(reachable)
            }
        }
    }

    // MARK: - Start / Stop VPN (password-free via sudoers)

    /// sudoers 免密规则内容：仅允许当前用户免密执行对本 plist 的 launchctl load/unload。
    /// 最小授权——不能改 plist 内容、不能启停其他服务。
    private func sudoersContent() -> String {
        let user = NSUserName()
        return "\(user) ALL=(root) NOPASSWD: /bin/launchctl unload \(launchdPlistPath), /bin/launchctl load \(launchdPlistPath), /bin/launchctl load -w \(launchdPlistPath)"
    }

    /// 以 sudo -n（免密）执行命令。sudoers 规则未安装时返回 false。
    private func runSudoN(arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n"] + arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// 启动 VPN：加载 LaunchDaemon。依赖安装时写入的 sudoers 免密规则，无弹窗。
    func startVPN(completion: @escaping (Bool) -> Void = { _ in }) {
        guard isDaemonInstalled() else {
            lastError = "守护进程未安装"
            completion(false)
            return
        }
        lastError = nil
        os_log("startVPN", log: log, type: .info)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let ok = self.runSudoN(arguments: ["launchctl", "load", "-w", self.launchdPlistPath])
            guard ok else {
                DispatchQueue.main.async {
                    self.lastError = "免密规则未生效，请先「重新安装守护进程」一次（会写入启停免密规则）"
                    completion(false)
                }
                return
            }
            var reachable = false
            for _ in 0..<10 {
                Thread.sleep(forTimeInterval: 1.0)
                if self.coreReachableSync() { reachable = true; break }
            }
            DispatchQueue.main.async { completion(reachable) }
        }
    }

    /// 停止 VPN：卸载 LaunchDaemon。临时停止——重启电脑后 daemon 会自动恢复运行。免密。
    func stopVPN(completion: @escaping (Bool) -> Void = { _ in }) {
        lastError = nil
        os_log("stopVPN", log: log, type: .info)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let ok = self.runSudoN(arguments: ["launchctl", "unload", self.launchdPlistPath])
            DispatchQueue.main.async {
                if !ok {
                    self.lastError = "免密规则未生效，请先「重新安装守护进程」一次（会写入启停免密规则）"
                }
                completion(ok)
            }
        }
    }

    // MARK: - Peer List (Async)

    struct Peer: Codable {
        let hostname: String?
        let ipv4: String?
        let cost: String?
        let lat_ms: String?
        let loss_rate: String?
        let rx_bytes: String?
        let tx_bytes: String?
        let version: String?

        var displayTitle: String {
            var parts = [String]()
            if let h = hostname, !h.isEmpty { parts.append(h) }
            if let ip = ipv4, !ip.isEmpty { parts.append(ip) }
            if let c = cost, !c.isEmpty { parts.append(c) }
            if let l = lat_ms, !l.isEmpty { parts.append(l + "ms") }
            if let lr = loss_rate, !lr.isEmpty { parts.append(lr) }
            if let v = version, !v.isEmpty { parts.append("v" + v) }
            return parts.isEmpty ? "unknown" : parts.joined(separator: " \u{2022} ")
        }
    }

    func fetchPeerList(completion: @escaping ([Peer]?) -> Void) {
        guard let path = cliPath else {
            completion(nil)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = ["-o", "json", "peer", "list"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()

                guard process.terminationStatus == 0 else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }

                let data = try pipe.fileHandleForReading.readToEnd() ?? Data()
                let peers = try? JSONDecoder().decode([Peer].self, from: data)
                DispatchQueue.main.async {
                    completion(peers)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func generatePlist(corePath: String, configServerUrl: String) -> String {
        let esc = { (s: String) -> String in
            s.replacingOccurrences(of: "&", with: "&amp;")
             .replacingOccurrences(of: "<", with: "&lt;")
             .replacingOccurrences(of: ">", with: "&gt;")
             .replacingOccurrences(of: "'", with: "&apos;")
             .replacingOccurrences(of: "\"", with: "&quot;")
        }
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(launchdLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(esc(corePath))</string>
                <string>--daemon</string>
                <string>--config-dir</string>
                <string>\(esc(configDir))</string>
                <string>-w</string>
                <string>\(esc(configServerUrl))</string>
                <string>--rpc-portal</string>
                <string>127.0.0.1:15888</string>
            </array>
            <key>EnvironmentVariables</key>
            <dict>
                <key>HOME</key>
                <string>\(esc(daemonHome))</string>
            </dict>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>StandardOutPath</key>
            <string>/tmp/easytier-core.log</string>
            <key>StandardErrorPath</key>
            <string>/tmp/easytier-core.log</string>
        </dict>
        </plist>
        """
    }

    /// Execute a shell command with administrator privileges via AppleScript.
    private func runAppleScriptSudo(command: String) -> (Bool, String?) {
        let script = "do shell script \"\(command)\" with administrator privileges"
        os_log("AppleScript: %{public}@", log: log, type: .debug, script)
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)
        if let error = error {
            let msg = (error[NSAppleScript.errorMessage] as? String)
                ?? (error["NSAppleScriptErrorBriefMessage"] as? String)
                ?? "Unknown error"
            os_log("AppleScript error: %{public}@ | full: %{public}@", log: log, type: .error,
                   msg, error.description)
            return (false, msg)
        }
        return (true, nil)
    }
}
