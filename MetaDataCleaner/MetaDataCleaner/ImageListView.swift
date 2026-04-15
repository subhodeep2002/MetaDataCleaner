import SwiftUI

enum ItemStatus {
    case pending
    case processing
    case done
    case failed(String)

    var icon: String {
        switch self {
        case .pending: return "clock"
        case .processing: return "arrow.clockwise"
        case .done: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .secondary
        case .processing: return .accentColor
        case .done: return .green
        case .failed: return .red
        }
    }

    var label: String {
        switch self {
        case .pending: return "Waiting"
        case .processing: return "Processing…"
        case .done: return "Cleaned"
        case .failed(let msg): return msg
        }
    }
}

struct ImageItem: Identifiable {
    let id = UUID()
    let url: URL
    var status: ItemStatus = .pending

    var filename: String { url.lastPathComponent }
    var folder: String { url.deletingLastPathComponent().lastPathComponent }
}

struct ImageListView: View {
    @Binding var items: [ImageItem]
    let onRemove: (UUID) -> Void

    var body: some View {
        List {
            ForEach($items) { $item in
                HStack(spacing: 10) {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.filename)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                        Text(item.folder)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    Spacer()

                    statusView(item.status)

                    Button {
                        onRemove(item.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .opacity(isProcessing ? 0 : 1)
                }
                .padding(.vertical, 2)
            }
        }
        .listStyle(.inset)
    }

    private var isProcessing: Bool {
        items.contains { if case .processing = $0.status { return true }; return false }
    }

    @ViewBuilder
    private func statusView(_ status: ItemStatus) -> some View {
        HStack(spacing: 4) {
            if case .processing = status {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: status.icon)
                    .foregroundStyle(status.color)
            }
            Text(status.label)
                .font(.caption)
                .foregroundStyle(status.color)
                .lineLimit(1)
        }
        .frame(minWidth: 90, alignment: .trailing)
    }
}
