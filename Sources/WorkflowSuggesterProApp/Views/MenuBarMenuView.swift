import AppKit
import SwiftUI

struct MenuBarMenuView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Panel") { openPanel() }

        Button(appModel.isGenerating ? "Regenerating…" : "Regenerate Now") {
            appModel.regenerate()
            openPanel()
        }
        .disabled(appModel.isGenerating)

        Button("Reveal Scripts Folder in Finder") { appModel.revealScriptsFolder() }

        Divider()

        Button("Quit") { NSApplication.shared.terminate(nil) }
    }

    private func openPanel() {
        openWindow(id: AppScene.dashboard)
        NSApp.activate(ignoringOtherApps: true)
    }
}
