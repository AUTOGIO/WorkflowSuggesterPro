import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct WorkflowSuggesterProApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup("WorkflowSuggester Pro", id: AppScene.dashboard) {
            DashboardView().environment(appModel)
        }
        .defaultSize(width: 900, height: 640)

        Settings {
            PreferencesView().environment(appModel)
        }

        MenuBarExtra {
            MenuBarMenuView().environment(appModel)
        } label: {
            Label("WorkflowSuggester Pro", systemImage: "sparkles")
        }
    }
}
