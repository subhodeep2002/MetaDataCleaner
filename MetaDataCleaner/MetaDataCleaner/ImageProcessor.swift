import Foundation
import ImageIO
import UniformTypeIdentifiers
import AppKit

enum ProcessingError: LocalizedError {
    case cannotReadImage(URL)
    case cannotCreateDestination(URL)
    case cannotWriteImage(URL)

    var errorDescription: String? {
        switch self {
        case .cannotReadImage(let url): return "Cannot read image: \(url.lastPathComponent)"
        case .cannotCreateDestination(let url): return "Cannot create output file: \(url.lastPathComponent)"
        case .cannotWriteImage(let url): return "Cannot write cleaned image: \(url.lastPathComponent)"
        }
    }
}

struct ProcessingResult {
    let url: URL
    let success: Bool
    let error: String?
}

final class ImageProcessor {

    static let supportedExtensions: Set<String> = ["png", "jpg", "jpeg", "webp", "tiff", "tif", "bmp", "gif"]

    /// Strips ALL metadata from an image and writes it to outputURL.
    /// Uses CGImageSource / CGImageDestination — no metadata properties are copied.
    static func stripMetadata(from sourceURL: URL, to outputURL: URL) throws {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw ProcessingError.cannotReadImage(sourceURL)
        }

        let uti = CGImageSourceGetType(source) ?? UTType.png.identifier as CFString

        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, uti, 1, nil) else {
            throw ProcessingError.cannotCreateDestination(outputURL)
        }

        // Add image WITHOUT any metadata properties
        // Passing nil for options means no metadata is copied from source
        let options: [CFString: Any] = [
            kCGImageDestinationMetadata: NSNull(),   // explicitly no metadata
            kCGImageDestinationMergeMetadata: false
        ]

        CGImageDestinationAddImageFromSource(destination, source, 0, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ProcessingError.cannotWriteImage(outputURL)
        }
    }

    /// Collects all supported image files from a list of URLs (files or folders).
    static func collectImages(from urls: [URL]) -> [URL] {
        var result: [URL] = []
        for url in urls {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    result.append(contentsOf: imagesInDirectory(url))
                } else if isSupported(url) {
                    result.append(url)
                }
            }
        }
        return result
    }

    private static func imagesInDirectory(_ dir: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: dir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return enumerator.compactMap { $0 as? URL }.filter { isSupported($0) }
    }

    private static func isSupported(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }
}
