# Phase 2: Node Info Menu - Context

**Gathered:** 2026-04-17
**Status:** Ready for planning
**Mode:** Auto-generated (design fully specified in prior design doc)

<domain>
## Phase Boundary

实现已连接节点二级子菜单，解析 `easytier-cli -o json peer list` 输出，展示全部 7 个字段。

核心交付：
1. 右键菜单显示"已连接节点"二级子菜单
2. 每个节点显示 hostname, ipv4, cost, latency, loss_rate, traffic, version
3. 打开菜单时自动刷新节点列表
4. 无节点时显示占位提示

不包含：CI/CD 自动构建（Phase 3）

Phase 1 已实现：关于对话框（UI-06）、退出功能（UI-07）、菜单打开刷新机制。

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
所有实现细节由 Claude 决定 — 设计文档已完整定义所有 UI 和数据格式。

### 已锁定决策（来自设计文档）
- 节点显示格式：`hostname • ipv4 • cost • latency ms • loss_rate • rx/tx • version`
- 数据源：`easytier-cli -o json peer list`
- 菜单打开时刷新（已有 menuWillOpen 机制）
- 无节点时显示"(无已连接节点)"
- 获取失败时显示"(获取节点列表失败)"

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `EasyTierBar/AppDelegate.swift` — 已有 mainMenu/configMenu/statusItem 结构
- `EasyTierBar/ServiceManager.swift` — 已有 Process 调用模式，checkStatus 异步刷新
- `EasyTierBar/ConfigManager.swift` — 配置管理已完成

### Established Patterns
- 菜单构建：NSMenu + NSMenuItem 模式
- 异步刷新：DispatchQueue.global + DispatchQueue.main.async
- 错误处理：静默降级 + placeholder 菜单项

### Integration Points
- AppDelegate 的 menuWillOpen 方法 — 需在此处添加 updatePeerList 调用
- AppDelegate 的 mainMenu — 需在配置子菜单后添加"已连接节点"子菜单
- ServiceManager 的 cliPath — 共享 easytier-cli 路径

</code_context>

<specifics>
## Specific Ideas

- peer list JSON 格式参考：`[{"hostname":"easytier-moon","ipv4":"10.126.126.7","cost":"p2p","lat_ms":"60.17","loss_rate":"0.0%","rx_bytes":"2.90 kB","tx_bytes":"2.66 kB","version":"2.4.5"}]`
- 每个节点一行显示所有字段，用 `•` 分隔
- 节点菜单项不可点击（action: nil），仅展示信息

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
