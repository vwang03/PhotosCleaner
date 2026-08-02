import Foundation
import Photos
import CoreGraphics
import AppKit

/// Loads pixel data for assets, respecting the configured iCloud policy so scans never
/// silently trigger unwanted downloads (PRD 4.6 / Open Question on Optimize Mac Storage).
public struct AssetImageLoader: Sendable {
    public init() {}

    public struct LoadedImage {
        public let cgImage: CGImage
        public let wasServedFromiCloud: Bool
    }

    /// Loads a reasonably-sized preview suitable for perceptual hashing and Vision
    /// feature-print generation. Uses `.fastFormat` delivery so it resolves with a
    /// single callback rather than waiting on a possible slower "final" callback that
    /// may never arrive when network access is disallowed.
    public func loadPreviewImage(
        for asset: PHAsset,
        allowNetworkAccess: Bool,
        maxDimension: CGFloat = 512
    ) async -> LoadedImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
            options.isSynchronous = false
            options.isNetworkAccessAllowed = allowNetworkAccess
            options.version = .current

            let targetSize = CGSize(width: maxDimension, height: maxDimension)
            var didResume = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                guard !didResume else { return }
                didResume = true
                let isInCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
                if let cgImage = image?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    continuation.resume(returning: LoadedImage(cgImage: cgImage, wasServedFromiCloud: isInCloud))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Reads the full original resource bytes for exact-duplicate content hashing.
    /// Only call this for assets where the iCloud policy permits it (local assets, or
    /// `forceDownload`).
    public func loadResourceData(for asset: PHAsset, allowNetworkAccess: Bool) async -> Data? {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = preferredResource(from: resources) else { return nil }

        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = allowNetworkAccess

        return await withCheckedContinuation { continuation in
            var buffer = Data()
            var didResume = false
            PHAssetResourceManager.default().requestData(for: resource, options: options, dataReceivedHandler: { chunk in
                buffer.append(chunk)
            }, completionHandler: { error in
                guard !didResume else { return }
                didResume = true
                if error != nil {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: buffer)
                }
            })
        }
    }

    private func preferredResource(from resources: [PHAssetResource]) -> PHAssetResource? {
        let priority: [PHAssetResourceType] = [.fullSizePhoto, .photo, .fullSizeVideo, .video]
        for type in priority {
            if let match = resources.first(where: { $0.type == type }) {
                return match
            }
        }
        return resources.first
    }
}
