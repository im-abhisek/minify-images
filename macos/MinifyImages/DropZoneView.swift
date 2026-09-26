import SwiftUI

/// One pane: an empty drop target, or the image list once files are added.
struct ImagePaneView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ZStack {
            FileDropCatcher(isTargeted: $model.isTargeted) { urls in
                self.model.addDroppedURLs(urls)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(model.isTargeted ? Color.accentColor.opacity(0.14) : Color.white.opacity(0.05))
                .allowsHitTesting(false)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    model.isTargeted ? Color.accentColor : Color.white.opacity(0.08),
                    lineWidth: 1
                )
                .allowsHitTesting(false)

            if model.jobs.isEmpty {
                emptyState
            } else {
                listState
            }
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
            Text("Drop Files and Folders")
                .font(.system(size: 15, weight: .semibold))
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
                AddFilesButton(compact: true)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 8)
    }

    private var headerTitle: String {
        model.jobs.count == 1 ? "1 image" : "\(model.jobs.count) images"
    }
}

private struct AddFilesButton: View {
    var compact = false
    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            self.model.chooseFiles()
        } label: {
            Label("Add Files", systemImage: "plus")
        }
        .buttonStyle(MinifyButtonStyle(compact: compact))
    }
}
