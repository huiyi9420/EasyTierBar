# EasyTier macOS 状态栏工具 — 设计规格

**版本:** 1.0
**日期:** 2026-04-17
**设计完成:** ✓

## 概述

macOS 菜单栏工具，提供：
- 一键启动/停止 EasyTier VPN 服务
- 图标状态反映连接状态
- 右键菜单查看所有已连接节点的详细信息
- 通过 `easytier-cli service` 集成 macOS 原生 launchd 服务管理

## 架构设计

```
┌─────────────────────────────┐
│  EasyTierBar.app (菜单栏 UI) │ ← 普通用户进程，无 sudo
│  ├── 状态栏图标：状态指示    │
│  ├── 左键：切换连接状态      │
│  ├── 右键：菜单 + 节点列表   │
│  └── 打开菜单时刷新状态      │
└──────────┬──────────────────┘
           │
           │ 调用 easytier-cli
           ↓
┌─────────────────────────────┐
│  easytier-cli               │ ← 命令行接口
│  - service start/stop/status│
│  - peer list -o json        │
│  - node info -o json        │
└──────────┬──────────────────┘
           │ RPC 访问
           ↓
┌─────────────────────────────┐
│  easytier-core (launchd)    │ ← root 系统服务
│  - 创建 TUN 网卡            │
│  - P2P 组网打洞            │
│  - RPC 端口: 127.0.0.1:15888│
└─────────────────────────────┘
```

### 架构选择

**方案 A：原生 launchd 系统服务**
- ✅ 不需要手动配置 sudoers
- ✅ macOS 原生服务管理，开机自启动可选
- ✅ 崩溃自动重启
- ✅ 菜单栏进程普通用户运行，安全

初始安装只需一次：`sudo easytier-cli service install -w <config-url>`

## UI 设计

### 菜单栏图标

使用 macOS 原生 SF Symbols：
- **已连接:** `antenna.radiowaves.left.and.right` (完整天线)
- **未连接:** `antenna.radiowaves.left.and.right.slash` (天线划线)
- 自动适配浅色/深色模式

### 右键菜单结构

```
[✓ 已连接 EasyTier]  ← 点击切换（启动/停止）
──────────────────
[已连接节点 ▶]  ← 二级子菜单
   ├─ easytier-moon
   │  10.126.126.7 • p2p • 60ms • 0.0% • 2.90 kB • v2.4.5
   ├─ NanoPi_R4S
   │  10.126.126.1 • relay(2) • 59ms • 0.0% • 0 B • v2.4.5
   └─ ... (所有节点)
──────────────────
[关于]
[退出]
```

### 节点信息显示

显示全部字段（用户全选）：
1. **主机名** - 节点自定义名称
2. **虚拟 IPv4** - VPN IP 地址
3. **连接类型** - `p2p`/`relay(N)`/`Local`
4. **延迟** - `XX.X ms`
5. **丢包率** - `0.0%`
6. **流量** - `RX/TX kB`
7. **版本** - EasyTier 版本号

### 刷新策略

**只在打开菜单时刷新一次**，不后台轮询：
- 打开右键菜单 → 异步调用 `easytier-cli service status` + `easytier-cli peer list -o json`
- 更新状态栏图标 → 更新二级子菜单节点列表
- 优点：零后台开销，只在用户查看时更新

### 交互行为

| 操作 | 行为 |
|------|------|
| 左键点击图标 | 切换连接状态（启动 → 停止，停止 → 启动） |
| 右键点击图标 | 弹出菜单，**同时刷新状态** |
| 点击"已连接 EasyTier" | 切换连接后关闭菜单 |
| 点击节点 | 无动作，仅展示信息 |
| 点击"关于" | 弹出对话框显示版本信息 |
| 点击"退出" | 退出应用**并停止服务** |

## 功能需求

### 必须实现

- [x] 状态栏图标状态变化（连接/断开）
- [x] 左键点击一键切换连接状态
- [x] 右键菜单打开后自动刷新状态
- [x] 二级子菜单显示所有节点信息（全部7个字段）
- [x] 通过 `easytier-cli service` 与 launchd 集成
- [x] 应用启动时检测当前服务状态更新图标

### 可选扩展（未来）

- [ ] 点击节点 ping 测试延迟
- [ ] 显示流量走势图
- [ ] 支持多配置切换

## 自动化更新

### GitHub Actions 自动构建

添加 GitHub Actions workflow 实现完全自动化：

1. **监听新版本**：定时轮询 `EasyTier/EasyTier` GitHub repo，检测新 release
2. **下载二进制**：自动下载 `easytier-aarch64-apple-darwin` 压缩包
3. **编译 UI**：Swift 编译 `EasyTierBar` 源码
4. **打包 app**：将 easytier 二进制内嵌到 `EasyTierBar.app/Contents/Resources/`
5.** 发布 **：创建新 release 到你的 repo，用户可下载

### 更新路径

应用内检查更新（可选添加）：
- 启动时调用 GitHub API 检查你的 repo 是否有新版本
- 有更新提示用户下载

### 文件位置

| 文件 | 位置 |
|------|------|
| 源码 | `EasyTierBar/main.swift` |
| Info.plist | `EasyTierBar/Info.plist` |
| GitHub workflow | `.github/workflows/build.yml` |
| 编译输出 | `EasyTierBar.app/` |

### 内嵌二进制路径

UI 使用相对路径从 app bundle 加载 easytier-cli：
```swift
let cliPath = Bundle.main.path(forResource: "easytier-cli", ofType: nil)
let corePath = Bundle.main.path(forResource: "easytier-core", ofType: nil)
```

## 技术实现

### 语言和框架

- Swift + Cocoa + AppKit → 原生 macOS 应用
- 不使用 SwiftUI → 兼容更多 macOS 版本
- 无 Dock 图标 (`LSUIElement = true`)

### 核心类

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem: NSStatusItem
    let peerMenu: NSMenu       // 二级子菜单
    var isRunning: Bool        // 当前服务运行状态
    
    func checkStatus()         // 调用 easytier-cli service status，更新 UI
    func toggleService()       // 切换服务状态
    func updatePeerList()      // 调用 peer list -o json，重建二级菜单
}
```

### 权限要求

唯一需要 root 的步骤是**初始安装服务**（用户第一次使用）：
```bash
sudo /Applications/EasyTierBar.app/Contents/Resources/easytier-cli service install --disable-autostart true -w udp://111.170.131.76:22020/zhaolulu
```
之后菜单栏应用不需要 root，也不需要 sudoers 配置。

**开机自启**：禁用，仅通过菜单栏手动启动。
**退出行为**：退出应用时停止服务。

## 自检

- [x] 无占位符/待定项
- [x] 内部一致
- [x] 范围聚焦（单一应用，一个实现计划可覆盖）
- [x] 无歧义，所有需求明确
