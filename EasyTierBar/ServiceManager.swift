import Foundation

class ServiceManager {
    static let shared = ServiceManager()

    let cliPath: String?
    var isRunning = false
    var isInstalled = true
    var onStatusChanged: ((Bool) -> Void)?

    private init() {
        cliPath = Bundle.main.path(forResource: "easytier-cli", ofType: nil)
        if cliPath == nil {
            let devPath = (Bundle.main.bundlePath as NSString).deletingLastPathComponent + "/easytier-cli"
            if FileManager.default.fileExists(atPath: devPath) {
                // devPath used as fallback — only in development mode
            }
        }
    }

    var isReady: Bool {
        cliPath != nil
    }

    // MARK: - Status Check (Async)

    func checkStatus(completion: @escaping (Bool) -> Void = { _ in }) {
        guard let path = cliPath else {
            isRunning = false
            completion(false)
            onStatusChanged?(false)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = ["service", "status"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()
                let running = process.terminationStatus == 0

                DispatchQueue.main.async {
                    self?.isRunning = running
                    self?.isInstalled = true
                    completion(running)
                    self?.onStatusChanged?(running)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.isRunning = false
                    self?.isInstalled = true
                    completion(false)
                    self?.onStatusChanged?(false)
                }
            }
        }
    }

    // MARK: - Service Control (Sync)

    func startService(configUrl: String) -> Bool {
        guard let path = cliPath else { return false }

        if !isInstalled {
            if !installService(configUrl: configUrl) {
                return false
            }
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["service", "start"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let success = process.terminationStatus == 0
            if success {
                isRunning = true
                onStatusChanged?(true)
            }
            return success
        } catch {
            return false
        }
    }

    func stopService() -> Bool {
        guard let path = cliPath else { return false }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["service", "stop"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let success = process.terminationStatus == 0
            if success {
                isRunning = false
                onStatusChanged?(false)
            }
            return success
        } catch {
            return false
        }
    }

    // MARK: - Peer List (Async)

    struct Peer: Codable {
        let hostname: String
        let ipv4: String
        let cost: String
        let lat_ms: String
        let loss_rate: String
        let rx_bytes: String
        let tx_bytes: String
        let version: String
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

    // MARK: - Install (AppleScript sudo)

    @discardableResult
    func installService(configUrl: String) -> Bool {
        guard let path = cliPath else { return false }

        let command = "\"\(path)\" service install --disable-autostart true -w \"\(configUrl)\""
        let script = "do shell script \"\(command)\" with administrator privileges"

        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)

        if let _ = error {
            return false
        }

        isInstalled = true
        return true
    }
}
