import SwiftUI

@main
struct EvomapConsoleApp: App {
    @StateObject private var store = ConsoleStore()
    @AppStorage(ConsoleAppSettings.appLanguageKey) private var appLanguageRawValue = ConsoleLanguage.system.rawValue

    private var appLanguage: ConsoleLanguage {
        ConsoleLanguage(rawValue: appLanguageRawValue) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .id(appLanguage.rawValue)
                .frame(minWidth: 1180, minHeight: 760)
                .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
        }
        .commands {
            ConsoleCommands(store: store)
        }

        Settings {
            ConsoleSettingsView()
                .id(appLanguage.rawValue)
                .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
        }
    }
}
