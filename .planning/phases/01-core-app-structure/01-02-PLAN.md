---
wave: 1
depends_on: []
files_modified:
  - EasyTierBar/ServiceManager.swift
autonomous: true
requirements:
  - SVC-01
  - SVC-02
  - SVC-03
  - SVC-04
objective: 创建服务管理模块，封装 easytier-cli 调用，支持异步状态检查和 AppleScript sudo 安装
---

# Plan 02: ServiceManager.swift — 服务集成模块

## Objective

实现 `ServiceManager` 类，封装 easytier-cli 的 service start/stop/status 调用。从 Bundle Resources 定位二进制，提供异步状态检查、同步启停控制、AppleScript sudo 安装等功能。

## Context

从 CONTEXT.md 决策：
- 混合模式：status 检查异步（DispatchQueue.global()），start/stop 同步（waitUntilExit）
- status 检查失败时静默降级为"断开"状态
- 服务未安装时通过 AppleScript `do shell script ... with administrator privileges` 自动安装
- easytier-cli 从 app bundle Resources 加载
- 启动时验证 easytier-cli 二进制存在

## Tasks

### Task 1: 创建 ServiceManager.swift 基本结构

<read_first>
- EasyTierBar/main.swift — 了解现有 Process 调用模式
</read_first>

<action>
创建文件 `EasyTierBar/ServiceManager.swift`：

```swift
import Foundation

class ServiceManager {
    static let shared = ServiceManager()

    let cliPath: String?
    var isRunning = false
    var isInstalled = true
    var onStatusChanged: ((Bool) -> Void)?

    private init() {
        cliPath = Bundle.main.path(forResource: "easytier-cli", ofType: nil)
        if cliPath == nil {
            // 开发模式：尝试从项目目录加载
            let devPath = "/Users/zhaolulu/开发/easytier-macos-aarch64/easytier-cli"
            if FileManager.default.fileExists(atPath: devPath) {
                cliPath = devPath
            }
        }
    }

    var isReady: Bool {
        cliPath != nil
    }
}
```
</action>

<acceptance_criteria>
- `EasyTierBar/ServiceManager.swift` 文件存在
- ServiceManager 有 `cliPath`、`isRunning`、`isInstalled`、`onStatusChanged` 属性
- ServiceManager 有 `isReady` 计算属性
- cliPath 优先从 Bundle.main.path 加载，fallback 到开发路径
</acceptance_criteria>

### Task 2: 实现异步状态检查

<read_first>
- EasyTierBar/ServiceManager.swift — 当前文件状态
</read_first>

<action>
在 `ServiceManager` 类中添加：

```swift
    // MARK: - Status Check (Async)

    func checkStatus(completion: @escaping (Bool) -> Void = { _ in }) {
        guard let path = cliPath else {
            isRunning = false
            completion(false)
            onStatusChanged?(false)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = ["service", "status"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()
                let running = process.terminationStatus == 0

                DispatchQueue.main.async {
                    self?.isRunning = running
                    self?.isInstalled = true
                    completion(running)
                    self?.onStatusChanged?(running)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.isRunning = false
                    self?.isInstalled = true
                    completion(false)
                    self?.onStatusChanged?(false)
                }
            }
        }
    }
```
</action>

<acceptance_criteria>
- ServiceManager 有 `checkStatus(completion:)` 方法
- 使用 `DispatchQueue.global(qos: .userInitiated)` 异步执行
- 结果通过 `DispatchQueue.main.async` 回到主线程
- 更新 `isRunning` 属性
- 调用 `onStatusChanged` 回调
- cliPath 为 nil 时直接返回 false
</acceptance_criteria>

### Task 3: 实现同步启停控制

<read_first>
- EasyTierBar/ServiceManager.swift — 当前文件状态
</read_first>

<action>
在 `ServiceManager` 类中添加：

```swift
    // MARK: - Service Control (Sync)

    func startService(configUrl: String) -> Bool {
        guard let path = cliPath else { return false }

        // 如果服务未安装，先安装
        if !isInstalled {
            if !installService(configUrl: configUrl) {
                return false
            }
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["service", "start"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let success = process.terminationStatus == 0
            if success {
                isRunning = true
                onStatusChanged?(true)
            }
            return success
        } catch {
            return false
        }
    }

    func stopService() -> Bool {
        guard let path = cliPath else { return false }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["service", "stop"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let success = process.terminationStatus == 0
            if success {
                isRunning = false
                onStatusChanged?(false)
            }
            return success
        } catch {
            return false
        }
    }
```
</action>

<acceptance_criteria>
- ServiceManager 有 `startService(configUrl:)` 方法，返回 Bool
- ServiceManager 有 `stopService()` 方法，返回 Bool
- startService 在未安装时调用 installService
- 两者都使用同步 `waitUntilExit`
- 成功后更新 isRunning 并调用回调
</acceptance_criteria>

### Task 4: 实现 AppleScript sudo 安装

<read_first>
- EasyTierBar/ServiceManager.swift — 当前文件状态
</read_first>

<action>
在 `ServiceManager` 类中添加：

```swift
    // MARK: - Install (AppleScript sudo)

    @discardableResult
    func installService(configUrl: String) -> Bool {
        guard let path = cliPath else { return false }

        let command = "\"\(path)\" service install --disable-autostart true -w \"\(configUrl)\""
        let script = "do shell script \"\(command)\" with administrator privileges"

        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)

        if let error = error {
            // 用户取消或安装失败
            return false
        }

        isInstalled = true
        return true
    }
```
</action>

<acceptance_criteria>
- ServiceManager 有 `installService(configUrl:)` 方法
- 使用 `NSAppleScript` + `do shell script ... with administrator privileges`
- 安装命令包含 `--disable-autostart true -w` 参数
- 返回 Bool 表示成功/失败
- 用户取消时返回 false（不崩溃）
</acceptance_criteria>

## Verification

1. `EasyTierBar/ServiceManager.swift` 编译无错误
2. cliPath 从 Bundle Resources 正确定位
3. checkStatus 异步执行，结果回到主线程
4. startService/stopService 同步执行
5. installService 通过 AppleScript sudo 弹窗
6. 所有失败情况优雅降级

## must_haves

- Bundle.main.path 定位 easytier-cli
- 异步 status 检查
- 同步 start/stop
- AppleScript sudo 安装
- 开发模式 fallback 路径
- 失败静默降级
