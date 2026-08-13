import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let mainMenu = NSMenu()
    let peerMenu = NSMenu()

    private var statusMenuItem: NSMenuItem!
    private var daemonActionItem: NSMenuItem!
    private var webConsoleItem: NSMenuItem!
    private var restartItem: NSMenuItem!
    private var statusTimer: Timer?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ServiceManager.shared.isReady else {
            showAlert(title: "组件缺失",
                      message: "easytier-core / easytier-cli 未找到，请确保它们在应用包 Resources 目录中。")
            NSApplication.shared.terminate(nil)
            return
        }

        removeQuarantineIfNeeded()
        buildMenu()

        ServiceManager.shared.onStatusChanged = { [weak self] status in
            self?.applyStatus(status)
            if status == .running { self?.updatePeerList() }
        }
        ConfigManager.shared.onConfigChanged = { [weak self] in
            self?.refreshStatus()
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(menuWillOpen),
            name: NSMenu.didBeginTrackingNotification, object: mainMenu)

        // 首次启动必须先配置配置中心地址
        if !ConfigManager.shared.hasCenter {
            if let cfg = runCenterDialog(isFirstLaunch: true) {
                ConfigManager.shared.saveCenter(cfg)
            } else {
                NSApplication.shared.terminate(nil)
                return
            }
        }

        refreshStatus()
        updatePeerList()

        // 每 60 秒自动刷新状态，避免长时间不打开菜单导致状态冻结（如挂机一晚）
        statusTimer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshStatus()
        }
        if let timer = statusTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    // MARK: - Menu Building

    private func buildMenu() {
        statusMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        mainMenu.addItem(statusMenuItem)

        mainMenu.addItem(NSMenuItem.separator())

        let peersItem = NSMenuItem(title: "已连接节点", action: nil, keyEquivalent: "")
        peersItem.submenu = peerMenu
        mainMenu.addItem(peersItem)

        mainMenu.addItem(NSMenuItem.separator())

        let refreshItem = mainMenu.addItem(
            withTitle: "刷新状态", action: #selector(refreshAction), keyEquivalent: "r")
        refreshItem.target = self

        webConsoleItem = mainMenu.addItem(
            withTitle: "打开 Web 控制台", action: #selector(openWebConsole), keyEquivalent: "")
        webConsoleItem.target = self

        mainMenu.addItem(NSMenuItem.separator())

        daemonActionItem = mainMenu.addItem(
            withTitle: "安装守护进程", action: #selector(toggleDaemon), keyEquivalent: "")
        daemonActionItem.target = self

        restartItem = mainMenu.addItem(
            withTitle: "重启守护进程", action: #selector(restartAction), keyEquivalent: "")
        restartItem.target = self

        let editItem = mainMenu.addItem(
            withTitle: "配置中心设置...", action: #selector(editCenterConfig), keyEquivalent: "")
        editItem.target = self

        mainMenu.addItem(NSMenuItem.separator())

        let aboutItem = mainMenu.addItem(
            withTitle: "关于", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self

        mainMenu.addItem(NSMenuItem.separator())

        let quitItem = mainMenu.addItem(
            withTitle: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self

        statusItem.menu = mainMenu
    }

    // MARK: - Status

    private func refreshStatus() {
        ServiceManager.shared.checkStatus()
    }

    private func applyStatus(_ status: ServiceManager.DaemonStatus) {
        let symbolName: String, tint: NSColor, statusText: String, daemonTitle: String
        switch status {
        case .running:
            symbolName = "antenna.radiowaves.left.and.right"
            tint = .systemGreen
            statusText = "● 运行中"
            daemonTitle = "卸载守护进程"
        case .noNetwork:
            symbolName = "antenna.radiowaves.left.and.right.slash"
            tint = .systemOrange
            statusText = "● 守护进程运行中，未连通网络"
            daemonTitle = "卸载守护进程"
        case .installedNotReachable:
            symbolName = "antenna.radiowaves.left.and.right.slash"
            tint = .systemYellow
            statusText = "○ 守护进程未响应，启动中…"
            daemonTitle = "重新安装守护进程"
        case .notInstalled:
            symbolName = "antenna.radiowaves.left.and.right.slash"
            tint = .secondaryLabelColor
            statusText = ConfigManager.shared.hasCenter ? "⚠ 未安装守护进程" : "⚠ 未配置，请先设置配置中心"
            daemonTitle = ConfigManager.shared.hasCenter ? "安装守护进程" : "安装守护进程（请先配置）"
        }
        statusItem.button?.image = NSImage(
            systemSymbolName: symbolName, accessibilityDescription: "EasyTier")
        statusItem.button?.contentTintColor = tint
        statusMenuItem.title = statusText
        daemonActionItem.title = daemonTitle
        restartItem.isEnabled = status != .notInstalled
        // Web 控制台仅在地址有效时可点
        webConsoleItem.isEnabled =
            ConfigManager.shared.center?.webConsoleUrl.isEmpty == false
    }

    @objc private func menuWillOpen() {
        refreshStatus()
        updatePeerList()
    }

    private func updatePeerList() {
        peerMenu.removeAllItems()

        guard ServiceManager.shared.isDaemonInstalled() else {
            addPeerPlaceholder("(守护进程未安装)")
            return
        }

        ServiceManager.shared.fetchPeerList { [weak self] peers in
            guard let self = self else { return }
            self.peerMenu.removeAllItems()
            if let peers = peers, !peers.isEmpty {
                for peer in peers {
                    let item = NSMenuItem(title: peer.displayTitle, action: nil, keyEquivalent: "")
                    self.peerMenu.addItem(item)
                }
            } else {
                let title = peers == nil ? "(获取节点列表失败)" : "(无已连接节点)"
                self.addPeerPlaceholder(title)
            }
        }
    }

    private func addPeerPlaceholder(_ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        peerMenu.addItem(item)
    }

    // MARK: - Daemon Install / Uninstall (one-time sudo)

    @objc private func toggleDaemon() {
        if ServiceManager.shared.isDaemonInstalled() {
            confirmUninstall()
        } else {
            confirmInstall()
        }
    }

    private func confirmInstall() {
        guard let center = ConfigManager.shared.center else {
            showAlert(title: "未配置", message: "请先在「配置中心设置」中填写配置中心地址。")
            return
        }
        let alert = NSAlert()
        alert.messageText = "安装守护进程"
        alert.informativeText =
            "将创建系统级 LaunchDaemon 并立即启动，连接配置中心：\n\(center.configServerUrl)\n\n接下来会弹出系统密码框（仅此一次）。"
        alert.addButton(withTitle: "安装")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        daemonActionItem.isEnabled = false
        daemonActionItem.title = "正在安装…"
        ServiceManager.shared.installDaemon { [weak self] ok in
            self?.daemonActionItem.isEnabled = true
            if !ok {
                self?.showAlert(title: "安装失败",
                                message: ServiceManager.shared.lastError ?? "未知错误")
            }
            self?.refreshStatus()
        }
    }

    private func confirmUninstall() {
        let alert = NSAlert()
        alert.messageText = "卸载守护进程"
        alert.informativeText = "将停止 easytier-core 并移除 LaunchDaemon。"
        alert.addButton(withTitle: "卸载")
        alert.addButton(withTitle: "取消")

        let purgeCheckbox = NSButton(
            checkboxWithTitle: "同时清除本地网络配置（config-dir）", target: nil, action: nil)
        alert.accessoryView = purgeCheckbox

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        daemonActionItem.isEnabled = false
        daemonActionItem.title = "正在卸载…"
        ServiceManager.shared.uninstallDaemon(removeConfigs: purgeCheckbox.state == .on) { [weak self] ok in
            self?.daemonActionItem.isEnabled = true
            if !ok {
                self?.showAlert(title: "卸载失败",
                                message: ServiceManager.shared.lastError ?? "未知错误")
            }
            self?.refreshStatus()
        }
    }

    // MARK: - Refresh / Restart

    @objc private func refreshAction() {
        refreshStatus()
        updatePeerList()
    }

    @objc private func restartAction() {
        let alert = NSAlert()
        alert.messageText = "重启守护进程"
        alert.informativeText =
            "将重启 easytier-core 进程（保留配置），让它重新连接配置中心与对端。\n适用于网络卡死、配置中心失联等场景。\n会弹出系统密码框。"
        alert.addButton(withTitle: "重启")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        restartItem.isEnabled = false
        restartItem.title = "正在重启…"
        ServiceManager.shared.restartDaemon { [weak self] ok in
            self?.restartItem.isEnabled = true
            self?.restartItem.title = "重启守护进程"
            if !ok {
                self?.showAlert(title: "重启失败",
                                message: ServiceManager.shared.lastError ?? "未知错误")
            }
            self?.refreshStatus()
        }
    }

    // MARK: - Web Console

    @objc private func openWebConsole() {
        guard let urlStr = ConfigManager.shared.center?.webConsoleUrl,
              !urlStr.isEmpty,
              let url = URL(string: urlStr) else {
            showAlert(title: "未配置", message: "请先在「配置中心设置」中填写 Web 控制台地址。")
            return
        }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Center Config

    @objc private func editCenterConfig() {
        let wasInstalled = ServiceManager.shared.isDaemonInstalled()
        let old = ConfigManager.shared.center
        guard let cfg = runCenterDialog(isFirstLaunch: false) else { return }
        ConfigManager.shared.saveCenter(cfg)

        // 地址变更且守护进程已装：需要重装才生效
        if wasInstalled && old != cfg {
            let alert = NSAlert()
            alert.messageText = "地址已变更"
            alert.informativeText = "配置变更需要重新安装守护进程才能生效（会弹出系统密码框）。现在重装吗？"
            alert.addButton(withTitle: "立即重装")
            alert.addButton(withTitle: "稍后")
            if alert.runModal() == .alertFirstButtonReturn {
                daemonActionItem.isEnabled = false
                daemonActionItem.title = "正在重装…"
                ServiceManager.shared.installDaemon { [weak self] _ in
                    self?.daemonActionItem.isEnabled = true
                    self?.refreshStatus()
                }
            }
        }
    }

    /// 弹出配置中心设置对话框。返回用户填写的配置；nil 表示取消。
    private func runCenterDialog(isFirstLaunch: Bool) -> CenterConfig? {
        let alert = NSAlert()
        alert.messageText = isFirstLaunch ? "欢迎使用 EasyTierBar" : "配置中心设置"
        alert.informativeText =
            "配置中心地址用于 core 连接（-w）；Web 控制台地址用浏览器打开。二者协议/端口可能不同。"

        let serverField = NSTextField()
        serverField.placeholderString = "udp://host:port/user"
        serverField.stringValue = ConfigManager.shared.center?.configServerUrl ?? ""
        let webField = NSTextField()
        webField.placeholderString = "https://host"
        webField.stringValue = ConfigManager.shared.center?.webConsoleUrl ?? ""

        let stack = NSStackView(views: [
            makeRow(label: "配置中心地址", field: serverField),
            makeRow(label: "Web 控制台", field: webField),
        ])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.frame = NSRect(x: 0, y: 0, width: 360, height: 64)
        alert.accessoryView = stack

        alert.addButton(withTitle: "保存")
        if !isFirstLaunch { alert.addButton(withTitle: "取消") }

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }

        let server = serverField.stringValue.trimmingCharacters(in: .whitespaces)
        let web = webField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !server.isEmpty, !web.isEmpty else {
            showAlert(title: "输入无效", message: "配置中心地址和 Web 控制台地址都不能为空。")
            return runCenterDialog(isFirstLaunch: isFirstLaunch)
        }
        return CenterConfig(configServerUrl: server, webConsoleUrl: web)
    }

    private func makeRow(label text: String, field: NSTextField) -> NSView {
        let l = NSTextField(labelWithString: text)
        l.alignment = .right
        l.textColor = .secondaryLabelColor
        let row = NSStackView(views: [l, field])
        row.orientation = .horizontal
        row.spacing = 8
        l.widthAnchor.constraint(equalToConstant: 96).isActive = true
        field.widthAnchor.constraint(equalToConstant: 240).isActive = true
        return row
    }

    // MARK: - About & Quit

    @objc private func showAbout() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let alert = NSAlert()
        alert.messageText = "EasyTierBar v\(version)"
        alert.informativeText = "macOS 菜单栏看护工具 for EasyTier（Web-Managed 模式）"
        alert.runModal()
    }

    @objc private func quit() {
        // daemon 常驻，退出 app 不影响网络。
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Helpers

    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

    /// Remove macOS quarantine (com.apple.quarantine) from bundled binaries.
    /// Downloaded zip archives cause Gatekeeper to block execution.
    private func removeQuarantineIfNeeded() {
        guard let resourcePath = Bundle.main.resourcePath else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        process.arguments = ["-cr", resourcePath]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }
}
