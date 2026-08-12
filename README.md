# EasyTierBar

macOS 菜单栏看护工具，为 [EasyTier](https://github.com/EasyTier/EasyTier) VPN（Web-Managed / config-server 模式）提供常驻守护进程管理与状态监控。

专为 Apple Silicon (aarch64) 设计，零依赖，开箱即用。

## 功能

- **常驻守护进程** — 一次性安装系统级 LaunchDaemon，开机自启、崩溃自愈、自动连配置中心
- **三态状态** — 运行中 / 守护进程未响应 / 未安装，一目了然
- **Web 控制台入口** — 一键打开浏览器进入配置中心，统一管理网络实例
- **节点信息** — 查看已连接节点（主机名、IP、延迟、丢包率、版本等），走 RPC 无需密码
- **日常零密码** — 仅安装/卸载守护进程需要一次管理员密码，日常查看与打开 Web 控制台均免密
- **自动构建** — CI/CD 自动监听上游 EasyTier 发版，自动打包发布

## 适用场景

适合使用 **EasyTier Web 配置中心（`easytier-web`）** 统一管理多台设备的用户：

- 在服务器上部署 `easytier-web`，在网页端统一配置网络拓扑
- 每台 Mac 上跑 EasyTierBar，用 `-w <配置中心地址>` 让 `easytier-core` 连上配置中心
- 网络实例（哪些节点组哪个网）在 Web 控制台配置，由配置中心 `reconcile` 下发到本地

> 如果你需要本地维护多个独立网络配置、脱离 Web 中心自由组网，这种模式不太适合——可考虑 EasyTier 官方 GUI。

## 截图

```
┌─────────────────────────────────┐
│  ● 运行中                       │
├─────────────────────────────────┤
│  已连接节点           ▸         │
│    easytier-moon               │
│    10.126.126.7 · 60ms · v2.6  │
├─────────────────────────────────┤
│  打开 Web 控制台                │
├─────────────────────────────────┤
│  卸载守护进程                   │
│  配置中心设置...                │
├─────────────────────────────────┤
│  关于                           │
│  退出                           │
└─────────────────────────────────┘
```

## 安装

### 下载

前往 [Releases](https://github.com/huiyi9420/EasyTierBar/releases) 页面下载最新版 `EasyTierBar-aarch64-macos.zip`。

### 安装步骤

1. 解压 zip 文件
2. 将 `EasyTierBar.app` 拖入 `/Applications`
3. 首次启动：**右键点击** 应用 → 选择「打开」（绕过 Gatekeeper）
4. 如果提示「已损坏」，在终端运行：
   ```bash
   xattr -cr /Applications/EasyTierBar.app
   ```
5. 菜单栏出现天线图标即安装成功

### 首次使用

启动后应用会引导设置配置中心（两个字段，各自独立）：

1. **配置中心地址** — `easytier-core` 连接用，即 `-w` 参数。如 `udp://web-et.seeyon.ink:22020/admin`
2. **Web 控制台地址** — 浏览器打开的配置中心网页。如 `https://web-et.seeyon.ink`

填好后点菜单栏图标 →「安装守护进程」→ 输入一次管理员密码（**仅此一次**）。

守护进程安装后会：
- 开机自启、崩溃自动重启（`KeepAlive: true`）
- 自动连接配置中心、拉取 Web 端下发的网络配置并持久化到 `--config-dir`
- 凭 `machine-id` 断线重连后自动恢复网络实例

此后日常查看节点、打开 Web 控制台均无需密码。网络实例的增删在 Web 控制台做。

## 工作原理

EasyTierBar 把单个 `easytier-core` 作为**常驻 LaunchDaemon** 运行（root），自身（菜单栏 app，非 root）通过 RPC 控制和查询：

| 操作 | 实现方式 | 权限 |
|------|----------|------|
| 安装守护进程 | 写 launchd plist + `launchctl load`（AppleScript sudo） | 一次性 root |
| 卸载守护进程 | `launchctl unload` + `rm plist` + `pkill`（AppleScript sudo） | 一次性 root |
| 状态检测 | `easytier-cli node info`（RPC `127.0.0.1:15888`） | 无需 root |
| 节点查询 | `easytier-cli -o json peer list`（RPC） | 无需 root |
| 网络启停 | 在 Web 控制台操作（配置中心 `reconcile` 下发） | Web 端 |

守护进程命令（由 plist 的 `ProgramArguments` 决定）：

```
easytier-core --daemon \
  --config-dir "/Library/Application Support/EasyTierBar/configs" \
  -w <配置中心地址> \
  --rpc-portal 127.0.0.1:15888
```

运行日志位于 `/tmp/easytier-core.log`。

## 项目结构

```
EasyTierBar/
├── main.swift              # 应用入口
├── AppDelegate.swift       # 菜单 UI、三态状态、安装/卸载、Web 控制台入口
├── ServiceManager.swift    # 守护进程安装/卸载、RPC 状态检测、节点查询
├── ConfigManager.swift     # 配置中心地址持久化（UserDefaults，单条）
└── Info.plist              # 应用元数据 (com.easytier.menubar)
Makefile                    # 本地构建脚本
scripts/generate_icon.py    # 应用图标生成
.github/workflows/build.yml # CI/CD 自动构建发布
```

## 本地开发

### 前置要求

- macOS (Apple Silicon)
- Xcode Command Line Tools: `xcode-select --install`

### 准备二进制文件

从 [EasyTier Releases](https://github.com/EasyTier/EasyTier/releases) 下载 macOS aarch64 版本，将 `easytier-cli` 和 `easytier-core` 放在项目根目录。

### 构建与运行

```bash
# 编译
make

# 清理
make clean

# 部署到 Applications
cp -R build/EasyTierBar.app /Applications/
xattr -cr /Applications/EasyTierBar.app
open /Applications/EasyTierBar.app
```

### 查看调试日志

```bash
# 查看 EasyTierBar 内部日志
log stream --predicate 'subsystem == "com.easytier.bar"' --level debug

# 查看 easytier-core 运行日志
tail -f /tmp/easytier-core.log
```

## CI/CD

GitHub Actions 自动化流水线：

- **触发方式**：每 6 小时定时检查 + 推送到 main + 手动触发
- **工作流程**：检测 EasyTier 新版本 → 下载 macOS 二进制 → 编译 Swift → 打包 .app → 发布 Release
- **产物**：`EasyTierBar-aarch64-macos.zip`

### 手动触发构建

在仓库的 Actions 页面，选择 "Build EasyTier" workflow，点击 "Run workflow"，可指定 EasyTier 版本标签。

## 常见问题

### 打开时提示「已损坏」

macOS Gatekeeper 对下载的第三方应用会标记隔离属性：

```bash
xattr -cr /Applications/EasyTierBar.app
```

应用启动时也会自动执行此操作。

### 为什么没有「启动/停止网络」按钮？

EasyTierBar 定位为**常驻守护进程的看护者**。在 Web-Managed（config-server）模式下，网络实例由 Web 配置中心统一下发；本地停掉的实例会被配置中心 `reconcile` 重新拉起，因此本地「停止」语义不干净。

想临时断开：去 Web 控制台停这台机器的网络实例，或在菜单里「卸载守护进程」。

### 安装/卸载时弹出密码框

创建/移除系统级 LaunchDaemon 需要 root 权限，通过 macOS 原生 AppleScript 弹出管理员认证框。**仅在安装和卸载守护进程时各弹一次**，日常使用不会弹。

### 守护进程已安装但状态显示「未响应」

通常是 `easytier-core` 启动较慢或连接配置中心失败。查看 `/tmp/easytier-core.log` 确认：
- 配置中心地址是否正确、是否可达
- 15888 端口是否被占用（是否有手动运行的 core 未被清理）

### 如何完全卸载

1. 菜单栏图标 →「卸载守护进程」（可勾选同时清除本地网络配置）
2. 退出 EasyTierBar
3. 删除应用：`rm -rf /Applications/EasyTierBar.app`

## 技术栈

| 项目 | 说明 |
|------|------|
| 语言 | Swift 5 |
| 框架 | Cocoa / AppKit（原生 macOS） |
| 服务管理 | launchd（macOS 原生服务管理器） |
| 控制接口 | EasyTier RPC（`easytier-cli` over `127.0.0.1:15888`） |
| 目标平台 | macOS aarch64 (Apple Silicon) |
| 权限模型 | AppleScript `do shell script with administrator privileges`（仅安装/卸载） |

## 贡献

欢迎提交 Issue 和 Pull Request。

开发流程：
1. Fork 仓库
2. 创建功能分支：`git checkout -b feature/your-feature`
3. 本地测试：`make && cp -R build/EasyTierBar.app /Applications/`
4. 提交 PR

## 相关项目

- [EasyTier](https://github.com/EasyTier/EasyTier) — 开源、去中心化、无需公网 IP 的 P2P 组网工具

## License

MIT
