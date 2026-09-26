import AppKit
import SwiftUI

@main
struct MinifyImagesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model: AppModel

    init() {
        let model = AppModel()
        self._model = State(initialValue: model)
        // Hand the adaptor's own delegate the model. NSApp.delegate is SwiftUI's
        // wrapper, so files opened at cold launch flush before the window appears.
        self.appDelegate.attach(model: model)
    }

    var body: some Scene {
        // One window for the life of the app. WindowGroup was opening a new
        // window for every file passed to `open -a` / Open With.
        Window("Minify Images", id: "main") {
            ContentView()
                .preferredColorScheme(.dark)
                .background {
                    MainWindowBridge(model: model, appDelegate: appDelegate)
                }
                .environment(model)
                .onOpenURL { url in
                    self.appDelegate.present(urls: [url])
                }
                .onAppear {
                    self.appDelegate.attach(model: self.model)
                    NSApp.appearance = NSAppearance(named: .darkAqua)
                    NSWindow.allowsAutomaticWindowTabbing = false
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
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
    private var queuedOpenURLs: [URL] = []
    private var openFlushScheduled = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.removeObject(forKey: "temporary.paneStyle.border")
        UserDefaults.standard.removeObject(forKey: "temporary.paneStyle.fill")
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

    /// Keeps the first model so the window and the delegate share one list.
    /// Flushes anything queued before the model existed.
    @MainActor
    func attach(model: AppModel) {
        if self.model == nil {
            self.model = model
        }
        self.flushPendingURLs()
    }

    @MainActor
    func setShowMainWindow(_ show: @escaping @MainActor () -> Void) {
        self.showMainWindow = show
    }

    @MainActor
    func present(urls: [URL]) {
        guard !urls.isEmpty else { return }
        guard self.model != nil else {
            self.pendingURLs.append(contentsOf: urls)
            return
        }
        self.queuedOpenURLs.append(contentsOf: urls)
        guard !self.openFlushScheduled else { return }
        self.openFlushScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.openFlushScheduled = false
            let batch = self.queuedOpenURLs
            self.queuedOpenURLs = []
            self.flushOpenedURLs(batch)
        }
    }

    @MainActor
    private func flushPendingURLs() {
        guard let model = self.model, !self.pendingURLs.isEmpty else { return }
        let urls = self.pendingURLs
        self.pendingURLs = []
        model.addDroppedURLs(urls)
        self.showMainWindow?()
        self.orderMainWindowFront()
        DispatchQueue.main.async { [weak self] in
            self?.orderMainWindowFront()
        }
    }

    /// One batch for a burst of `onOpenURL` callbacks and `application(_:open:)`.
    @MainActor
    private func flushOpenedURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        if let model = self.model {
            model.addDroppedURLs(urls)
        } else {
            self.pendingURLs.append(contentsOf: urls)
        }
        self.showMainWindow?()
        self.orderMainWindowFront()
        // openWindow is async; order front again once a closed window has reappeared.
        DispatchQueue.main.async { [weak self] in
            self?.orderMainWindowFront()
        }
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
    var model: AppModel
    var appDelegate: AppDelegate

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .onAppear {
                let openWindow = self.openWindow
                let delegate = self.appDelegate
                delegate.attach(model: self.model)
                delegate.setShowMainWindow { @MainActor in
                    openWindow(id: "main")
                }
            }
    }
}
