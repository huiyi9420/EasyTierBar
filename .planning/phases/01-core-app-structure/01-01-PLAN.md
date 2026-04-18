---
wave: 1
depends_on: []
files_modified:
  - EasyTierBar/ConfigManager.swift
autonomous: true
requirements:
  - SVC-03
objective: 创建配置管理模块，支持多网络配置的增删改查和持久化存储
---

# Plan 01: ConfigManager.swift — 配置管理模块

## Objective

实现 `ConfigManager` 类，管理多网络配置（name + URL），使用 UserDefaults 持久化。提供增删改查、当前选择、首次引导等功能。此模块为 AppDelegate 和 ServiceManager 的基础设施。

## Context

从 CONTEXT.md 决策：
- 完整多配置支持：可在菜单中新增/删除/切换网络配置
- 配置存储：UserDefaults 数组，每项包含 name + URL
- 首次启动无配置时自动弹出引导对话框添加第一个配置

## Tasks

### Task 1: 创建 ConfigManager.swift 基本结构

<read_first>
- EasyTierBar/main.swift — 了解现有代码结构
</read_first>

<action>
创建文件 `EasyTierBar/ConfigManager.swift`：

```swift
import Foundation

struct NetworkConfig: Codable, Equatable {
    let id: UUID
    let name: String
    let url: String

    init(id: UUID = UUID(), name: String, url: String) {
        self.id = id
        self.name = name
        self.url = url
    }
}

class ConfigManager {
    static let shared = ConfigManager()
    private let configsKey = "networkConfigs"
    private let selectedKey = "selectedConfigId"

    private(set) var configs: [NetworkConfig] = []
    private(set) var selectedId: UUID?

    private init() {
        load()
    }

    var selectedConfig: NetworkConfig? {
        configs.first { $0.id == selectedId }
    }

    var hasConfigs: Bool {
        !configs.isEmpty
    }
}
```
</action>

<acceptance_criteria>
- `EasyTierBar/ConfigManager.swift` 文件存在
- 文件包含 `NetworkConfig` struct，有 id/name/url 三个字段
- 文件包含 `ConfigManager` class，有 `configs`/`selectedId`/`selectedConfig`/`hasConfigs` 属性
- ConfigManager 使用 `static let shared` 单例模式
</acceptance_criteria>

### Task 2: 实现持久化和 CRUD 方法

<read_first>
- EasyTierBar/ConfigManager.swift — 当前文件状态
</read_first>

<action>
在 `ConfigManager` 类中添加以下方法：

```swift
    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: configsKey) else { return }
        configs = (try? JSONDecoder().decode([NetworkConfig].self, from: data)) ?? []
        if let idString = UserDefaults.standard.string(forKey: selectedKey),
           let uuid = UUID(uuidString: idString) {
            selectedId = uuid
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(configs) {
            UserDefaults.standard.set(data, forKey: configsKey)
        }
    }

    // MARK: - CRUD

    func addConfig(name: String, url: String) -> NetworkConfig {
        let config = NetworkConfig(name: name, url: url)
        configs.append(config)
        if configs.count == 1 {
            selectedId = config.id
            UserDefaults.standard.set(config.id.uuidString, forKey: selectedKey)
        }
        save()
        return config
    }

    func deleteConfig(id: UUID) {
        configs.removeAll { $0.id == id }
        if selectedId == id {
            selectedId = configs.first?.id
            UserDefaults.standard.set(selectedId?.uuidString, forKey: selectedKey)
        }
        save()
    }

    func selectConfig(id: UUID) {
        guard configs.contains(where: { $0.id == id }) else { return }
        selectedId = id
        UserDefaults.standard.set(id.uuidString, forKey: selectedKey)
    }
}
```
</action>

<acceptance_criteria>
- ConfigManager 包含 `load()` 和 `save()` 私有方法
- ConfigManager 包含 `addConfig(name:url:)` 方法，返回 NetworkConfig
- ConfigManager 包含 `deleteConfig(id:)` 方法
- ConfigManager 包含 `selectConfig(id:)` 方法
- addConfig 在只有 1 个配置时自动选中
- deleteConfig 在删除选中配置时自动选中第一个
- 所有写操作调用 save() 持久化
</acceptance_criteria>

### Task 3: 添加配置变更通知

<read_first>
- EasyTierBar/ConfigManager.swift — 当前文件状态
</read_first>

<action>
在 `ConfigManager` 类中添加通知机制：

```swift
    // 在属性声明区域添加
    var onConfigsChanged: (() -> Void)?

    // 在 save() 方法末尾添加
    onConfigsChanged?()
```

更新 `save()` 方法为：
```swift
    private func save() {
        if let data = try? JSONEncoder().encode(configs) {
            UserDefaults.standard.set(data, forKey: configsKey)
        }
        onConfigsChanged?()
    }
```
</action>

<acceptance_criteria>
- ConfigManager 有 `onConfigsChanged: (() -> Void)?` 回调属性
- save() 方法末尾调用 `onConfigsChanged?()`
</acceptance_criteria>

## Verification

1. `EasyTierBar/ConfigManager.swift` 编译无错误
2. NetworkConfig 有 UUID + name + url
3. ConfigManager 支持完整的 CRUD 操作
4. 所有操作持久化到 UserDefaults
5. 选中状态正确维护

## must_haves

- 多配置数组存储
- UserDefaults 持久化
- 当前选中配置跟踪
- 增删选操作
- 变更回调通知
