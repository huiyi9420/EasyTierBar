# Phase 1: Core App Structure - Context

**Gathered:** 2026-04-17
**Status:** Ready for planning

<domain>
## Phase Boundary

搭建 Swift 菜单栏应用骨架，集成 easytier-cli service 管理连接，包含多配置管理功能。

核心交付：
1. 状态栏 SF Symbols 图标反映连接/断开状态
2. 左键切换当前配置的连接状态
3. 多配置管理（新增/删除/切换/选择当前配置）
4. 通过 easytier-cli service start/stop 管理连接
5. 通过 easytier-cli service status 检测运行状态
6. easytier-cli 从 app bundle Resources 加载
7. 退出应用时停止服务
8. 首次启动引导用户添加配置
9. 服务未安装时通过 AppleScript sudo 弹窗自动安装

不包含：节点信息子菜单（Phase 2）、CI/CD 自动构建（Phase 3）

</domain>

<decisions>
## Implementation Decisions

### 进程执行模型
- 混合模式：status 检查异步（DispatchQueue.global()），start/stop 同步（waitUntilExit）
- status 检查失败时静默降级为"断开"状态，不弹窗打扰用户
- 服务未安装时通过 AppleScript do shell script with administrator privileges 弹窗自动安装

### 配置管理
- 完整多配置支持：可在菜单中新增/删除/切换网络配置
- 配置存储：UserDefaults 数组，每项包含 name + URL
- 菜单内配置列表（单选样式），当前选中配置有勾选标记
- "添加配置"菜单项弹出输入对话框（名称 + 网络 URL）
- "删除配置"菜单项删除当前选中的配置
- 首次启动无配置时，自动弹出引导对话框添加第一个配置
- 启动/停止操作针对当前选中的配置

### 构建与代码结构
- 构建方式：swiftc 命令行编译（无 Xcode 项目依赖）
- 4 文件拆分：main.swift（入口）+ AppDelegate.swift（UI/菜单逻辑）+ ServiceManager.swift（easytier-cli 调用）+ ConfigManager.swift（配置存储）
- 启动时验证 easytier-cli 二进制存在于 Bundle Resources，不存在则提示错误

### Claude's Discretion
- 各类内部实现细节（错误处理粒度、日志级别、具体变量命名等）
- UI 细节布局（菜单项顺序、分隔线位置等）

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- EasyTierBar/main.swift — 现有菜单栏应用骨架，包含 statusItem、menu、toggleService、checkStatus 基本结构可参考
- EasyTierBar/Info.plist — 已配置 LSUIElement=true
- easytier-cli / easytier-core — 已存在于项目根目录，后续需内嵌到 app bundle Resources

### Established Patterns
- SF Symbols 天线图标：已连接用 `antenna.radiowaves.left.and.right`，断开用 `.slash` 变体
- AppKit + NSStatusItem 菜单栏模式
- LSUIElement=true 隐藏 Dock 图标

### Integration Points
- Bundle.main.path(forResource: "easytier-cli", ofType: nil) — 从 Resources 加载 CLI
- easytier-cli service start/stop/status — 服务管理接口
- easytier-cli service install — 首次安装（需要 sudo，通过 AppleScript）

</code_context>

<specifics>
## Specific Ideas

- 菜单结构参考设计规格文档的右键菜单设计（但不含节点子菜单）
- AppleScript `do shell script ... with administrator privileges` 实现 sudo 弹窗
- 配置数组结构示例：`[{"name": "Home", "url": "udp://111.170.131.76:22020/zhaolulu"}, ...]`

</specifics>

<deferred>
## Deferred Ideas

- 节点信息子菜单（Phase 2）
- CI/CD 自动构建（Phase 3）
- 点击节点 ping 测试延迟（v2+）
- 流量走势图（v2+）
- 应用内检查更新提示（v2+）

</deferred>
