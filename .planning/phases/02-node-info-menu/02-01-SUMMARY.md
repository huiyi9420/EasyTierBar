---
phase: 02-node-info-menu
plan: 02-01
status: complete
---

## Plan 02-01: Node Info Submenu — 节点信息子菜单

### What was built
- ServiceManager.Peer struct: 8 fields matching easytier-cli JSON output
- ServiceManager.fetchPeerList: async peer data fetching with JSON parsing
- AppDelegate peerMenu: "已连接节点" submenu with all 7 fields per node
- Auto-refresh on menu open via menuWillOpen
- Placeholder messages for empty/error states

### Key files
- Modified: `EasyTierBar/ServiceManager.swift` (added Peer struct + fetchPeerList)
- Modified: `EasyTierBar/AppDelegate.swift` (added peerMenu + updatePeerList)

### Deviations
- Added `try` to readToEnd call (compiler error fix)

### Self-Check: PASSED
