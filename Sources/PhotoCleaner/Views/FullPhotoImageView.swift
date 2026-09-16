import SwiftUI
import Photos
import AppKit

/// Displays a single asset large and *uncropped*, so the user can judge the actual
/// photo rather than the square center-crop the grid thumbnails show.
///
/// Unlike `AsyncThumbnailView` this view does not impose a square frame: it fits the
/// image into whatever frame the caller gives it, preserving the original aspect ratio.
/// iCloud downloads are allowed because reaching this view is always a deliberate,
/// single-asset user action.
struct FullPhotoImageView: View {
    let localIdentifier: String
    /// Longest-edge pixel budget for the render request. Callers should quantize this
    /// so window resizing doesn't kick off a new fetch for every single point.
    var maxPixelSize: CGFloat

    @StateObject private var download = PhotoDownloadProgress()
    @State private var image: NSImage?
    @State private var didFail = false

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else if didFail {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                    Text("Couldn't load this photo")
                        .font(.callout)
                }
                .foregroundStyle(.secondary)
            } else {
                loadingIndicator
            }
        }
        .task(id: "\(localIdentifier)-\(Int(maxPixelSize))") {
            await load()
        }
    }

    private var loadingIndicator: some View {
        VStack(spacing: 10) {
            if download.fraction > 0, download.fraction < 1 {
                ProgressView(value: download.fraction)
                    .frame(width: 180)
                Text("Downloading from iCloud… \(Int(download.fraction * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                Text("Loading full photo…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func load() async {
        let progress = download
        let loaded = await FullImageLoader.shared.image(
            for: localIdentifier,
            maxPixelSize: maxPixelSize
        ) { fraction in
            Task { @MainActor in progress.fraction = fraction }
        }

        if let loaded {
            image = loaded
            didFail = false
        } else {
            // Keep any previously loaded render on screen; only report failure when
            // there's nothing at all to show.
            didFail = image == nil
        }
        download.fraction = 0
    }
}

/// Relays `PHImageManager`'s off-thread progress callbacks back to the view. A
/// main-actor class is used (rather than capturing view state) so the callback can be
/// `@Sendable`.
@MainActor
final class PhotoDownloadProgress: ObservableObject {
    @Published var fraction: Double = 0
}

/// Loads large, aspect-fit renders of assets with a small LRU cache. Kept separate
/// from `ThumbnailCache` because these images are one to two orders of magnitude
/// larger, so only a handful can be held in memory.
actor FullImageLoader {
    static let shared = FullImageLoader()

    private var cache: [String: NSImage] = [:]
    private var recentKeys: [String] = []
    private let capacity = 4

    func image(
        for identifier: String,
        maxPixelSize: CGFloat,
        progress: @escaping @Sendable (Double) -> Void
    ) async -> NSImage? {
        let key = "\(identifier)-\(Int(maxPixelSize))"
        if let cached = cache[key] {
            remember(key, image: cached)
            return cached
        }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = fetchResult.firstObject else { return nil }

        let image: NSImage? = await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            // .highQualityFormat resolves with a single callback, keeping this a
            // one-shot continuation.
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .exact
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true
            options.progressHandler = { fraction, _, _, _ in progress(fraction) }

            var didResume = false
            // A square target with .aspectFit caps the longest edge at maxPixelSize
            // while preserving the original aspect ratio.
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: maxPixelSize, height: maxPixelSize),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: image)
            }
        }

        if let image {
            remember(key, image: image)
        }
        return image
    }

    private func remember(_ key: String, image: NSImage) {
        cache[key] = image
        recentKeys.removeAll { $0 == key }
        recentKeys.append(key)
        while recentKeys.count > capacity {
            cache.removeValue(forKey: recentKeys.removeFirst())
        }
    }
}
