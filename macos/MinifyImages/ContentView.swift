import AppKit
import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            ImagePaneView()
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            OptionsView()
            StatusBar()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .background(WindowTitleSetter(title: "Minify Images"))
        .preferredColorScheme(.dark)
        .onAppear {
            DispatchQueue.main.async {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
        .onDrop(of: [.fileURL, .folder, .directory], isTargeted: $model.isTargeted) { providers in
            Task {
                let urls = await DroppedFileLoader.urls(from: providers)
                model.addDroppedURLs(urls)
            }
            return true
        }
        .frame(
            minWidth: 720,
            idealWidth: 800,
            maxWidth: 1200,
            minHeight: 480,
            idealHeight: 560,
            maxHeight: 900
        )
    }

}

/// Hides the system title (still set for Mission Control, the Window menu, and accessibility)
/// and draws "Minify Images" at the window's horizontal centre, level with the traffic lights.
/// macOS 26 draws the system title leading-aligned even with no toolbar, and a toolbar
/// `.principal` item is centred in the toolbar's inset rather than across the full window.
private struct WindowTitleSetter: NSViewRepresentable {
    var title: String

    func makeNSView(context: Context) -> TitleWindowView {
        let view = TitleWindowView()
        view.title = title
        return view
    }

    func updateNSView(_ nsView: TitleWindowView, context: Context) {
        nsView.title = title
        nsView.applyTitle()
    }
}

private final class TitleWindowView: NSView {
    var title = ""

    private var titleField: PassThroughTextField?
    private var observedWindow: NSWindow?
    private var didResignInitialFocus = false
    private var didConstrainTitle = false

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyTitle()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        titleField?.removeFromSuperview()
    }

    func applyTitle() {
        guard let window else { return }
        window.title = title
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = false
        window.styleMask.insert(.titled)
        window.toolbar = nil
        observe(window)
        installTitleIfNeeded()
        positionTitle()
        guard !didResignInitialFocus else { return }
        didResignInitialFocus = true
        DispatchQueue.main.async { [weak self, weak window] in
            window?.makeFirstResponder(nil)
            self?.installTitleIfNeeded()
            self?.positionTitle()
        }
    }

    private func observe(_ window: NSWindow) {
        guard observedWindow !== window else { return }
        NotificationCenter.default.removeObserver(self)
        observedWindow = window
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowFrameChanged(_:)),
            name: NSWindow.didResizeNotification,
            object: window
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowKeyChanged(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: window
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowKeyChanged(_:)),
            name: NSWindow.didResignKeyNotification,
            object: window
        )
    }

    private func installTitleIfNeeded() {
        guard let window, let host = fullWidthHost(in: window) else { return }
        let field: PassThroughTextField
        if let existing = titleField, existing.superview === host {
            field = existing
        } else {
            titleField?.removeFromSuperview()
            didConstrainTitle = false
            let created = PassThroughTextField(labelWithString: title)
            created.font = NSFont.titleBarFont(ofSize: 0)
            created.alignment = .center
            created.drawsBackground = false
            created.isBezeled = false
            created.isEditable = false
            created.isSelectable = false
            created.refusesFirstResponder = true
            created.translatesAutoresizingMaskIntoConstraints = true
            created.autoresizingMask = []
            created.maximumNumberOfLines = 1
            host.addSubview(created)
            titleField = created
            field = created
        }
        field.stringValue = title
        field.font = NSFont.titleBarFont(ofSize: 0)
        updateTitleColor()
    }

    /// The title-bar ancestor that spans the window, so the label is not clipped at the traffic lights.
    private func fullWidthHost(in window: NSWindow) -> NSView? {
        guard let button = window.standardWindowButton(.closeButton) else { return nil }
        let target = window.contentView?.bounds.width ?? 0
        guard target > 1 else { return nil }
        var view = button.superview
        while let current = view {
            if current.bounds.width >= target - 2 {
                return current
            }
            view = current.superview
        }
        return nil
    }

    private func positionTitle() {
        guard !didConstrainTitle,
              let window,
              let field = titleField,
              let content = window.contentView,
              let button = window.standardWindowButton(.closeButton) else { return }
        field.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            field.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            field.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
        didConstrainTitle = true
    }

    private func updateTitleColor() {
        guard let field = titleField, let window else { return }
        field.textColor = window.isKeyWindow ? NSColor.labelColor : NSColor.secondaryLabelColor
    }

    @objc private func windowFrameChanged(_ notification: Notification) {
        self.installTitleIfNeeded()
        self.positionTitle()
    }

    @objc private func windowKeyChanged(_ notification: Notification) {
        self.installTitleIfNeeded()
        self.positionTitle()
        self.updateTitleColor()
    }
}

/// Title text must not take the click, so the title bar still drags the window.
private final class PassThroughTextField: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

private struct StatusBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.35)
            HStack(spacing: 8) {
                if showsStatusIcon {
                    statusMark
                        .frame(width: 16, height: 16)
                }
                Text(statusText)
                    .font(.system(size: 12.5, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(emphasize ? Color.primary : Color.secondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let summary = model.lastSummary, summary.converted > 0, !model.isRunning {
                    Button("Show in Finder") {
                        model.revealOutputs()
                    }
                    .buttonStyle(MinifyButtonStyle(compact: true))
                }
                if !model.jobs.isEmpty {
                    Button("Clear") {
                        model.clear()
                    }
                    .disabled(model.isRunning)
                    .buttonStyle(MinifyButtonStyle())
                }
                if model.isRunning {
                    Button("Cancel") {
                        model.cancel()
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    .buttonStyle(MinifyButtonStyle())
                }
                Button(model.isRunning ? "Converting…" : convertTitle) {
                    model.convert()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(MinifyButtonStyle())
                .disabled(!model.canConvert)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(Color.white.opacity(0.05))
    }

    private var emphasize: Bool {
        model.isRunning || model.lastSummary != nil
    }

    private var convertTitle: String {
        let n = model.jobs.count
        if n == 0 { return "Convert" }
        return n == 1 ? "Convert 1 image" : "Convert \(n) images"
    }

    private var statusText: String {
        if model.isRunning {
            return model.inProgressStatus
        }
        if let summary = model.lastSummary {
            return model.doneStatus(summary)
        }
        if let message = model.statusMessage {
            return message
        }
        if let reason = model.convertDisabledReason {
            return reason
        }
        return "Ready"
    }

    private var showsStatusIcon: Bool {
        model.isRunning || model.lastSummary != nil
    }

    @ViewBuilder
    private var statusMark: some View {
        if model.isRunning {
            YellowSpinner()
        } else if model.lastSummary != nil {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.green)
                .accessibilityLabel("Done")
        } else {
            Color.clear
        }
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
        .frame(width: 800, height: 560)
}
