import SwiftUI

@main
struct PlugWatchApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra("PlugWatch", systemImage: appModel.menuBarSymbol) {
            MenuBarContent(model: appModel)
        }
        .menuBarExtraStyle(.menu)
    }
}
