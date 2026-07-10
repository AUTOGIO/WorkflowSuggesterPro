import Foundation

struct AppPreferences: Codable, Sendable {
    var lookbackDays: Int
    var minOccurrences: Int
    var providerMode: AppModel.ProviderMode

    static let defaults = AppPreferences(lookbackDays: 14, minOccurrences: 4, providerMode: .onDeviceFirst)
}

// Not Sendable: UserDefaults doesn't conform, and this type is only ever touched from
// AppModel's @MainActor context — never captured by a Task.detached closure.
struct AppPreferencesStore {
    private let userDefaults: UserDefaults
    private let key = "WorkflowSuggesterPro.preferences"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> AppPreferences {
        guard let data = userDefaults.data(forKey: key),
              let preferences = try? JSONDecoder().decode(AppPreferences.self, from: data) else {
            return .defaults
        }
        return preferences
    }

    func save(_ preferences: AppPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        userDefaults.set(data, forKey: key)
    }
}
