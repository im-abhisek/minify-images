import SwiftUI

/// One pane: an empty drop target, or a thumbnail grid once files are added.
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
                paneShape.fill(model.isTargeted ? AnyShapeStyle(Color.accentColor.opacity(0.14)) : AnyShapeStyle(Self.paneFill))
                PaneGrid()
                ConversionEdgeGlow(animate: model.isRunning && !reduceMotion)
                    .opacity(model.isRunning ? 1 : 0)
                    .animation(.easeInOut(duration: 0.8), value: model.isRunning)
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
            Group {
                if model.isTargeted {
                    paneShape.strokeBorder(Color.accentColor, lineWidth: 1)
                } else {
                    paneShape.strokeBorder(Self.rim, lineWidth: 1)
                }
            }
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
                LazyVGrid(columns: tileColumns, spacing: 12) {
                    ForEach(model.jobs) { job in
                        JobTileView(job: job)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .scrollContentBackground(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 8)
    }

    private var tileColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 120, maximum: 140), spacing: 12)]
    }

    private var headerTitle: String {
        model.jobs.count == 1 ? "1 image" : "\(model.jobs.count) images"
    }

    /// Slightly darker than the window at the top, current grey pane at the bottom.
    private static let paneFill = LinearGradient(
        colors: [
            Color.black.opacity(0.16),
            Color.white.opacity(0.05)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Light along the top edge, dark along the bottom.
    private static let rim = LinearGradient(
        colors: [
            Color.white.opacity(0.22),
            Color.black.opacity(0.50)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

/// Hairline canvas seams over the pane fill. 32pt cells, faint black.
private struct PaneGrid: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 32
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
            context.stroke(path, with: .color(Color.black.opacity(0.20)), lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Blue and pink light that travels around the pane edge. The centre stays clear.
/// Reduce Motion holds the glow still.
private struct ConversionEdgeGlow: View {
    var animate: Bool

    private let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !self.animate)) { timeline in
            let angle = self.angle(at: timeline.date)
            ZStack {
                self.shape
                    .strokeBorder(Self.gradient(angle: angle, strength: 1), lineWidth: 2.5)
                    .blur(radius: 8)
                self.shape
                    .strokeBorder(Self.gradient(angle: angle, strength: 1), lineWidth: 2.5)
                self.shape
                    .strokeBorder(Self.gradient(angle: angle, strength: 0.28), lineWidth: 16)
                    .blur(radius: 6)
            }
        }
        .mask {
            self.shape.strokeBorder(Color.white, lineWidth: 22)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func angle(at date: Date) -> Angle {
        guard self.animate else { return .degrees(-32) }
        let cycle = 10.0
        let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle) / cycle
        return .degrees(phase * 360)
    }

    private static func gradient(angle: Angle, strength: Double) -> AngularGradient {
        let blue = Color.blue.opacity(0.95 * strength)
        let pink = Color(red: 0.98, green: 0.45, blue: 0.72).opacity(0.9 * strength)
        let dim = Color.blue.opacity(0.08 * strength)
        return AngularGradient(
            gradient: Gradient(stops: [
                Gradient.Stop(color: dim, location: 0),
                Gradient.Stop(color: blue, location: 0.20),
                Gradient.Stop(color: pink, location: 0.46),
                Gradient.Stop(color: dim, location: 0.70),
                Gradient.Stop(color: blue, location: 0.86),
                Gradient.Stop(color: dim, location: 1)
            ]),
            center: .center,
            startAngle: angle,
            endAngle: angle + .degrees(360)
        )
    }
}

private struct AddFilesButton: View {
    /// Filled grey button in the empty pane. Plain blue text once thumbnails are showing.
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
