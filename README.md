# EasyTierBar

macOS 菜单栏工具，为 [EasyTier](https://github.com/EasyTier/EasyTier) VPN 提供图形化操作界面。

专为 Apple Silicon (aarch64) 设计，零依赖，开箱即用。

## 功能

- **状态栏图标** — 实时显示 VPN 连接状态
- **一键连接/断开** — 点击菜单栏图标即可操作，无需终端命令
- **多配置管理** — 支持多个网络配置，自由切换
- **节点信息** — 查看已连接节点的详细信息（主机名、IP、延迟、丢包率、版本等）
- **自动构建** — CI/CD 自动监听上游 EasyTier 发版，自动打包发布

## 截图

```
┌─────────────────────────────────┐
│  停止 EasyTier                  │  ← 点击切换
├─────────────────────────────────┤
│  网络配置             ▸         │
│    ● Home                      │  ← 当前选中
│      Office                    │
│      ─────────                 │
│      添加配置...                │
│      删除当前配置               │
│  已连接节点           ▸         │
│    easytier-moon               │
│    10.126.126.7 · 60ms · v2.4  │
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

启动后应用会引导添加第一个网络配置：

1. 输入配置名称（如 `Home`）
2. 输入网络地址（如 `udp://host:port/network-name`）
3. 点击「添加」

之后点击菜单栏图标即可一键连接。首次启动/停止服务时，macOS 会弹出管理员密码输入框，这是正常行为（VPN 服务需要 root 权限创建虚拟网卡）。

## 工作原理

EasyTierBar 通过 macOS 原生 **launchd** 管理 `easytier-core` 后台进程：

| 操作 | 实现方式 |
|------|----------|
| 启动服务 | 写 launchd plist 到 `/Library/LaunchDaemons/`，通过 `launchctl load` 加载 |
| 停止服务 | `launchctl unload` 卸载服务并清理 plist |
| 状态检测 | `pgrep -x easytier-core` 检测进程 |
| 节点查询 | `easytier-cli -o json peer list` 获取节点信息 |

服务以 root 权限运行，崩溃后 launchd 自动重启（`KeepAlive: true`）。运行日志位于 `/tmp/easytier-core.log`。

## 项目结构

```
EasyTierBar/
├── main.swift              # 应用入口
├── AppDelegate.swift       # 菜单 UI 和用户交互逻辑
├── ServiceManager.swift    # launchd 服务管理（启动/停止/状态）
├── ConfigManager.swift     # 多配置持久化存储（UserDefaults）
└── Info.plist              # 应用元数据
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

在仓库的 Actions 页面，选择 "Build EasyTierBar" workflow，点击 "Run workflow"，可指定 EasyTier 版本标签。

## 常见问题

### 打开时提示「已损坏」

macOS Gatekeeper 对下载的第三方应用会标记隔离属性：

```bash
xattr -cr /Applications/EasyTierBar.app
```

应用启动时也会自动执行此操作。

### 启动服务时弹出密码框

EasyTier 需要创建虚拟网卡（TUN 设备），这需要 root 权限。EasyTierBar 通过 macOS 原生 AppleScript 弹出管理员认证框。如果不想每次输入密码，可以配置 sudo 免密（不推荐）。

### 服务启动后无法联网

检查 `/tmp/easytier-core.log` 确认错误原因。常见问题：
- 网络地址格式错误
- 服务端不可达
- 端口被占用

### 如何完全卸载

1. 在 EasyTierBar 中停止服务
2. 退出 EasyTierBar
3. 删除应用：`rm -rf /Applications/EasyTierBar.app`
4. 清理残留（如有）：`sudo rm -f /Library/LaunchDaemons/com.easytier.core.plist`

## 技术栈

| 项目 | 说明 |
|------|------|
| 语言 | Swift 5 |
| 框架 | Cocoa / AppKit（原生 macOS） |
| 服务管理 | launchd（macOS 原生服务管理器） |
| 目标平台 | macOS aarch64 (Apple Silicon) |
| 权限模型 | AppleScript `do shell script with administrator privileges` |

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
