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
        .background {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
        }
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
/// The title bar is transparent and unified so it matches the window background, and the
/// traffic lights sit in from the corner. macOS 26 draws the system title leading-aligned.
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

private final class TitleWindowView: NSView, NSToolbarDelegate {
    var title = ""

    private static let toolbarIdentifier = NSToolbar.Identifier("MinifyImagesTitlebar")
    private static let trafficLeftInset: CGFloat = 20

    private var titleField: PassThroughTextField?
    private var observedWindow: NSWindow?
    private var didResignInitialFocus = false
    private var didConstrainTitle = false
    private var isUpdatingChrome = false

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        guard !self.isUpdatingChrome else { return }
        self.isUpdatingChrome = true
        self.placeTrafficLights()
        self.isUpdatingChrome = false
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        self.applyTitle()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        self.titleField?.removeFromSuperview()
    }

    func applyTitle() {
        guard let window else { return }
        window.title = self.title
        self.configureChrome(window)
        self.observe(window)
        self.installTitleIfNeeded()
        self.positionTitle()
        self.placeTrafficLights()
        self.scheduleChromeRefresh()
        guard !self.didResignInitialFocus else { return }
        self.didResignInitialFocus = true
        DispatchQueue.main.async { [weak self, weak window] in
            window?.makeFirstResponder(nil)
            self?.refreshChrome()
        }
    }

    func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] { [] }

    func toolbarAllowedItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] { [] }

    private func configureChrome(_ window: NSWindow) {
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.styleMask.insert(.fullSizeContentView)
        window.styleMask.insert(.titled)
        window.backgroundColor = .windowBackgroundColor
        window.toolbarStyle = .unified
        guard window.toolbar == nil else {
            window.toolbar?.allowsUserCustomization = false
            return
        }
        let toolbar = NSToolbar(identifier: Self.toolbarIdentifier)
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.displayMode = .iconOnly
        toolbar.delegate = self
        window.toolbar = toolbar
    }

    private func observe(_ window: NSWindow) {
        guard self.observedWindow !== window else { return }
        NotificationCenter.default.removeObserver(self)
        self.observedWindow = window
        let names: [Notification.Name] = [
            NSWindow.didResizeNotification,
            NSWindow.didEndLiveResizeNotification,
            NSWindow.didExitFullScreenNotification,
            NSWindow.didBecomeKeyNotification,
            NSWindow.didResignKeyNotification
        ]
        for name in names {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowChromeChanged(_:)),
                name: name,
                object: window
            )
        }
    }

    private func installTitleIfNeeded() {
        guard let window, let host = self.fullWidthHost(in: window) else { return }
        let field: PassThroughTextField
        if let existing = self.titleField, existing.superview === host {
            field = existing
        } else {
            self.titleField?.removeFromSuperview()
            self.didConstrainTitle = false
            let created = PassThroughTextField(labelWithString: self.title)
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
            self.titleField = created
            field = created
        }
        field.stringValue = self.title
        field.font = NSFont.titleBarFont(ofSize: 0)
        self.updateTitleColor()
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
        guard !self.didConstrainTitle,
              let window,
              let field = self.titleField,
              let content = window.contentView,
              let button = window.standardWindowButton(.closeButton) else { return }
        field.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            field.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            field.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
        self.didConstrainTitle = true
    }

    private func updateTitleColor() {
        guard let field = self.titleField, let window else { return }
        field.textColor = window.isKeyWindow ? NSColor.labelColor : NSColor.secondaryLabelColor
    }

    /// Insets the traffic lights from the top-left corner and keeps that inset after AppKit relayout.
    private func placeTrafficLights() {
        guard let window, !window.styleMask.contains(.fullScreen) else { return }
        guard let close = window.standardWindowButton(.closeButton),
              let miniaturize = window.standardWindowButton(.miniaturizeButton),
              let zoom = window.standardWindowButton(.zoomButton),
              close.bounds.height > 1 else { return }

        if let stack = close.superview as? NSStackView {
            self.place(stack, height: stack.bounds.height)
            return
        }

        let buttons = [close, miniaturize, zoom]
        guard let container = close.superview else { return }
        let gap = self.buttonGap(between: close, and: miniaturize)
        let y = self.originY(in: container, itemHeight: close.bounds.height)
        var x = Self.trafficLeftInset
        for button in buttons {
            self.move(button, to: NSPoint(x: x, y: y))
            x += button.bounds.width + gap
        }
    }

    private func place(_ group: NSView, height: CGFloat) {
        guard let container = group.superview, height > 1 else { return }
        if self.updateHorizontalInset(of: group, to: Self.trafficLeftInset) {
            return
        }
        let y = self.originY(in: container, itemHeight: height)
        self.move(group, to: NSPoint(x: Self.trafficLeftInset, y: y))
    }

    private func originY(in container: NSView, itemHeight: CGFloat) -> CGFloat {
        let height = container.bounds.height
        let topInset: CGFloat
        if height > 100 {
            topInset = 16
        } else {
            topInset = max(12, (height - itemHeight) / 2)
        }
        if container.isFlipped {
            return topInset
        }
        return height - topInset - itemHeight
    }

    private func buttonGap(between first: NSView, and second: NSView) -> CGFloat {
        let measured = second.frame.minX - first.frame.maxX
        if measured > 1, measured < 24 { return measured }
        return 6
    }

    private func move(_ view: NSView, to origin: NSPoint) {
        guard abs(view.frame.origin.x - origin.x) > 0.5 || abs(view.frame.origin.y - origin.y) > 0.5 else { return }
        view.setFrameOrigin(origin)
    }

    /// Updates an existing leading constraint so AppKit does not snap the buttons back.
    private func updateHorizontalInset(of view: NSView, to inset: CGFloat) -> Bool {
        guard let holder = view.superview else { return false }
        for constraint in holder.constraints where constraint.isActive {
            let first = constraint.firstItem as? NSView
            let second = constraint.secondItem as? NSView
            let horizontal = constraint.firstAttribute == .leading
            guard horizontal else { continue }
            if first === view, second === holder {
                if abs(constraint.constant - inset) > 0.5 {
                    constraint.constant = inset
                }
                return true
            }
            if first === holder, second === view {
                let desired = -inset
                if abs(constraint.constant - desired) > 0.5 {
                    constraint.constant = desired
                }
                return true
            }
        }
        return false
    }

    private func refreshChrome() {
        guard let window = self.window else { return }
        self.configureChrome(window)
        self.installTitleIfNeeded()
        self.positionTitle()
        self.placeTrafficLights()
        self.updateTitleColor()
    }

    private func scheduleChromeRefresh() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshChrome()
            DispatchQueue.main.async { [weak self] in
                self?.placeTrafficLights()
            }
        }
    }

    @objc private func windowChromeChanged(_: Notification) {
        self.refreshChrome()
        self.scheduleChromeRefresh()
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
                    if model.isRunning {
                        Button("Cancel") {
                            model.cancel()
                        }
                        .keyboardShortcut(.escape, modifiers: [])
                        .buttonStyle(FilledGreyButtonStyle())
                    } else {
                        Button("Clear All") {
                            model.clear()
                        }
                        .buttonStyle(FilledGreyButtonStyle())
                    }
                }
                Button(model.isRunning ? "Converting…" : convertTitle) {
                    model.convert()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(FilledBlueButtonStyle())
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
