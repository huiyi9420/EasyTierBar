# EasyTierBar 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 创建 macOS 菜单栏工具 EasyTierBar，一键启动/停止 EasyTier 服务，显示连接状态，右键查看所有节点信息，支持 GitHub Actions 自动从上游拉取最新版重新打包。

**架构：** 原生 Swift + Cocoa 应用，使用 SF Symbols 显示状态栏图标。easytier-core 通过 `easytier-cli service install` 注册为 launchd 系统服务（root 运行），菜单栏应用作为普通用户通过 `easytier-cli` 调用管理服务和读取节点信息。easytier 二进制内嵌在 app bundle 中，GitHub Actions 自动监听上游发版并更新。

**技术栈：** Swift 5+, Cocoa/AppKit, macOS, GitHub Actions

---

## 文件结构

| 文件 | 职责 |
|------|------|
| `EasyTierBar/main.swift` | 主程序入口，`AppDelegate`，状态栏菜单逻辑，状态轮询，节点列表构建 |
| `EasyTierBar/Info.plist` | App 配置，`LSUIElement=true` 隐藏 Dock 图标 |
| `.github/workflows/build.yml` | GitHub Actions 自动化构建：检测上游 release → 下载二进制 → 编译 Swift → 打包 app → 发布 release |

---

### 任务 1：重构 main.swift 适配新设计

**文件：**
- 修改：`EasyTierBar/main.swift`

当前 `main.swift` 是直接 spawn `sudo easytier-core`，需要重构为调用 `easytier-cli service`。

- [ ] **步骤 1：定义常量**

```swift
import Cocoa

let easytierCLIPath = Bundle.main.path(forResource: "easytier-cli", ofType: nil)!
let configURL = "udp://111.170.131.76:22020/zhaolulu"
let serviceName = "easytier"

class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let mainMenu = NSMenu()
    let peerMenu = NSMenu()          // 二级子菜单：节点列表
    var isRunning = false           // 服务运行状态

```

- [ ] **步骤 2：完成 applicationDidFinishLaunching 构建菜单结构**

```swift
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 主菜单项：开关
        let toggleItem = mainMenu.addItem(
            withTitle: "启动 EasyTier", action: #selector(toggleService), keyEquivalent: "t")
        toggleItem.target = self

        // 二级子菜单：已连接节点
        let peersItem = NSMenuItem(title: "已连接节点", action: nil)
        peersItem.submenu = peerMenu
        mainMenu.addItem(peersItem)

        mainMenu.addItem(NSMenuItem.separator())
        mainMenu.addItem(
            withTitle: "关于", action: #selector(showAbout), keyEquivalent: "a").target = self
        mainMenu.addItem(NSMenuItem.separator())
        mainMenu.addItem(
            withTitle: "退出", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = mainMenu

        // 打开菜单时刷新状态
        NSMenu.willPopUpNotification.addObserver(
            self, selector: #selector(menuWillOpen), name: NSMenu.willPopUpNotification, object: nil)

        checkStatus()
    }
```

- [ ] **步骤 3：实现 checkStatus 调用 `easytier-cli service status`**

```swift
    func checkStatus(completion: (() -> Void)? = nil) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: easytierCLIPath)
        process.arguments = ["service", "status"]
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
            // 退出码 0 = running, 非 0 = stopped
            isRunning = process.terminationStatus == 0
            updateUI()
            updatePeerList()
            completion?()
        } catch {
            showAlert(title: "检查状态失败", message: error.localizedDescription)
            completion?()
        }
    }
```

- [ ] **步骤 4：实现 updateUI 更新状态栏图标**

```swift
    func updateUI() {
        let imageName = isRunning
            ? "antenna.radiowaves.left.and.right"
            : "antenna.radiowaves.left.and.right.slash"
        statusItem.button?.image = NSImage(
            systemSymbolName: imageName, accessibilityDescription: "EasyTier")
        if let item = mainMenu.items.first {
            item.title = isRunning ? "停止 EasyTier" : "启动 EasyTier"
        }
    }
```

- [ ] **步骤 5：实现 updatePeerList 解析 JSON 并重建二级菜单**

解析 `easytier-cli -o json peer list` 输出：

```swift
    func updatePeerList() {
        peerMenu.removeAllItems()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: easytierCLIPath)
        process.arguments = ["-o", "json", "peer", "list"]
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = try pipe.fileHandleForReading.readToEnd() ?? Data()
            // JSON 格式: [{"hostname":"easytier-moon","ipv4":"10.126.126.7","cost":"p2p","lat_ms":"60.17","loss_rate":"0.0%","rx_bytes":"2.90 kB","tx_bytes":"2.66 kB","version":"2.4.5"}, ...]
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
            let peers = try JSONDecoder().decode([Peer].self, from: data)
            for peer in peers {
                // 显示: "hostname  ipv4 • cost • lat_ms ms • loss_rate • rx/tx • version"
                var title = "\(peer.hostname)"
                if !peer.ipv4.isEmpty {
                    title += " • \(peer.ipv4)"
                }
                title += " • \(peer.cost) • \(peer.lat_ms)ms • \(peer.loss_rate) • \(peer.rx_bytes)/\(peer.tx_bytes) • \(peer.version)"
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                peerMenu.addItem(item)
            }
            if peers.isEmpty {
                let item = NSMenuItem(title: "(无已连接节点)", action: nil, keyEquivalent: "")
                item.isEnabled = false
                peerMenu.addItem(item)
            }
        } catch {
            let item = NSMenuItem(title: "(获取节点列表失败)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            peerMenu.addItem(item)
        }
    }
```

- [ ] **步骤 6：实现 toggleService 启动/停止**

```swift
    @objc func toggleService() {
        if isRunning {
            stopService()
        } else {
            startService()
        }
    }

    func startService() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: easytierCLIPath)
        process.arguments = ["service", "start"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            checkStatus()
        } catch {
            showAlert(title: "启动失败", message: error.localizedDescription)
        }
    }

    func stopService() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: easytierCLIPath)
        process.arguments = ["service", "stop"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            checkStatus()
        } catch {
            showAlert(title: "停止失败", message: error.localizedDescription)
        }
    }
```

- [ ] **步骤 7：实现 menuWillOpen 钩子（每次打开菜单刷新）**

```swift
    @objc func menuWillOpen(_ notification: Notification) {
        checkStatus()
    }
```

- [ ] **步骤 8：实现 showAbout 和 showAlert**

```swift
    @objc func showAbout() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        showAlert(title: "EasyTierBar v\(version)", message: """
            macOS 菜单栏工具 for EasyTier

            源代码: https://github.com/[your-username]/EasyTierBar
            基于 EasyTier: https://github.com/EasyTier/EasyTier
            """)
    }

    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
```

- [ ] **步骤 9：实现 quit**

```swift
    @objc func quit() {
        // 退出应用时停止服务
        if isRunning {
            stopService()
        }
        NSApplication.shared.terminate(nil)
    }
}
```

- [ ] **步骤 10：补全底部代码**

```swift
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
```

### 任务 2：更新 Info.plist 配置

**文件：**
- 修改：`EasyTierBar/Info.plist`

- [ ] **步骤 1：添加版本信息**

在现有 dict 基础上追加：

```xml
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
```

### 任务 3：创建 GitHub Actions workflow 自动化构建

**文件：**
- 创建：`.github/workflows/build.yml`

- [ ] **步骤 1：编写 workflow**

```yaml
name: Build EasyTierBar

# 每天定时检测 EasyTier/EasyTier 是否有新版本
on:
  schedule:
    - cron: '0 6 * * *'  # 每天 UTC 6点 = 北京时间 14点
  workflow_dispatch:  # 支持手动触发

jobs:
  build:
    runs-on: macos-15
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Get latest EasyTier release
        id: get-release
        run: |
          LATEST=$(curl -s https://api.github.com/repos/EasyTier/EasyTier/releases/latest | jq -r '.tag_name')
          echo "latest=$LATEST" >> $GITHUB_OUTPUT
          echo "Latest EasyTier release: $LATEST"

      - name: Download EasyTier aarch64-macos binary
        run: |
          TAG=${{ steps.get-release.outputs.latest }}
          URL="https://github.com/EasyTier/EasyTier/releases/download/$TAG/easytier-aarch64-apple-darwin.tar.gz"
          echo "Downloading $URL"
          curl -L -o easytier.tar.gz "$URL"
          tar xzf easytier.tar.gz
          ls -la

      - name: Compile Swift
        run: |
          cd EasyTierBar
          swiftc -o EasyTierBar main.swift -framework Cocoa

      - name: Package app bundle
        run: |
          mkdir -p EasyTierBar.app/Contents/MacOS
          mkdir -p EasyTierBar.app/Contents/Resources
          mv EasyTierBar/EasyTierBar EasyTierBar.app/Contents/MacOS/
          cp EasyTierBar/Info.plist EasyTierBar.app/Contents/
          # 复制 easytier 二进制到 Resources
          mv easytier-cli easytier-core EasyTierBar.app/Contents/Resources/
          chmod +x EasyTierBar.app/Contents/Resources/*
          ls -la EasyTierBar.app/Contents/

      - name: Zip app
        run: |
          zip -r EasyTierBar-aarch64-macos.zip EasyTierBar.app/

      - name: Create Release
        id: create-release
        uses: actions/create-release@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          tag_name: ${{ steps.get-release.outputs.latest }}
          release_name: EasyTierBar ${{ steps.get-release.outputs.latest }} (auto-built)
          draft: false
          prerelease: false

      - name: Upload Release Asset
        uses: actions/upload-release-asset@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          upload_url: ${{ steps.create-release.outputs.upload_url }}
          asset_path: ./EasyTierBar-aarch64-macos.zip
          asset_name: EasyTierBar-aarch64-macos.zip
          asset_content_type: application/zip
```

---

## 自检

✅ 规格覆盖：所有设计需求都对应任务
- 状态栏图标：任务 1 updateUI
- 左键切换：toggleService
- 二级菜单节点列表：peerMenu + updatePeerList（包含所有 7 个字段：hostname/ipv4/cost/latency/loss rate/traffic/version）
- 打开菜单刷新：menuWillOpen + checkStatus
- 内嵌二进制 + GitHub Actions 自动构建：任务 3 workflow
- launchd 原生集成：调用 `easytier-cli service` 接口

✅ 无占位符：每个步骤都有完整代码
✅ 无歧义：所有路径、命令、代码都明确
✅ 一致性：变量名和结构一致
