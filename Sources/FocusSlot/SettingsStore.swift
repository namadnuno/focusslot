import FocusSlotCore
import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var settings: SchedulingSettings {
        didSet {
            save()
        }
    }

    private let defaults: UserDefaults
    private let key = "FocusSlot.settings.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(SchedulingSettings.self, from: data) {
            settings = decoded
        } else {
            settings = SchedulingSettings()
        }
    }

    func updateCalendarIdentifier(_ identifier: String?) {
        settings.calendarIdentifier = identifier?.isEmpty == true ? nil : identifier
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
