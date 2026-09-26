import SwiftUI

/// One pane: an empty drop target, or the image list once files are added.
struct ImagePaneView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let paneShape = RoundedRectangle(cornerRadius: 18, style: .continuous)

    var body: some View {
        @Bindable var model = model
        ZStack {
            FileDropCatcher(isTargeted: $model.isTargeted) { urls in
                self.model.addDroppedURLs(urls)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ZStack {
                paneShape
                    .fill(model.isTargeted ? Color.accentColor.opacity(0.14) : Color.white.opacity(0.05))

                ConversionWash(animate: model.isRunning && !reduceMotion)
                    .opacity(model.isRunning ? 0.16 : 0)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: model.isRunning)

                PaneGrid()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(paneShape)
            .allowsHitTesting(false)

            if model.jobs.isEmpty {
                emptyState
            } else {
                listState
            }
        }
        .overlay {
            paneShape
                .strokeBorder(
                    model.isTargeted ? Color.accentColor : Color.white.opacity(0.08),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: 150)
        .animation(.easeInOut(duration: 0.16), value: model.isTargeted)
        .onDrop(of: [.fileURL, .folder, .directory], isTargeted: $model.isTargeted) { providers in
            Task {
                let urls = await DroppedFileLoader.urls(from: providers)
                self.model.addDroppedURLs(urls)
            }
            return true
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Drop files and folders")
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("Drop Files and Folders")
                    .font(.system(size: 15, weight: .semibold))
                Text("Convert JPEGs and PNGs to WebP")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            }
            .allowsHitTesting(false)
            AddFilesButton()
        }
        .padding(16)
    }

    private var listState: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(headerTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                if let skipped = model.skippedNotice {
                    Text(skipped)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                AddFilesButton(filled: false)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.jobs) { job in
                        JobRowView(job: job)
                        if job.id != model.jobs.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 8)
    }

    private var headerTitle: String {
        model.jobs.count == 1 ? "1 image" : "\(model.jobs.count) images"
    }
}

/// Thin canvas lines over the pane fill. About 5% white, 18pt apart.
private struct PaneGrid: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 18
            var path = Path()
            var x = spacing / 2
            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y = spacing / 2
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(path, with: .color(Color.white.opacity(0.05)), lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Soft blue and pink wash. Drifts while a batch runs; static when Reduce Motion is on.
private struct ConversionWash: View {
    var animate: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !animate)) { timeline in
            let phase = self.phase(at: timeline.date)
            Canvas { context, size in
                ConversionWash.draw(context: &context, size: size, phase: phase)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func phase(at date: Date) -> Double {
        guard self.animate else { return 0.35 }
        let cycle = 8.0
        return date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle) / cycle
    }

    private static func draw(context: inout GraphicsContext, size: CGSize, phase: Double) {
        let blobs: [(Color, Double)] = [
            (Color.blue, 0),
            (Color(red: 0.98, green: 0.45, blue: 0.72), 0.5)
        ]
        let reach = max(min(size.width, size.height), 1)
        for (color, shift) in blobs {
            let angle = (phase + shift) * 2 * Double.pi
            let cx = size.width * 0.5 + CGFloat(cos(angle)) * size.width * 0.22
            let cy = size.height * 0.5 + CGFloat(sin(angle * 0.85 + shift)) * size.height * 0.2
            let radius = reach * 0.62
            let rect = CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2)
            context.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.95), color.opacity(0)]),
                    center: CGPoint(x: cx, y: cy),
                    startRadius: 0,
                    endRadius: radius
                )
            )
        }
    }
}

private struct AddFilesButton: View {
    /// Filled grey button in the empty pane. Plain blue text once the list is showing.
    var filled = true
    @Environment(AppModel.self) private var model

    var body: some View {
        if filled {
            Button {
                self.model.chooseFiles()
            } label: {
                Label("Add Files", systemImage: "plus")
            }
            .buttonStyle(MinifyButtonStyle())
        } else {
            Button {
                self.model.chooseFiles()
            } label: {
                Label("Add Files", systemImage: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.blue)
            }
            .buttonStyle(.plain)
        }
    }
}
