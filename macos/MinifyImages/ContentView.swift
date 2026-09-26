import AppKit
import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            ImagePaneView()
                .padding(.horizontal, 20)
                .padding(.top, 12)
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

/// Keeps the standard centred title bar title visible.
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

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyTitle()
    }

    func applyTitle() {
        guard let window else { return }
        window.title = title
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.styleMask.insert(.titled)
        // Unified toolbar style draws the title beside the traffic lights.
        // No toolbar, expanded style: the standard title bar centres the title.
        window.toolbar = nil
        window.toolbarStyle = .expanded
        guard !didResignInitialFocus else { return }
        didResignInitialFocus = true
        DispatchQueue.main.async { [weak window] in
            window?.makeFirstResponder(nil)
        }
    }

    private var didResignInitialFocus = false
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
