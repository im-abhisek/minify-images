import SwiftUI

struct JobListView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(model.jobs.count == 1 ? "1 image" : "\(model.jobs.count) images")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                Spacer()
                if let skipped = model.skippedNotice {
                    Text(skipped)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.jobs) { job in
                        JobRowView(job: job)
                        if job.id != model.jobs.last?.id {
                            Divider().padding(.leading, 24)
                        }
                    }
                }
            }
            .frame(maxHeight: 220)
        }
        .padding(.bottom, 8)
    }
}

struct JobRowView: View {
    @Environment(AppModel.self) private var model
    let job: ImageJob

    var body: some View {
        HStack(spacing: 12) {
            statusMark
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(job.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(detailColor)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if case .succeeded(let result) = job.status {
                Button("Show") {
                    model.reveal(result.destination)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tint)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .contextMenu {
            Button("Reveal original in Finder") {
                model.reveal(job.source)
            }
            if case .succeeded(let result) = job.status {
                Button("Reveal WebP in Finder") {
                    model.reveal(result.destination)
                }
            }
        }
    }

    @ViewBuilder
    private var statusMark: some View {
        switch job.status {
        case .queued:
            Circle()
                .stroke(Color.secondary.opacity(0.45), lineWidth: 1.4)
                .frame(width: 10, height: 10)
        case .converting:
            ProgressView()
                .controlSize(.mini)
        case .succeeded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 14))
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.system(size: 14))
        }
    }

    private var detail: String {
        switch job.status {
        case .queued:
            return job.source.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        case .converting:
            return "Converting…"
        case .succeeded(let result):
            let sizes = "\(ByteFormat.string(result.sourceBytes)) → \(ByteFormat.string(result.destBytes))  \(ByteFormat.savings(from: result.sourceBytes, to: result.destBytes))"
            let note = result.destBytes > result.sourceBytes ? "  ·  larger than original" : ""
            return "\(sizes)  ·  \(result.label)\(note)"
        case .failed(let message):
            return message
        }
    }

    private var detailColor: Color {
        switch job.status {
        case .failed: return .red
        default: return .secondary
        }
    }
}
