import SwiftUI

struct ConsoleCommands: Commands {
    @ObservedObject var store: ConsoleStore
    @AppStorage(ConsoleAppSettings.appLanguageKey) private var appLanguageRawValue = ConsoleLanguage.system.rawValue

    var body: some Commands {
        let _ = appLanguageRawValue

        SidebarCommands()

        CommandMenu(AppLocalization.string("menu.console", fallback: "Console")) {
            Button(AppLocalization.string("section.overview", fallback: "Overview")) {
                store.setSection(.overview)
            }
            .keyboardShortcut("0")

            Button(AppLocalization.string("section.nodes", fallback: "Nodes")) {
                store.setSection(.nodes)
            }
            .keyboardShortcut("1")

            Button(AppLocalization.string("section.skills", fallback: "Skills")) {
                store.setSection(.skills)
            }
            .keyboardShortcut("2")

            Divider()

            Button(AppLocalization.string("command.refresh_current_module", fallback: "Refresh Current Module")) {
                store.refreshCurrentSection()
            }
            .keyboardShortcut("r")

            Button(
                store.isInspectorPresented
                    ? AppLocalization.string("command.hide_inspector", fallback: "Hide Inspector")
                    : AppLocalization.string("command.show_inspector", fallback: "Show Inspector")
            ) {
                store.isInspectorPresented.toggle()
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
        }
    }
}
