import SwiftUI

@main
struct KiteNativeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = HabitViewModel()

    var body: some Scene {
        WindowGroup {
            ChecklistView()
                .environmentObject(store)
                .frame(minWidth: 545, idealWidth: 575, maxWidth: 615, minHeight: 700, idealHeight: 760)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}
