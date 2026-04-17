# EasyTierBar

## What This Is

macOS 菜单栏工具，为 EasyTier VPN 提供图形化操作界面。状态栏图标实时反映连接状态，左键一键开关连接，右键查看所有已连接节点的详细信息（主机名、IP、延迟、丢包率、流量、版本等）。通过 `easytier-cli service` 集成 macOS 原生 launchd 服务管理，不需要手动配置 sudoers。

## Core Value

一键开关 EasyTier VPN 连接，无需打开终端手动操作。

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] 状态栏 SF Symbols 图标反映连接/断开状态
- [ ] 左键点击一键切换连接（通过 easytier-cli service start/stop）
- [ ] 右键菜单二级子菜单显示所有节点信息（7个字段：hostname/ipv4/cost/latency/loss_rate/traffic/version）
- [ ] 打开菜单时自动刷新状态（零后台轮询）
- [ ] 通过 easytier-cli service 注册 launchd 系统服务（root 运行）
- [ ] 退出应用时停止服务
- [ ] 禁用开机自启，仅手动启动
- [ ] GitHub Actions workflow 自动监听 EasyTier/EasyTier 新 release，自动下载二进制、编译、打包、发布

### Out of Scope

- 后台定期轮询状态 — 用户选择只在打开菜单时刷新，减少资源占用
- 开机自启动 — 用户明确要求禁用
- 点击节点 ping 测试 — 未来扩展
- 流量走势图 — 未来扩展
- 多配置切换 — 未来扩展

## Context

- EasyTier 是开源 P2P VPN 组网工具（https://github.com/EasyTier/EasyTier）
- easytier-core 需要 sudo 仅因为创建 TUN 虚拟网卡，其他功能（连接、peer 发现、路由、RPC）普通用户可用
- easytier-cli 原生支持 Launchd 服务管理（`service manager kind: Launchd`）
- easytier-cli 支持 `-o json` 输出结构化数据
- 当前网络有 7 个节点：MacBook-Pro-16, NanoPi_R4S, Gen8, 陈萍萍-公司电脑, Me-mini, 任佳荣, easytier-moon
- 已有初步版 EasyTierBar（Swift，仅开关，直接 spawn 进程需 sudo），需要重构

## Constraints

- **Tech Stack**: Swift + Cocoa + AppKit（原生 macOS 应用，不用 SwiftUI）
- **macOS**: 目标 aarch64 (Apple Silicon)
- **Binary**: easytier-cli/core 内嵌到 app bundle Resources 目录
- **Service**: 通过 easytier-cli service 集成 launchd，不手动配置 sudoers
- **No Dock Icon**: LSUIElement = true，仅菜单栏

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| launchd 系统服务 vs sudoers | macOS 原生服务管理，不需要手动编辑 sudoers，崩溃自动重启 | ✓ Good |
| 二级子菜单 vs 内联 | 节点多（7个）时内联会拉很长菜单，二级子菜单保持主菜单简洁 | — Pending |
| SF Symbols 系统图标 | 原生风格，自动适配深浅色模式，最小体积 | — Pending |
| 打开菜单时刷新 vs 后台轮询 | 用户选择零后台开销方案 | — Pending |
| 内嵌二进制 + GitHub Actions | 完全自动化，监听上游发版自动构建发布 | — Pending |
| 禁用开机自启 | 用户手动控制连接 | — Pending |
| 退出时停止服务 | 服务和 UI 生命周期绑定 | — Pending |

---
*Last updated: 2026-04-17 after initialization*
