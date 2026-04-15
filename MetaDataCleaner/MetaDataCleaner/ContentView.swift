import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var items: [ImageItem] = []
    @State private var outputFolder: URL? = nil
    @State private var isDropTargeted = false
    @State private var isProcessing = false
    @State private var showCompletionAlert = false
    @State private var completionMessage = ""

    private var processedCount: Int { items.filter { if case .done = $0.status { return true }; return false }.count }
    private var failedCount: Int { items.filter { if case .failed = $0.status { return true }; return false }.count }
    private var canProcess: Bool { !items.isEmpty && outputFolder != nil && !isProcessing }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Main content
            if items.isEmpty {
                dropZone
            } else {
                imageList
            }

            Divider()

            // Footer toolbar
            footer
        }
        .alert("Processing Complete", isPresented: $showCompletionAlert) {
            Button("Open Output Folder") {
                if let folder = outputFolder {
                    NSWorkspace.shared.open(folder)
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(completionMessage)
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Image(systemName: "shield.lefthalf.filled")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            Text("Metadata Cleaner")
                .font(.title2.bold())
            Spacer()
            if !items.isEmpty {
                Button("Clear All") {
                    items = []
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .disabled(isProcessing)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var dropZone: some View {
        DropZoneView(isTargeted: isDropTargeted, onTap: pickFiles)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers)
            }
    }

    private var imageList: some View {
        VStack(spacing: 0) {
            // Drop more bar
            HStack {
                Text("\(items.count) image\(items.count == 1 ? "" : "s") queued")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Add More…") { pickFiles() }
                    .buttonStyle(.borderless)
                    .disabled(isProcessing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            ImageListView(items: $items) { id in
                items.removeAll { $0.id == id }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            // Output folder selector
            VStack(alignment: .leading, spacing: 2) {
                Text("Save to:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    Text(outputFolder?.abbreviatingWithTildeInPath ?? "No folder chosen")
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(outputFolder == nil ? .secondary : .primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Choose Output…") {
                pickOutputFolder()
            }
            .disabled(isProcessing)

            Divider().frame(height: 24)

            Button(action: processImages) {
                HStack(spacing: 6) {
                    if isProcessing {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isProcessing ? "Cleaning…" : "Clean Metadata")
                }
                .frame(minWidth: 140)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canProcess)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Actions

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .folder]
        panel.message = "Choose images or folders to clean"
        panel.prompt = "Add"

        if panel.runModal() == .OK {
            addURLs(panel.urls)
        }
    }

    private func pickOutputFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "Choose where to save the cleaned images"
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            outputFolder = url
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        let group = DispatchGroup()
        var collected: [URL] = []

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    collected.append(url)
                    handled = true
                }
            }
        }

        group.notify(queue: .main) {
            addURLs(collected)
        }

        return handled
    }

    private func addURLs(_ urls: [URL]) {
        let newImages = ImageProcessor.collectImages(from: urls)
        let existingPaths = Set(items.map(\.url.path))
        let unique = newImages.filter { !existingPaths.contains($0.path) }
        items.append(contentsOf: unique.map { ImageItem(url: $0) })
    }

    private func processImages() {
        guard let output = outputFolder else { return }
        isProcessing = true

        // Reset statuses
        for i in items.indices { items[i].status = .pending }

        Task {
            var doneCount = 0
            var failCount = 0

            for i in items.indices {
                await MainActor.run { items[i].status = .processing }

                let source = items[i].url
                let destURL = uniqueOutputURL(for: source, in: output)

                do {
                    try ImageProcessor.stripMetadata(from: source, to: destURL)
                    await MainActor.run {
                        items[i].status = .done
                        doneCount += 1
                    }
                } catch {
                    await MainActor.run {
                        items[i].status = .failed(error.localizedDescription)
                        failCount += 1
                    }
                }
            }

            await MainActor.run {
                isProcessing = false
                completionMessage = "\(doneCount) image\(doneCount == 1 ? "" : "s") cleaned successfully."
                    + (failCount > 0 ? " \(failCount) failed." : "")
                showCompletionAlert = true
            }
        }
    }

    /// Returns a unique output URL with a random alphanumeric filename.
    /// Regenerates until the name doesn't clash with any existing file in the folder.
    private func uniqueOutputURL(for source: URL, in folder: URL) -> URL {
        let ext = source.pathExtension.lowercased()
        var candidate: URL
        repeat {
            candidate = folder.appendingPathComponent("\(randomName()).\(ext)")
        } while FileManager.default.fileExists(atPath: candidate.path)
        return candidate
    }

    /// Generates a random 16-character alphanumeric string.
    private func randomName() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<16).map { _ in chars.randomElement()! })
    }
}

private extension URL {
    var abbreviatingWithTildeInPath: String {
        (path as NSString).abbreviatingWithTildeInPath
    }
}
