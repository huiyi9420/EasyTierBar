# Phase 3: CI/CD Pipeline - Context

**Gathered:** 2026-04-17
**Status:** Ready for planning
**Mode:** Infrastructure phase — minimal context

<domain>
## Phase Boundary

创建 GitHub Actions workflow，实现：
1. 自动检测 EasyTier/EasyTier 新 release
2. 下载 macOS aarch64 二进制
3. Swift 编译 EasyTierBar
4. 打包 .app（二进制内嵌 Resources）
5. 发布 Release 到 GitHub

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
所有实现细节由 Claude 决定 — 纯基础设施阶段。

</decisions>

<code_context>
## Existing Code Insights

### Project Structure
- `EasyTierBar/main.swift` + `ConfigManager.swift` + `ServiceManager.swift` + `AppDelegate.swift`
- `EasyTierBar/Info.plist`
- `Makefile` — swiftc 编译 + app bundle 打包
- easytier-cli/easytier-core 在项目根目录（开发用）

### Build Command
```bash
swiftc -o EasyTierBar EasyTierBar/*.swift -framework Cocoa
```

### App Bundle Structure
```
EasyTierBar.app/
  Contents/
    Info.plist
    MacOS/EasyTierBar
    Resources/easytier-cli
    Resources/easytier-core
```

</code_context>

<specifics>
## Specific Ideas

- Workflow 触发：`schedule` (每 6 小时检查) + `workflow_dispatch` (手动)
- 比对最新 EasyTier tag vs 已有 Release tag，避免重复构建
- 使用 `macos-15` runner
- Release name 格式：`EasyTierBar {easytier-tag}`
- 产物：`EasyTierBar-aarch64-macos.zip`

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
