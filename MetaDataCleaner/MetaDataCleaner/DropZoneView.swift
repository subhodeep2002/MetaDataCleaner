import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    let isTargeted: Bool
    let onTap: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.04))
                )

            VStack(spacing: 12) {
                Image(systemName: isTargeted ? "arrow.down.circle.fill" : "photo.stack")
                    .font(.system(size: 44))
                    .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
                    .animation(.spring(duration: 0.2), value: isTargeted)

                Text("Drop images or folders here")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)

                Text("or")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Choose Files / Folders") {
                    onTap()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                Text("Supports PNG, JPG, JPEG, WebP, TIFF, BMP, GIF")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(32)
        }
    }
}
