---
phase: 01-core-app-structure
plan: 01-02
status: complete
---

## Plan 01-02: ServiceManager — 服务集成模块

### What was built
- `ServiceManager` singleton with cliPath from Bundle.main.path
- Async checkStatus via DispatchQueue.global
- Sync startService / stopService with waitUntilExit
- AppleScript `do shell script ... with administrator privileges` for install
- Development mode fallback path for cliPath
- onStatusChanged callback

### Key files
- Created: `EasyTierBar/ServiceManager.swift`

### Deviations
- Simplified dev fallback path (removed unused variable assignment)

### Self-Check: PASSED
