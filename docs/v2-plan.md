# EasyTierBar v2 Plan

**Created:** 2026-04-26
**Status:** Planning
**Branch:** v2

## Problem

v1 版本每次启动/停止 EasyTier 都需要输入管理员密码。原因是 `easytier-core` 创建 TUN 虚拟网卡需要 root 权限，当前方案通过 AppleScript `do shell script ... with administrator privileges` 执行 `launchctl load/unload`，每次操作都会弹出系统认证框。

## Research Summary

### Analyzed Approaches

| Project | Approach | System Modification | Password Frequency |
|---------|----------|---------------------|-------------------|
| EasyTier Official GUI | AuthorizationExecuteWithPrivileges, entire GUI runs as root | None | Every launch |
| clash-verge-rev | Persistent root service + custom IPC | LaunchDaemon + Helper Tool + IPC socket | Once (install) |
| v1 (current) | AppleScript sudo for each launchctl operation | None | Every start/stop |

### Source Code Verified (EasyTier/EasyTier repository)

1. **`core.rs:run_main()`** — RPC server starts BEFORE any network instance. Core can run idle with only RPC listening.
2. **`instance_manage.rs`** — Full RPC interface: `run_network_instance`, `delete_network_instance`, `list_network_instance`, `collect_network_info`.
3. **`instance_manager.rs`** — Dynamic instance lifecycle: create, delete, retain. Supports `--config-dir` with automatic `.toml` persistence.
4. **RPC portal** — TCP on `127.0.0.1:15888`, accessible to non-root users. No Unix socket permission restrictions.
5. **`easytier-cli`** — Already used in v1 for `peer list` via RPC, confirming non-root RPC access works.

## Solution: LaunchDaemon Service Mode + RPC Dynamic Control

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    EasyTierBar (non-root)                    │
│  ┌─────────┐  ┌──────────────┐  ┌───────────────────────┐  │
│  │ Install  │  │  Start/Stop  │  │  Peer List / Status   │  │
│  │ Service  │  │  via RPC     │  │  via easytier-cli     │  │
│  └────┬─────┘  └──────┬───────┘  └───────────┬───────────┘  │
│       │ sudo (once)    │ no root               │ no root       │
└───────┼────────────────┼───────────────────────┼──────────────┘
        │                │                       │
        ▼                ▼                       ▼
┌─────────────────────────────────────────────────────────────┐
│              LaunchDaemon (root, persistent)                  │
│         /Library/LaunchDaemons/com.easytier.core.plist       │
│                                                              │
│  easytier-core --daemon --config-dir /path/to/configs       │
│                                                              │
│  ┌─────────────┐  ┌──────────────────┐  ┌───────────────┐  │
│  │ RPC Server  │  │ Network Instance │  │ Config Dir     │  │
│  │ :15888      │  │ Manager          │  │ (.toml files)  │  │
│  └─────────────┘  └──────────────────┘  └───────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Lifecycle

| Operation | Method | Root Required | Frequency |
|-----------|--------|---------------|-----------|
| Install service | AppleScript sudo, create LaunchDaemon plist | Yes | Once |
| Start network | RPC `run_network_instance` via easytier-cli | No | Every use |
| Stop network | RPC `delete_network_instance` via easytier-cli | No | Every use |
| Check status | RPC `list_network_instance` / `collect_network_info` | No | Every use |
| Peer list | RPC via `easytier-cli peer list` (already works) | No | Every use |
| Uninstall service | AppleScript sudo, unload + delete plist + cleanup | Yes | Once |

### System Modifications

| File/Directory | Purpose | Created By | Removed By |
|---------------|---------|------------|------------|
| `/Library/LaunchDaemons/com.easytier.core.plist` | LaunchDaemon config | Install | Uninstall |
| Config dir (app-managed) | Network instance .toml files | Install | Uninstall |

No sudoers, no helper scripts, no additional system files.

## Implementation Plan

### Phase 1: Service Infrastructure

- Add `installService()` to ServiceManager — one-time LaunchDaemon setup
- Add `uninstallService()` to ServiceManager — clean removal with confirmation
- Add `isServiceInstalled()` — check LaunchDaemon plist existence
- Update LaunchDaemon plist to use `--daemon --config-dir` mode

### Phase 2: RPC-Based Network Control

- Rewrite `startService()` — use `easytier-cli` or direct RPC to call `run_network_instance`
- Rewrite `stopService()` — use `easytier-cli` or direct RPC to call `delete_network_instance`
- Rewrite `checkStatus()` — use RPC `list_network_instance` instead of `pgrep`
- Remove `runAppleScriptSudo()` — no longer needed for daily operations

### Phase 3: UI Integration

- Add "Install Service" menu item to AppDelegate
- Add "Uninstall Service" menu item with confirmation dialog
- Auto-detect service installation status on launch
- Guide first-time users through installation

### Phase 4: Config & Cleanup

- Adapt ConfigManager to generate .toml configs compatible with RPC requests
- Ensure config-dir is properly managed (created on install, cleaned on uninstall)
- Handle edge cases: service not installed, service crashed, config mismatch

## Files to Modify

| File | Changes |
|------|---------|
| `ServiceManager.swift` | Major rewrite: add install/uninstall, replace launchctl with RPC |
| `AppDelegate.swift` | Add install/uninstall menu items, auto-detect logic |
| `ConfigManager.swift` | May need .toml generation for RPC config |

## Acceptance Criteria

- [ ] First launch prompts for password once to install service
- [ ] Subsequent start/stop operations complete without password prompt
- [ ] Peer list and status checking work without password
- [ ] Uninstall removes all system modifications cleanly
- [ ] App works correctly after reinstall
- [ ] Service survives system reboot (LaunchDaemon persistence)
