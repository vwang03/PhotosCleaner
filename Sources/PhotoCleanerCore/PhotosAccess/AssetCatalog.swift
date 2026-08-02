import Foundation
import Photos

/// Enumerates `PHAsset`s from the user's library according to `ScanSettings` filters,
/// and extracts the lightweight metadata used for clustering.
public struct AssetCatalog: Sendable {
    public init() {}

    public func fetchCandidateAssets(settings: ScanSettings) -> [PHAsset] {
        let options = PHFetchOptions()
        options.includeHiddenAssets = settings.includeHiddenAlbum
        options.includeAllBurstAssets = true
        if !settings.includeVideos {
            options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        }

        let fetchResult = PHAsset.fetchAssets(with: options)
        var results: [PHAsset] = []
        results.reserveCapacity(fetchResult.count)
        fetchResult.enumerateObjects { asset, _, _ in
            if !settings.includeScreenshots && asset.mediaSubtypes.contains(.photoScreenshot) { return }
            if !settings.includeFavorites && asset.isFavorite { return }
            results.append(asset)
        }
        return results
    }

    /// Builds the metadata snapshot for one asset. This does not touch pixel data, so
    /// it never triggers an iCloud download and is safe to call for every candidate.
    public func metadata(for asset: PHAsset) -> ScannedAssetMetadata {
        let (fileSizeBytes, isLocallyAvailable) = resourceInfo(for: asset)
        return ScannedAssetMetadata(
            localIdentifier: asset.localIdentifier,
            modificationDate: asset.modificationDate ?? Date(timeIntervalSince1970: 0),
            creationDate: asset.creationDate,
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight,
            fileSizeBytes: fileSizeBytes,
            isFavorite: asset.isFavorite,
            hasAdjustments: asset.hasAdjustments,
            isScreenshot: asset.mediaSubtypes.contains(.photoScreenshot),
            isVideo: asset.mediaType == .video,
            isLocallyAvailable: isLocallyAvailable,
            burstIdentifier: asset.representsBurst ? asset.burstIdentifier : nil,
            albumNames: albumNames(for: asset),
            latitude: asset.location?.coordinate.latitude,
            longitude: asset.location?.coordinate.longitude
        )
    }

    private func albumNames(for asset: PHAsset) -> [String] {
        let collections = PHAssetCollection.fetchAssetCollectionsContaining(asset, with: .album, options: nil)
        var names: [String] = []
        collections.enumerateObjects { collection, _, _ in
            if let title = collection.localizedTitle {
                names.append(title)
            }
        }
        return names
    }

    /// `PHAssetResource` exposes `fileSize`/`locallyAvailable` only via KVC (not part of
    /// its public Swift API surface), which is a long-standing, widely-used technique
    /// for reading this information without triggering a full asset download. We treat
    /// both as best-effort: if unavailable, we fall back to `0` / `true` respectively and
    /// let the later thumbnail/data-request pass (which uses fully public APIs) refine
    /// `isLocallyAvailable` via `PHImageResultIsInCloudKey`.
    private func resourceInfo(for asset: PHAsset) -> (fileSizeBytes: Int64, isLocallyAvailable: Bool) {
        let resources = PHAssetResource.assetResources(for: asset)
        var totalSize: Int64 = 0
        var isLocal = true
        for resource in resources {
            if let size = resource.value(forKey: "fileSize") as? Int64 {
                totalSize += size
            } else if let size = resource.value(forKey: "fileSize") as? Int {
                totalSize += Int64(size)
            }
            if let local = resource.value(forKey: "locallyAvailable") as? Bool {
                isLocal = isLocal && local
            }
        }
        return (totalSize, isLocal)
    }
}
