# EasyTierBar v1 Requirements

## v1 Requirements

### UI

- [ ] **UI-01**: 状态栏图标使用 SF Symbols 显示连接状态（已连接/断开）
- [ ] **UI-02**: 左键点击图标切换连接状态（启动 → 停止，停止 → 启动）
- [ ] **UI-03**: 右键菜单显示"已连接节点"二级子菜单
- [ ] **UI-04**: 每个节点显示全部 7 个字段（hostname, ipv4, cost, latency, loss_rate, traffic, version）
- [ ] **UI-05**: 打开菜单时自动刷新状态和节点列表
- [ ] **UI-06**: 关于对话框显示版本信息
- [ ] **UI-07**: 退出菜单项

### Service Integration

- [ ] **SVC-01**: 通过 easytier-cli service start/stop 管理连接
- [ ] **SVC-02**: 通过 easytier-cli service status 检测运行状态
- [ ] **SVC-03**: easytier-cli 路径从 app bundle Resources 加载（Bundle.main.path）
- [ ] **SVC-04**: 退出应用时停止服务

### Data

- [ ] **DAT-01**: 解析 easytier-cli -o json peer list 输出，构建节点列表
- [ ] **DAT-02**: 错误处理：CLI 不可用时显示友好错误信息

### CI/CD

- [ ] **CI-01**: GitHub Actions workflow 定时检测 EasyTier/EasyTier 新 release
- [ ] **CI-02**: 自动下载 macOS aarch64 二进制
- [ ] **CI-03**: 自动编译 Swift 并打包 .app（二进制内嵌 Resources）
- [ ] **CI-04**: 自动发布新 release 到 GitHub

## v2 Requirements (Deferred)

- 点击节点 ping 测试延迟
- 流量走势图
- 多配置切换
- 应用内检查更新提示

## Out of Scope

- 后台定期轮询 — 打开菜单时刷新即可
- 开机自启动 — 用户明确禁用
- SwiftUI — 使用 AppKit 保证兼容性

## Traceability

| Phase | Requirements | Status |
|-------|-------------|--------|
| Phase 1: Core App | UI-01, UI-02, SVC-01, SVC-02, SVC-03, SVC-04, DAT-01, DAT-02 | — |
| Phase 2: Menu & Data | UI-03, UI-04, UI-05, UI-06, UI-07 | — |
| Phase 3: CI/CD | CI-01, CI-02, CI-03, CI-04 | — |
