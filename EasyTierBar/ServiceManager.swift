import Foundation

class ServiceManager {
    static let shared = ServiceManager()

    let cliPath: String?
    let corePath: String?
    private(set) var isRunning = false
    var onStatusChanged: ((Bool) -> Void)?

    private let installedConfigKey = "ETB_installedConfigUrl"

    private init() {
        cliPath = Bundle.main.path(forResource: "easytier-cli", ofType: nil)
        corePath = Bundle.main.path(forResource: "easytier-core", ofType: nil)
    }

    var isReady: Bool { cliPath != nil }

    // MARK: - Status Check (Async)

    func checkStatus(completion: @escaping (Bool) -> Void = { _ in }) {
        guard let path = cliPath else {
            applyStatus(false, completion: completion)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let output = self?.runCli(path: path, args: ["service", "status"]) ?? ""
            let running = output.lowercased().contains("running")

            DispatchQueue.main.async {
                self?.applyStatus(running, completion: completion)
            }
        }
    }

    // MARK: - Start (installs service + starts it, all with sudo)

    func startService(configUrl: String, completion: @escaping (Bool) -> Void = { _ in }) {
        guard let path = cliPath else { completion(false); return }

        // Always install with sudo first (may need uninstall too)
        if needsInstall(configUrl: configUrl) {
            guard installService(configUrl: configUrl) else {
                completion(false)
                return
            }
        }

        // Start with sudo
        let ok = runAppleScriptSudo(command: "\"\(path)\" service start")
        applyStatus(ok, completion: completion)
    }

    // MARK: - Stop (with sudo)

    func stopService(completion: @escaping (Bool) -> Void = { _ in }) {
        guard let path = cliPath else { completion(false); return }

        let ok = runAppleScriptSudo(command: "\"\(path)\" service stop")
        applyStatus(!ok, completion: completion)
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
            return parts.isEmpty ? "unknown" : parts.joined(separator: " • ")
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

    private func applyStatus(_ running: Bool, completion: (Bool) -> Void) {
        isRunning = running
        completion(running)
        onStatusChanged?(running)
    }

    private func needsInstall(configUrl: String) -> Bool {
        let saved = UserDefaults.standard.string(forKey: installedConfigKey)
        return saved != configUrl
    }

    @discardableResult
    private func installService(configUrl: String) -> Bool {
        guard let path = cliPath else { return false }

        // Uninstall existing (sudo)
        _ = runAppleScriptSudo(command: "\"\(path)\" service uninstall")

        // Install with sudo
        let cmd = "\"\(path)\" service install --disable-autostart true -w \"\(configUrl)\""
        guard runAppleScriptSudo(command: cmd) else { return false }

        UserDefaults.standard.set(configUrl, forKey: installedConfigKey)
        return true
    }

    @discardableResult
    private func runAppleScriptSudo(command: String) -> Bool {
        let script = "do shell script \"\(command)\" with administrator privileges"
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)
        return error == nil
    }

    private func runCli(path: String, args: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = try pipe.fileHandleForReading.readToEnd() ?? Data()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}
