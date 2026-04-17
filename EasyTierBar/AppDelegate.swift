import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let mainMenu = NSMenu()
    let configMenu = NSMenu()
    let peerMenu = NSMenu()

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ServiceManager.shared.isReady else {
            let alert = NSAlert()
            alert.messageText = "easytier-cli 未找到"
            alert.informativeText = "请确保 easytier-cli 在应用包 Resources 目录中。"
            alert.runModal()
            NSApplication.shared.terminate(nil)
            return
        }

        buildMenu()
        updateUI()

        ServiceManager.shared.onStatusChanged = { [weak self] _ in
            self?.updateUI()
        }
        ConfigManager.shared.onConfigsChanged = { [weak self] in
            self?.rebuildConfigMenu()
            self?.updateUI()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuWillOpen),
            name: NSMenu.didBeginTrackingNotification,
            object: mainMenu)

        if !ConfigManager.shared.hasConfigs {
            showAddConfigDialog(isFirstLaunch: true)
        } else {
            ServiceManager.shared.checkStatus()
            updatePeerList()
        }
    }

    // MARK: - Menu Building

    private func buildMenu() {
        let toggleItem = mainMenu.addItem(
            withTitle: "启动 EasyTier", action: #selector(toggleService), keyEquivalent: "t")
        toggleItem.target = self

        let configItem = NSMenuItem(title: "网络配置", action: nil, keyEquivalent: "")
        configItem.submenu = configMenu
        mainMenu.addItem(configItem)

        let peersItem = NSMenuItem(title: "已连接节点", action: nil, keyEquivalent: "")
        peersItem.submenu = peerMenu
        mainMenu.addItem(peersItem)

        mainMenu.addItem(NSMenuItem.separator())

        mainMenu.addItem(
            withTitle: "关于", action: #selector(showAbout), keyEquivalent: "").target = self

        mainMenu.addItem(NSMenuItem.separator())

        mainMenu.addItem(
            withTitle: "退出", action: #selector(quit), keyEquivalent: "q").target = self

        statusItem.menu = mainMenu
    }

    private func rebuildConfigMenu() {
        configMenu.removeAllItems()

        let configs = ConfigManager.shared.configs
        let selectedId = ConfigManager.shared.selectedId

        for config in configs {
            let item = NSMenuItem(title: config.name, action: #selector(selectConfig(_:)), keyEquivalent: "")
            item.representedObject = config.id
            item.state = config.id == selectedId ? .on : .off
            item.target = self
            configMenu.addItem(item)
        }

        if !configs.isEmpty {
            configMenu.addItem(NSMenuItem.separator())
        }

        configMenu.addItem(
            withTitle: "添加配置...", action: #selector(showAddConfig), keyEquivalent: "n").target = self
        configMenu.addItem(
            withTitle: "删除当前配置", action: #selector(deleteCurrentConfig), keyEquivalent: "").target = self
    }

    // MARK: - UI Update

    func updateUI() {
        let imageName = ServiceManager.shared.isRunning
            ? "antenna.radiowaves.left.and.right"
            : "antenna.radiowaves.left.and.right.slash"
        statusItem.button?.image = NSImage(
            systemSymbolName: imageName, accessibilityDescription: "EasyTier")

        if let toggleItem = mainMenu.items.first {
            let hasConfig = ConfigManager.shared.selectedConfig != nil
            if !hasConfig {
                toggleItem.title = "未配置网络"
            } else {
                toggleItem.title = ServiceManager.shared.isRunning ? "停止 EasyTier" : "启动 EasyTier"
            }
        }

        rebuildConfigMenu()
    }

    @objc private func menuWillOpen() {
        ServiceManager.shared.checkStatus()
        updatePeerList()
    }

    private func updatePeerList() {
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
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                item.isEnabled = false
                self.peerMenu.addItem(item)
            }
        }
    }

    // MARK: - Actions

    @objc func toggleService() {
        guard let config = ConfigManager.shared.selectedConfig else { return }

        if ServiceManager.shared.isRunning {
            setToggleState(enabled: false, title: "正在停止...")
            ServiceManager.shared.stopService { [weak self] success in
                guard let self = self else { return }
                self.setToggleState(enabled: true)
                if !success {
                    self.showAlert(title: "操作失败", message: "无法停止 EasyTier 服务。")
                }
                self.updateUI()
            }
        } else {
            setToggleState(enabled: false, title: "正在启动...")
            ServiceManager.shared.startService(configUrl: config.url) { [weak self] success in
                guard let self = self else { return }
                self.setToggleState(enabled: true)
                if !success {
                    self.showAlert(title: "操作失败", message: "无法启动 EasyTier 服务。")
                }
                self.updateUI()
            }
        }
    }

    private func setToggleState(enabled: Bool, title: String? = nil) {
        guard let toggleItem = mainMenu.items.first else { return }
        toggleItem.isEnabled = enabled
        if let title = title { toggleItem.title = title }
    }

    @objc func selectConfig(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        ConfigManager.shared.selectConfig(id: id)
        updateUI()
    }

    // MARK: - Config Management

    @objc func showAddConfig() {
        showAddConfigDialog(isFirstLaunch: false)
    }

    func showAddConfigDialog(isFirstLaunch: Bool) {
        let alert = NSAlert()
        alert.messageText = isFirstLaunch ? "欢迎使用 EasyTierBar" : "添加网络配置"

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 8

        let nameField = NSTextField()
        nameField.placeholderString = "配置名称（如：Home、Office）"
        stackView.addArrangedSubview(nameField)

        let urlField = NSTextField()
        urlField.placeholderString = "udp://host:port/network"
        stackView.addArrangedSubview(urlField)

        stackView.frame = NSRect(x: 0, y: 0, width: 300, height: 58)
        alert.accessoryView = stackView

        alert.addButton(withTitle: "添加")
        if !isFirstLaunch {
            alert.addButton(withTitle: "取消")
        }

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            let name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
            let url = urlField.stringValue.trimmingCharacters(in: .whitespaces)

            guard !name.isEmpty, !url.isEmpty else {
                showAlert(title: "输入无效", message: "名称和 URL 不能为空。")
                if isFirstLaunch { showAddConfigDialog(isFirstLaunch: true) }
                return
            }

            _ = ConfigManager.shared.addConfig(name: name, url: url)
            updateUI()
        } else if isFirstLaunch {
            NSApplication.shared.terminate(nil)
        }
    }

    @objc func deleteCurrentConfig() {
        guard let config = ConfigManager.shared.selectedConfig else { return }

        let alert = NSAlert()
        alert.messageText = "删除配置"
        alert.informativeText = "确定删除配置「\(config.name)」吗？"
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")

        if alert.runModal() == .alertFirstButtonReturn {
            ConfigManager.shared.deleteConfig(id: config.id)
            updateUI()
        }
    }

    // MARK: - About & Quit

    @objc func showAbout() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let alert = NSAlert()
        alert.messageText = "EasyTierBar v\(version)"
        alert.informativeText = "macOS 菜单栏工具 for EasyTier VPN"
        alert.runModal()
    }

    @objc func quit() {
        if ServiceManager.shared.isRunning {
            ServiceManager.shared.stopService { _ in }
        }
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Helpers

    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
