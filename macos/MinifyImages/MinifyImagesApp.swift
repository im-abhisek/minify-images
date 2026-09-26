import AppKit
import SwiftUI

@main
struct MinifyImagesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        // One window for the life of the app. WindowGroup was opening a new
        // window for every file passed to `open -a` / Open With.
        Window("Minify Images", id: "main") {
            ContentView()
                .preferredColorScheme(.dark)
                .environment(model)
                .background {
                    MainWindowBridge()
                }
                .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
                .onAppear {
                    NSApp.appearance = NSAppearance(named: .darkAqua)
                    NSWindow.allowsAutomaticWindowTabbing = false
                }
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 800, height: 560)
        .commands {
            // Replaces File > New / New Window so a second window cannot be created.
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
    var showMainWindow: (@MainActor () -> Void)?
    private var pendingURLs: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Dock click with no window open. Returning true lets the single Window scene reopen.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            let show = self.showMainWindow
            Task { @MainActor in
                show?()
                self.orderMainWindowFront()
            }
        }
        return true
    }

    func application(_ sender: NSApplication, open urls: [URL]) {
        Task { @MainActor in
            self.present(urls: urls)
        }
    }

    @MainActor
    func attach(model: AppModel, show: @escaping @MainActor () -> Void) {
        self.model = model
        self.showMainWindow = show
        guard !self.pendingURLs.isEmpty else { return }
        let urls = self.pendingURLs
        self.pendingURLs = []
        model.addDroppedURLs(urls)
    }

    @MainActor
    private func present(urls: [URL]) {
        if let model = self.model {
            model.addDroppedURLs(urls)
        } else {
            self.pendingURLs.append(contentsOf: urls)
        }
        self.showMainWindow?()
        self.orderMainWindowFront()
    }

    @MainActor
    private func orderMainWindowFront() {
        NSApp.activate()
        if let window = NSApp.windows.first(where: { $0.canBecomeMain && ($0.isVisible || $0.isMiniaturized) }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}

/// Captures openWindow while the main window exists so a later external open can bring it back.
private struct MainWindowBridge: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(AppModel.self) private var model

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .onAppear {
                guard let delegate = NSApp.delegate as? AppDelegate else { return }
                let openWindow = self.openWindow
                delegate.attach(model: self.model) { @MainActor in
                    openWindow(id: "main")
                }
            }
    }
}
