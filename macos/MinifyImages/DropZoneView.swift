import SwiftUI

struct DropZoneView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ZStack {
            FileDropCatcher(isTargeted: $model.isTargeted) { urls in
                model.addDroppedURLs(urls)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(model.isTargeted ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.035))
                .allowsHitTesting(false)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    model.isTargeted ? Color.accentColor : Color.primary.opacity(0.16),
                    style: StrokeStyle(lineWidth: model.isTargeted ? 2 : 1.4, dash: model.isTargeted ? [] : [6, 5])
                )
                .allowsHitTesting(false)

            VStack(spacing: 10) {
                Image(systemName: model.isTargeted ? "square.and.arrow.down" : "photo.on.rectangle.angled")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(model.isTargeted ? Color.accentColor : Color.secondary)
                    .symbolRenderingMode(.hierarchical)
                    .allowsHitTesting(false)

                Text(model.isTargeted ? "Drop to add" : "Drop JPEG or PNG")
                    .font(.system(size: 15, weight: .semibold))
                    .allowsHitTesting(false)

                Text("Files or a folder. Originals are never changed.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .allowsHitTesting(false)

                Button("Choose files…") {
                    model.chooseFiles()
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 196)
        .animation(.easeInOut(duration: 0.16), value: model.isTargeted)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Drop JPEG or PNG files, or a folder")
    }
}
