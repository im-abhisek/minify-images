import AppKit
import SwiftUI

@main
struct MinifyImagesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .onAppear {
                    appDelegate.model = model
                    NSWindow.allowsAutomaticWindowTabbing = false
                }
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .windowResizability(.contentSize)
        .defaultSize(width: 760, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") {
                    model.chooseFiles()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button("Convert") {
                    model.convert()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!model.canConvert)

                Button("Cancel") {
                    model.cancel()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .disabled(!model.isRunning)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func application(_ sender: NSApplication, open urls: [URL]) {
        Task { @MainActor in
            model?.addDroppedURLs(urls)
        }
    }
}
