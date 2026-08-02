import SwiftUI
import Photos
import AppKit

/// Loads and displays a `PHAsset` thumbnail by local identifier, with a lightweight
/// in-memory cache so re-rendering the same cluster (e.g. after a selection change)
/// doesn't re-fetch from Photos every time.
struct AsyncThumbnailView: View {
    let localIdentifier: String
    var targetSize: CGFloat = 160
    /// Requests Photos' high-quality render instead of the fast/cached-thumbnail
    /// render. Defaults to true everywhere photo quality matters for judging which
    /// photo to keep; only the innermost fast-scrolling strips should opt out.
    var highQuality: Bool = true
    /// Whether this specific request may trigger an iCloud download. Should stay
    /// false for bulk grid thumbnails and only be enabled for a single, deliberate,
    /// user-initiated zoom/preview request.
    var allowNetworkAccess: Bool = false

    @State private var nsImage: NSImage?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.15))
            if let nsImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .frame(width: targetSize, height: targetSize)
        .clipped()
        .task(id: "\(localIdentifier)-\(Int(targetSize))-\(highQuality)-\(allowNetworkAccess)") {
            nsImage = await ThumbnailCache.shared.loadImage(
                for: localIdentifier,
                size: targetSize,
                highQuality: highQuality,
                allowNetworkAccess: allowNetworkAccess
            )
        }
    }
}

actor ThumbnailCache {
    static let shared = ThumbnailCache()

    private var cache: [String: NSImage] = [:]

    func loadImage(for identifier: String, size: CGFloat, highQuality: Bool, allowNetworkAccess: Bool) async -> NSImage? {
        let key = "\(identifier)-\(Int(size))-\(highQuality)-\(allowNetworkAccess)"
        if let existing = cache[key] {
            return existing
        }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = fetchResult.firstObject else { return nil }

        let image: NSImage? = await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            // Both .fastFormat and .highQualityFormat resolve with a single callback,
            // so this stays a one-shot continuation either way. .highQualityFormat is
            // used by default so users can actually judge photo quality/sharpness;
            // .fastFormat remains available for contexts that prioritize scroll speed
            // over fidelity.
            options.deliveryMode = highQuality ? .highQualityFormat : .fastFormat
            options.resizeMode = highQuality ? .exact : .fast
            options.isSynchronous = false
            options.isNetworkAccessAllowed = allowNetworkAccess

            var didResume = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: size * 2, height: size * 2),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: image)
            }
        }

        if let image {
            cache[key] = image
        }
        return image
    }
}
