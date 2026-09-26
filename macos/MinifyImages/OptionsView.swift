import SwiftUI

struct OptionsView: View {
    @Environment(AppModel.self) private var model
    @State private var showAdvanced = true

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 12) {
            outputRow

            DisclosureGroup(isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: 14) {
                    qualityRow
                    maxEdgeRow
                    Toggle("Include subfolders", isOn: $model.includeSubfolders)
                        .disabled(model.isRunning)
                        .onChange(of: model.includeSubfolders) { _, _ in
                            if !model.isRunning {
                                model.refreshJobs(resetResults: true)
                            }
                        }
                    Text("Transparent PNGs keep their alpha. Opaque PNGs stay near-lossless.")
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
        .onAppear {
            showAdvanced = true
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var outputRow: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
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
                .disabled(model.isRunning)
                .onChange(of: model.outputMode) { _, mode in
                    model.rememberOutputMode()
                    if mode == .folder && model.outputFolder == nil {
                        model.chooseOutputFolder(revertIfCancelled: true)
                    }
                }

                Button("Choose Output Folder") {
                    model.chooseOutputFolder()
                }
                .buttonStyle(MinifyButtonStyle())
                .disabled(model.isRunning)

                Spacer(minLength: 0)
            }

            if let path = model.outputFolderDisplay {
                Text(path)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.leading, 84)
                    .help(model.outputFolder?.path ?? path)
            }
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
                .disabled(model.isRunning)
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
        case 75..<90: return "smaller, still sharp"
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
            .disabled(model.isRunning)

            Text("Never upscales.")
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
}
