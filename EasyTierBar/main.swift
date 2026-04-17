import Cocoa

let binaryPath = "/Users/zhaolulu/开发/easytier-macos-aarch64/easytier-core"
let workingDir = "/Users/zhaolulu/开发/easytier-macos-aarch64"
let connectArgs = "-w udp://111.170.131.76:22020/zhaolulu"

class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var process: Process?
    var isRunning = false
    let menu = NSMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let toggleItem = menu.addItem(
            withTitle: "启动 EasyTier", action: #selector(toggleService), keyEquivalent: "t")
        toggleItem.target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            withTitle: "退出", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
        checkStatus()
    }

    func updateUI() {
        let imageName = isRunning
            ? "antenna.radiowaves.left.and.right"
            : "antenna.radiowaves.left.and.right.slash"
        statusItem.button?.image = NSImage(
            systemSymbolName: imageName, accessibilityDescription: "EasyTier")
        if let item = menu.items.first {
            item.title = isRunning ? "停止 EasyTier" : "启动 EasyTier"
        }
    }

    @objc func toggleService() {
        isRunning ? stopService() : startService()
    }

    func startService() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        p.arguments = [binaryPath] + connectArgs.split(separator: " ").map(String.init)
        p.currentDirectoryURL = URL(fileURLWithPath: workingDir)
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
            process = p
            isRunning = true
            updateUI()
        } catch {
            showAlert(title: "启动失败", message: error.localizedDescription)
        }
    }

    func stopService() {
        let kill = Process()
        kill.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        kill.arguments = ["pkill", "-f", "easytier-core"]
        kill.standardOutput = FileHandle.nullDevice
        kill.standardError = FileHandle.nullDevice
        try? kill.run()
        kill.waitUntilExit()
        process?.terminate()
        process = nil
        isRunning = false
        updateUI()
    }

    func checkStatus() {
        let check = Process()
        check.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        check.arguments = ["-x", "easytier-core"]
        check.standardOutput = FileHandle.nullDevice
        check.standardError = FileHandle.nullDevice
        try? check.run()
        check.waitUntilExit()
        isRunning = check.terminationStatus == 0
        updateUI()
    }

    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

    @objc func quit() {
        if isRunning { stopService() }
        NSApplication.shared.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
