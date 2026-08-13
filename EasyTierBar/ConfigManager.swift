import Foundation

/// 配置中心连接配置。
/// 两字段独立、各自必填：协议/端口/路径都不同，不能互相推导。
/// - configServerUrl: 传给 easytier-core 的 `-w` 参数，core 用它连接配置中心。如 `udp://web-et.seeyon.ink:22020/admin`
/// - webConsoleUrl:    浏览器打开的 web 控制台地址。如 `https://web-et.seeyon.ink`
struct CenterConfig: Codable, Equatable {
    var configServerUrl: String
    var webConsoleUrl: String
}

class ConfigManager {
    static let shared = ConfigManager()
    private let key = "centerConfig"

    private(set) var center: CenterConfig?
    var onConfigChanged: (() -> Void)?

    var hasCenter: Bool { center != nil }

    /// 状态自动检测间隔（秒）。0 = 关闭定时检测。默认 300（5 分钟），
    /// 平衡及时性与耗电（每次检测要起 2 个 easytier-cli 子进程）。
    var statusIntervalSeconds: Double {
        get {
            let v = UserDefaults.standard.object(forKey: "statusInterval") as? Double
            return v ?? 300
        }
        set { UserDefaults.standard.set(newValue, forKey: "statusInterval") }
    }

    private init() {
        load()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        center = try? JSONDecoder().decode(CenterConfig.self, from: data)
    }

    func saveCenter(_ config: CenterConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: key)
        }
        center = config
        onConfigChanged?()
    }
}
