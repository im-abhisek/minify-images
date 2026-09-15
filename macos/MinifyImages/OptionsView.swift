import SwiftUI

struct OptionsView: View {
    @Environment(AppModel.self) private var model
    @State private var showAdvanced = false

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 12) {
            outputRow

            DisclosureGroup(isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: 14) {
                    qualityRow
                    maxEdgeRow
                    pngRow
                    Toggle("Include subfolders", isOn: $model.includeSubfolders)
                        .onChange(of: model.includeSubfolders) { _, _ in
                            if !model.isRunning {
                                model.refreshJobs(resetResults: true)
                            }
                        }
                    Text("Defaults match the CLI: quality 90, no resize, Auto PNG.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 10)
            } label: {
                Text("Options")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .tint(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private var outputRow: some View {
        @Bindable var model = model
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Output")
                .font(.system(size: 12.5, weight: .medium))
                .frame(width: 72, alignment: .leading)
                .foregroundStyle(.secondary)

            Picker("Output", selection: $model.outputMode) {
                ForEach(OutputMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 280)
            .onChange(of: model.outputMode) { _, mode in
                if mode == .folder && model.outputFolder == nil {
                    model.chooseOutputFolder()
                    if model.outputFolder == nil {
                        model.outputMode = .besideOriginals
                    }
                }
            }

            if model.outputMode == .folder {
                Button(model.outputFolder?.lastPathComponent ?? "Choose…") {
                    model.chooseOutputFolder()
                }
                .help(model.outputFolder?.path ?? "Choose a folder")
            }

            Spacer(minLength: 0)
        }
    }

    private var qualityRow: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Quality")
                    .font(.system(size: 12.5, weight: .medium))
                    .frame(width: 72, alignment: .leading)
                    .foregroundStyle(.secondary)
                Text("\(model.quality)")
                    .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
                Text(qualityCaption)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Slider(value: qualityBinding, in: 70...100, step: 1)
                .disabled(model.pngStrategy == .lossless)
        }
    }

    private var qualityBinding: Binding<Double> {
        Binding(
            get: { Double(model.quality) },
            set: { model.quality = Int($0.rounded()) }
        )
    }

    private var qualityCaption: String {
        switch model.quality {
        case 90...100: return "visually lossless photographs"
        case 80..<90: return "still sharp, smaller"
        default: return "fine for small inline images"
        }
    }

    private var maxEdgeRow: some View {
        @Bindable var model = model
        return HStack(spacing: 12) {
            Text("Long edge")
                .font(.system(size: 12.5, weight: .medium))
                .frame(width: 72, alignment: .leading)
                .foregroundStyle(.secondary)

            Picker("Long edge", selection: maxEdgeBinding) {
                Text("Off").tag(Optional<Int>.none)
                ForEach(MaxEdge.presets, id: \.self) { value in
                    Text("\(value) px").tag(Optional(value))
                }
            }
            .labelsHidden()
            .frame(width: 140)

            Text("Never upscales. Off unless the source is huge.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    private var maxEdgeBinding: Binding<Int?> {
        Binding(
            get: { model.maxEdge.pixels },
            set: { newValue in
                if let newValue {
                    model.maxEdge = .preset(newValue)
                } else {
                    model.maxEdge = .off
                }
            }
        )
    }

    private var pngRow: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text("PNG")
                    .font(.system(size: 12.5, weight: .medium))
                    .frame(width: 72, alignment: .leading)
                    .foregroundStyle(.secondary)
                Picker("PNG", selection: $model.pngStrategy) {
                    ForEach(PNGStrategy.allCases) { strategy in
                        Text(strategy.title).tag(strategy)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 280)
                Spacer(minLength: 0)
            }
            Text(model.pngStrategy.caption)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.leading, 84)
        }
    }
}
