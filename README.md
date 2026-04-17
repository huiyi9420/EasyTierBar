# EasyTierBar

macOS 菜单栏工具，为 [EasyTier](https://github.com/EasyTier/EasyTier) VPN 提供图形化操作界面。

## 功能

- **状态栏图标** — 实时显示 VPN 连接状态（天线图标）
- **一键连接** — 左键点击即可启动/停止 VPN 服务
- **多配置管理** — 支持添加多个网络配置，自由切换
- **节点信息** — 右键查看所有已连接节点的详细信息（主机名、IP、延迟、丢包率、流量、版本等）
- **自动构建** — CI/CD 自动监听上游 EasyTier 发版，自动打包发布

## 截图

```
┌─────────────────────────────┐
│  ✅ 停止 EasyTier           │  ← 点击切换
├─────────────────────────────┤
│  网络配置         ▸         │
│    ● Home                  │  ← 选中配置
│      Office                │
│      ─────────             │
│      添加配置...            │
│      删除当前配置            │
│  已连接节点       ▸         │
│    easytier-moon            │
│    10.126.126.7 • p2p      │
│    60ms • 0.0% • v2.4.5    │
│    NanoPi_R4S               │
│    10.126.126.1 • relay(2)  │
│    59ms • 0.0% • v2.4.5    │
├─────────────────────────────┤
│  关于                       │
│  退出                       │
└─────────────────────────────┘
```

## 安装

### 下载

前往 [Releases](https://github.com/huiyi9420/EasyTierBar/releases) 页面下载最新版 `EasyTierBar-aarch64-macos.zip`。

### 安装步骤

1. 解压下载的 zip 文件
2. 将 `EasyTierBar.app` 拖入 `/Applications` 目录
3. 首次启动：右键点击应用 → 选择「打开」（绕过 Gatekeeper）
4. 菜单栏出现天线图标

### 首次使用

启动后应用会引导你添加第一个网络配置：

1. 输入配置名称（如 `Home`）
2. 输入网络地址（如 `udp://host:port/network`）
3. 点击「添加」

之后点击菜单栏图标即可一键连接。

## 构建

### 本地开发

需要 macOS + Xcode Command Line Tools：

```bash
# 编译
make

# 清理
make clean
```

编译产物位于 `build/EasyTierBar.app`。

### 依赖

运行时需要 `easytier-cli` 和 `easytier-core` 二进制文件，放置于 `EasyTierBar.app/Contents/Resources/` 目录。CI/CD 会自动处理。

## 项目结构

```
EasyTierBar/
├── main.swift              # 入口（5行）
├── AppDelegate.swift       # UI / 菜单逻辑
├── ServiceManager.swift    # easytier-cli 调用封装
├── ConfigManager.swift     # 多配置存储（UserDefaults）
└── Info.plist              # 应用配置
Makefile                    # 编译脚本
.github/workflows/build.yml # CI/CD 自动构建
```

## CI/CD

GitHub Actions 自动化流水线：

- **触发方式**：每 6 小时定时检查 + 手动触发
- **工作流程**：检测 EasyTier 新版本 → 下载 macOS 二进制 → 编译 Swift → 打包 .app → 发布 Release
- **产物**：`EasyTierBar-aarch64-macos.zip`（包含 easytier-cli + easytier-core）

## 技术细节

| 项目 | 说明 |
|------|------|
| 语言 | Swift 5 |
| 框架 | Cocoa / AppKit（原生 macOS） |
| 架构 | 状态栏 UI + launchd 系统服务 |
| 目标平台 | macOS aarch64 (Apple Silicon) |
| 服务管理 | `easytier-cli service` 原生 launchd 集成 |
| 权限 | 仅首次安装服务需要 sudo（AppleScript 弹窗） |

## 相关项目

- [EasyTier](https://github.com/EasyTier/EasyTier) — 开源 P2P VPN 组网工具

## License

MIT
