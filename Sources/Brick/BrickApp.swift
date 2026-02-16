import SwiftUI

@main
struct BrickApp: App {
    @StateObject private var appSettings = AppSettings()

    var body: some Scene {
        MenuBarExtra("Brick", systemImage: "shield.fill") {
            MenuBarView()
                .environmentObject(appSettings)
        }
        .menuBarExtraStyle(.window)
    }
}
