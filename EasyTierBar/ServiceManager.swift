import Foundation
import os.log

private let log = OSLog(subsystem: "com.easytier.bar", category: "ServiceManager")

class ServiceManager {
    static let shared = ServiceManager()

    let cliPath: String?
    let corePath: String?
    private(set) var isRunning = false
    private(set) var lastError: String?
    var onStatusChanged: ((Bool) -> Void)?

    private let launchdLabel = "com.easytier.core"
    private let launchdPlistPath = "/Library/LaunchDaemons/com.easytier.core.plist"

    private init() {
        cliPath = Bundle.main.path(forResource: "easytier-cli", ofType: nil)
        corePath = Bundle.main.path(forResource: "easytier-core", ofType: nil)
        os_log("init: cliPath=%{public}@, corePath=%{public}@", log: log, type: .info,
               cliPath ?? "nil", corePath ?? "nil")
    }

    var isReady: Bool { corePath != nil }

    // MARK: - Status Check (Async)

    func checkStatus(completion: @escaping (Bool) -> Void = { _ in }) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let running = self?.isProcessRunning() ?? false
            os_log("checkStatus: running=%{public}@", log: log, type: .info, String(running))
            DispatchQueue.main.async {
                self?.isRunning = running
                self?.onStatusChanged?(running)
                completion(running)
            }
        }
    }

    // MARK: - Start

    func startService(configUrl: String, completion: @escaping (Bool) -> Void = { _ in }) {
        guard let core = corePath else { completion(false); return }
        lastError = nil
        os_log("startService: configUrl=%{public}@", log: log, type: .info, configUrl)

        // 1. Write launchd plist to temp file (no sudo needed)
        let tmpPlist = "/tmp/\(launchdLabel).plist"
        let plistXML = generatePlist(corePath: core, configUrl: configUrl)
        do {
            try plistXML.write(toFile: tmpPlist, atomically: true, encoding: .utf8)
        } catch {
            let msg = "写入临时 plist 失败: \(error.localizedDescription)"
            lastError = msg
            os_log("startService: %{public}@", log: log, type: .error, msg)
            completion(false)
            return
        }

        // 2. Single sudo command: kill old process -> unload old -> copy plist -> load new
        let cmd = "pkill -x easytier-core 2>/dev/null; launchctl unload '\(launchdPlistPath)' 2>/dev/null; cp '\(tmpPlist)' '\(launchdPlistPath)' && launchctl load -w '\(launchdPlistPath)'"
        os_log("startService: cmd=%{public}@", log: log, type: .info, cmd)
        let (ok, err) = runAppleScriptSudo(command: cmd)
        os_log("startService: ok=%{public}@, err=%{public}@", log: log, type: .info,
               String(ok), err ?? "nil")

        if ok {
            // Verify process started after brief delay
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.5) { [weak self] in
                let running = self?.isProcessRunning() ?? false
                os_log("startService: verified running=%{public}@", log: log, type: .info, String(running))
                DispatchQueue.main.async {
                    self?.isRunning = running
                    self?.onStatusChanged?(running)
                    if !running {
                        self?.lastError = "服务已加载但进程未启动，请检查 /tmp/easytier-core.log"
                    }
                    completion(running)
                }
            }
        } else {
            lastError = err
            completion(false)
        }
    }

    // MARK: - Stop

    func stopService(completion: @escaping (Bool) -> Void = { _ in }) {
        lastError = nil
        let cmd = "launchctl unload '\(launchdPlistPath)' 2>/dev/null; rm -f '\(launchdPlistPath)'; pkill -x easytier-core 2>/dev/null; true"
        os_log("stopService: cmd=%{public}@", log: log, type: .info, cmd)
        let (ok, err) = runAppleScriptSudo(command: cmd)
        os_log("stopService: ok=%{public}@, err=%{public}@", log: log, type: .info,
               String(ok), err ?? "nil")

        if ok {
            isRunning = false
            onStatusChanged?(false)
            completion(true)
        } else {
            // AppleScript failed (user cancelled auth or error)
            // Check if process is already stopped regardless
            if !isProcessRunning() {
                isRunning = false
                onStatusChanged?(false)
                completion(true)
            } else {
                lastError = err ?? "无法停止服务"
                completion(false)
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

    private func isProcessRunning() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-x", "easytier-core"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    private func generatePlist(corePath: String, configUrl: String) -> String {
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
                <string>-w</string>
                <string>\(esc(configUrl))</string>
            </array>
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
