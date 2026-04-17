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
    var onConfigsChanged: (() -> Void)?

    var selectedConfig: NetworkConfig? {
        configs.first { $0.id == selectedId }
    }

    var hasConfigs: Bool {
        !configs.isEmpty
    }

    private init() {
        load()
    }

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
        onConfigsChanged?()
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
