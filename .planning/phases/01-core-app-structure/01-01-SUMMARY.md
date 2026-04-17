---
phase: 01-core-app-structure
plan: 01-01
status: complete
---

## Plan 01-01: ConfigManager — 配置管理模块

### What was built
- `NetworkConfig` struct: UUID + name + url，Codable + Equatable
- `ConfigManager` singleton: UserDefaults 持久化多配置数组
- CRUD: addConfig / deleteConfig / selectConfig
- 选中状态自动维护
- onConfigsChanged 回调通知

### Key files
- Created: `EasyTierBar/ConfigManager.swift`

### Deviations
- None — plan executed as specified

### Self-Check: PASSED
