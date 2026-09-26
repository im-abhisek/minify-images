import SwiftUI

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
                    self.model.reveal(result.destination)
                }
                .buttonStyle(MinifyButtonStyle(compact: true))
            }

            Button {
                self.model.removeJob(id: job.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.secondary.opacity(model.isRunning ? 0.35 : 0.85))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .disabled(model.isRunning)
            .help(model.isRunning ? "Wait until conversion finishes" : "Remove")
            .accessibilityLabel("Remove \(job.name)")
        }
        .padding(.horizontal, 16)
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
            YellowSpinner(side: 12)
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
