# EasyTierBar

macOS 菜单栏看护工具，为 [EasyTier](https://github.com/EasyTier/EasyTier) VPN（Web-Managed / config-server 模式）提供常驻守护进程管理与状态监控。

专为 Apple Silicon (aarch64) 设计，零依赖，开箱即用。

## 功能

- **常驻守护进程** — 一次性安装系统级 LaunchDaemon，开机自启、崩溃自愈、自动连配置中心
- **一键启停** — 菜单第一项「启动 / 停止」，操作时输入管理员密码。停止是临时的，重启电脑后自动恢复
- **五态健康状态** — 运行中(绿) / 未连通网络(橙) / 守护进程未响应(黄) / 已停止(灰) / 未安装(灰)。不只看进程在不在，还看是否有对端 peer，避免「进程活着但 VPN 早断了」的误报
- **定时自动刷新** — 默认每 5 分钟自动检测一次状态（可调：关闭 / 1分 / 5分 / 15分），无需打开菜单也能及时发现断开
- **网络失联恢复** — 菜单「重启守护进程」一键重启 core（弹一次密码，保留配置），用于配置中心 session 失联、网络卡死等场景
- **Web 控制台入口** — 一键打开浏览器进入配置中心，统一管理网络实例
- **节点信息** — 查看已连接节点（主机名、IP、延迟、丢包率、版本等），走 RPC 无需密码
- **操作简单** — 安装/卸载/重启/启停时输入管理员密码，日常查看状态、节点、打开 Web 控制台均免密
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
│  停止                (或 启动)   │
│  ● 运行中        (绿/橙/黄/灰)  │
├─────────────────────────────────┤
│  已连接节点           ▸         │
│    easytier-moon               │
│    10.126.126.7 · 60ms · v2.6  │
├─────────────────────────────────┤
│  刷新状态                       │
│  打开 Web 控制台                │
├─────────────────────────────────┤
│  卸载守护进程                   │
│  重启守护进程                   │
│  配置中心设置...                │
│  自动检测间隔        ▸          │
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
| 启动/停止 | `launchctl load -w / unload`（AppleScript sudo，弹密码框） | 每次输密码 |
| 重启守护进程 | `launchctl kickstart -k system/...`（AppleScript sudo，保留配置） | 一次性 root |
| 状态检测 | `easytier-cli node info` + `peer list`（RPC `127.0.0.1:15888`） | 无需 root |
| 定时刷新 | app 内 Timer，默认 5 分钟（可配置），自动跑状态检测 | 无需 root |
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
├── AppDelegate.swift       # 菜单 UI、四态状态、安装/卸载/重启、定时刷新、Web 控制台入口
├── ServiceManager.swift    # 守护进程安装/卸载/重启、RPC 状态与健康检测、节点查询
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

### 「停止」和「卸载守护进程」的区别？

- **停止**（输密码）：临时卸载 LaunchDaemon——VPN 立即断开，但配置和守护进程保留。重启电脑后自动恢复，也可随时点「启动」。
- **卸载守护进程**（输密码）：永久移除——删除 plist，可选清除本地网络配置。

本地停止是可靠的：停的是整个 core 守护进程（连同配置中心连接一起断开），而非单独停某个网络实例，因此不存在「被配置中心 reconcile 重新拉起」的问题。

### 安装/卸载/重启时弹出密码框

创建/移除/重启系统级 LaunchDaemon 需要 root 权限，通过 macOS 原生 AppleScript 弹出管理员认证框。**仅在这三种操作时弹**，日常查看、刷新、打开 Web 控制台都不会弹。

### 守护进程已安装但状态显示「未响应」

通常是 `easytier-core` 启动较慢或连接配置中心失败。查看 `/tmp/easytier-core.log` 确认：
- 配置中心地址是否正确、是否可达
- 15888 端口是否被占用（是否有手动运行的 core 未被清理）

### 显示「运行中」但实际连不上公司网络

状态判定为「运行中」的条件是：core 进程在跑 + RPC 可达 + 有对端 peer。但存在一种**死链残留**情况——某台对端（如公司内网入口节点）实际已断开、零流量，却仍残留在 peer 列表里，导致状态还是绿色。这时可去 **Web 控制台** 确认这台机器是否还在设备列表：若不在，说明配置中心 session 已断。

解决办法：菜单 →「重启守护进程」（输一次密码，保留配置），让 core 重新连接配置中心、重新协商 peer。也可终端直接执行 `sudo launchctl kickstart -k system/com.easytier.core`。

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
| 权限模型 | AppleScript `do shell script with administrator privileges`（安装/卸载/重启/启停） |

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
