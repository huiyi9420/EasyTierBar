---
wave: 2
depends_on:
  - 01
  - 02
files_modified:
  - EasyTierBar/AppDelegate.swift
autonomous: true
requirements:
  - UI-01
  - UI-02
  - SVC-04
objective: 创建 AppDelegate，实现菜单栏 UI、配置管理菜单、服务切换和首次引导
---

# Plan 03: AppDelegate.swift — UI 和菜单逻辑

## Objective

实现 `AppDelegate` 类，构建完整的菜单栏 UI：SF Symbols 状态图标、配置列表子菜单、添加/删除配置、服务切换、首次引导对话框、关于/退出等。此文件是 UI 层，依赖 ConfigManager 和 ServiceManager。

## Context

从 CONTEXT.md 决策：
- 菜单内配置列表（单选样式），当前选中配置有勾选标记
- "添加配置"菜单项弹出输入对话框（名称 + 网络 URL）
- "删除配置"菜单项删除当前选中的配置
- 首次启动无配置时自动弹出引导对话框添加第一个配置
- 左键点击切换当前配置的连接状态
- 退出应用时停止服务
- SF Symbols 天线图标

## Tasks

### Task 1: 创建 AppDelegate 基本结构和状态栏图标

<read_first>
- EasyTierBar/main.swift — 了解现有 AppDelegate 结构和菜单模式
- EasyTierBar/ConfigManager.swift — 配置管理接口
- EasyTierBar/ServiceManager.swift — 服务管理接口
</read_first>

<action>
创建文件 `EasyTierBar/AppDelegate.swift`：

```swift
import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let mainMenu = NSMenu()
    let configMenu = NSMenu()

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

        // 首次引导或恢复状态
        if !ConfigManager.shared.hasConfigs {
            showAddConfigDialog(isFirstLaunch: true)
        } else {
            ServiceManager.shared.checkStatus()
        }
    }
}
```
</action>

<acceptance_criteria>
- `EasyTierBar/AppDelegate.swift` 文件存在
- AppDelegate 有 `statusItem`、`mainMenu`、`configMenu` 属性
- applicationDidFinishLaunching 检查 ServiceManager.isReady
- easytier-cli 不存在时弹出错误提示并退出
- 无配置时弹出首次引导对话框
- 有配置时调用 checkStatus
- 注册 onStatusChanged 和 onConfigsChanged 回调
</acceptance_criteria>

### Task 2: 实现菜单构建

<read_first>
- EasyTierBar/AppDelegate.swift — 当前文件状态
</read_first>

<action>
在 `AppDelegate` 类中添加菜单构建方法：

```swift
    // MARK: - Menu Building

    private func buildMenu() {
        // 切换连接
        let toggleItem = mainMenu.addItem(
            withTitle: "启动 EasyTier", action: #selector(toggleService), keyEquivalent: "t")
        toggleItem.target = self

        // 配置列表子菜单
        let configItem = NSMenuItem(title: "网络配置", action: nil, keyEquivalent: "")
        configItem.submenu = configMenu
        mainMenu.addItem(configItem)

        mainMenu.addItem(NSMenuItem.separator())

        // 关于
        mainMenu.addItem(
            withTitle: "关于", action: #selector(showAbout), keyEquivalent: "").target = self

        mainMenu.addItem(NSMenuItem.separator())

        // 退出
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
```
</action>

<acceptance_criteria>
- AppDelegate 有 `buildMenu()` 方法
- 菜单包含：切换项、配置子菜单、分隔线、关于、分隔线、退出
- AppDelegate 有 `rebuildConfigMenu()` 方法
- 配置列表中选中项 state 为 .on
- 配置子菜单有"添加配置..."和"删除当前配置"
- 空列表时不显示多余分隔线
</acceptance_criteria>

### Task 3: 实现 UI 更新和菜单打开刷新

<read_first>
- EasyTierBar/AppDelegate.swift — 当前文件状态
</read_first>

<action>
在 `AppDelegate` 类中添加：

```swift
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
```

并在 `applicationDidFinishLaunching` 中添加菜单打开通知：
```swift
        // 在 buildMenu() 调用之后添加
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuWillOpen),
            name: NSMenu.didBeginTrackingNotification,
            object: mainMenu)
```

添加方法：
```swift
    @objc private func menuWillOpen() {
        ServiceManager.shared.checkStatus()
    }
```
</action>

<acceptance_criteria>
- updateUI 使用 SF Symbols 图标：已连接用 `antenna.radiowaves.left.and.right`，断开用 `.slash`
- 无配置时切换项标题为"未配置网络"
- 有配置时显示"启动/停止 EasyTier"
- 菜单打开时触发 checkStatus 异步刷新
</acceptance_criteria>

### Task 4: 实现服务切换和配置选择

<read_first>
- EasyTierBar/AppDelegate.swift — 当前文件状态
</read_first>

<action>
在 `AppDelegate` 类中添加：

```swift
    // MARK: - Actions

    @objc func toggleService() {
        guard let config = ConfigManager.shared.selectedConfig else { return }

        if ServiceManager.shared.isRunning {
            _ = ServiceManager.shared.stopService()
        } else {
            if !ServiceManager.shared.startService(configUrl: config.url) {
                showAlert(title: "操作失败", message: "无法\(!ServiceManager.shared.isRunning ? "启动" : "停止") EasyTier 服务。")
            }
        }
        updateUI()
    }

    @objc func selectConfig(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        ConfigManager.shared.selectConfig(id: id)
        updateUI()
    }
```
</action>

<acceptance_criteria>
- toggleService 检查是否有选中配置
- 运行中调用 stopService，未运行调用 startService
- 失败时弹出 Alert
- selectConfig 通过 representedObject 获取 UUID
- 操作后调用 updateUI
</acceptance_criteria>

### Task 5: 实现添加/删除配置对话框

<read_first>
- EasyTierBar/AppDelegate.swift — 当前文件状态
</read_first>

<action>
在 `AppDelegate` 类中添加：

```swift
    // MARK: - Config Management

    @objc func showAddConfig() {
        showAddConfigDialog(isFirstLaunch: false)
    }

    func showAddConfigDialog(isFirstLaunch: Bool) {
        let alert = NSAlert()
        alert.messageText = isFirstLaunch ? "欢迎使用 EasyTierBar" : "添加网络配置"

        // 创建输入框
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 8

        let nameField = NSTextField()
        nameField.placeholderString = "配置名称（如：Home、Office）"
        stackView.addArrangedSubview(nameField)

        let urlField = NSTextField()
        urlField.placeholderString = "udp://host:port/network"
        stackView.addArrangedSubview(urlField)

        let paddingView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 0))
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

            ConfigManager.shared.addConfig(name: name, url: url)
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
```
</action>

<acceptance_criteria>
- showAddConfigDialog 有 name 和 url 两个输入框
- 首次启动时没有取消按钮
- 首次启动点取消退出应用
- 空名称/URL 时提示错误
- 删除配置有确认对话框
- 对话框显示配置名称
</acceptance_criteria>

### Task 6: 实现关于和退出

<read_first>
- EasyTierBar/AppDelegate.swift — 当前文件状态
</read_first>

<action>
在 `AppDelegate` 类中添加：

```swift
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
            _ = ServiceManager.shared.stopService()
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
```
</action>

<acceptance_criteria>
- showAbout 显示版本号（从 Bundle 读取）
- quit 退出前停止服务
- showAlert 是通用提示方法
</acceptance_criteria>

## Verification

1. `EasyTierBar/AppDelegate.swift` 编译无错误
2. 启动时检查 easytier-cli 存在
3. 菜单结构完整：切换、配置子菜单、关于、退出
4. SF Symbols 图标正确切换
5. 配置列表带选中标记
6. 添加/删除配置对话框正常工作
7. 首次启动引导添加配置
8. 退出时停止服务

## must_haves

- SF Symbols 天线图标（已连接/断开两种状态）
- 配置列表子菜单（带选中标记）
- 添加配置输入对话框
- 删除配置确认对话框
- 首次启动引导
- 菜单打开时刷新状态
- 退出时停止服务
- 关于对话框
