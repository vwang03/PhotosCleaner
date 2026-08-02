import Foundation
import Photos

/// Orchestrates a full scan end-to-end: enumerate candidate assets, fingerprint them
/// (reusing cached fingerprints when unchanged), cluster into duplicate groups, then
/// verify exact-duplicate status within clusters via content hashing. Runs entirely off
/// the main thread and reports incremental progress so the UI never blocks (PRD 4.2 /
/// 5 Non-Functional Requirements).
public actor ScanCoordinator {
    private let assetCatalog: AssetCatalog
    private let imageLoader: AssetImageLoader
    private let cacheStore: ScanCacheStore
    private var isCancelled = false

    public init(
        assetCatalog: AssetCatalog = AssetCatalog(),
        imageLoader: AssetImageLoader = AssetImageLoader(),
        cacheStore: ScanCacheStore
    ) {
        self.assetCatalog = assetCatalog
        self.imageLoader = imageLoader
        self.cacheStore = cacheStore
    }

    public func cancel() {
        isCancelled = true
    }

    public func runScan(
        settings: ScanSettings,
        onProgress: @escaping @Sendable (ScanProgress) -> Void
    ) async -> [DuplicateGroup] {
        isCancelled = false
        var progress = ScanProgress(phase: .enumeratingLibrary, startedAt: Date())
        onProgress(progress)

        let assets = assetCatalog.fetchCandidateAssets(settings: settings)
        var assetsByID: [String: PHAsset] = [:]
        assetsByID.reserveCapacity(assets.count)
        for asset in assets { assetsByID[asset.localIdentifier] = asset }

        progress.totalCount = assets.count
        progress.phase = .fingerprinting
        onProgress(progress)

        var results: [ScannedAssetMetadata] = []
        results.reserveCapacity(assets.count)

        for asset in assets {
            if isCancelled {
                progress.phase = .cancelled
                onProgress(progress)
                return []
            }

            let baseMetadata = assetCatalog.metadata(for: asset)

            if !baseMetadata.isLocallyAvailable && settings.iCloudPolicy == .skipNonLocal {
                progress.processedCount += 1
                onProgress(progress)
                continue
            }

            let cached = try? await cacheStore.cachedIfCurrent(
                localIdentifier: baseMetadata.localIdentifier,
                currentModificationDate: baseMetadata.modificationDate
            )
            let fingerprinted = await fingerprint(baseMetadata: baseMetadata, asset: asset, cached: cached, settings: settings)
            results.append(fingerprinted)
            try? await cacheStore.upsert(fingerprinted)

            progress.processedCount += 1
            if progress.processedCount % 10 == 0 || progress.processedCount == progress.totalCount {
                progress.estimatedSecondsRemaining = Self.estimateRemaining(progress: progress)
                onProgress(progress)
            }
        }

        try? await cacheStore.pruneCache(keepingOnly: Set(assetsByID.keys))

        if isCancelled {
            progress.phase = .cancelled
            onProgress(progress)
            return []
        }

        progress.phase = .clustering
        onProgress(progress)
        var groups = DuplicateClusterBuilder.buildGroups(from: results, sensitivity: settings.sensitivity)

        progress.phase = .verifyingExactMatches
        onProgress(progress)
        groups = await verifyExactMatches(groups: groups, settings: settings, assetsByID: assetsByID)

        progress.phase = .completed
        onProgress(progress)
        return groups
    }

    private func fingerprint(
        baseMetadata: ScannedAssetMetadata,
        asset: PHAsset,
        cached: ScannedAssetMetadata?,
        settings: ScanSettings
    ) async -> ScannedAssetMetadata {
        var result = baseMetadata

        if baseMetadata.isVideo {
            // Video near-duplicate detection is out of scope (PRD section 11); only
            // exact content-hash matching applies, so we must hash eagerly here rather
            // than deferring to the post-clustering verification pass.
            if let cached, cached.contentHashHex != nil {
                result.contentHashHex = cached.contentHashHex
                return result
            }
            let allowNetwork = settings.iCloudPolicy == .forceDownload
            guard baseMetadata.isLocallyAvailable || allowNetwork else { return result }
            if let data = await imageLoader.loadResourceData(for: asset, allowNetworkAccess: allowNetwork) {
                result.contentHashHex = ContentHasher.hashHex(of: data)
            }
            return result
        }

        if let cached, cached.perceptualHash != nil {
            result.perceptualHash = cached.perceptualHash
            result.featurePrintData = cached.featurePrintData
            result.contentHashHex = cached.contentHashHex
            return result
        }

        let allowNetwork = settings.iCloudPolicy == .forceDownload
        guard let loaded = await imageLoader.loadPreviewImage(for: asset, allowNetworkAccess: allowNetwork) else {
            return result
        }
        result.perceptualHash = PerceptualHash.hash(of: loaded.cgImage)
        result.featurePrintData = FeaturePrintService.generateFeaturePrintData(for: loaded.cgImage)
        return result
    }

    /// For clusters formed via perceptual hashing, fills in `contentHashHex` for any
    /// image members that don't already have one (subject to the iCloud policy), then
    /// re-derives each group's exact/confidence fields. Cluster membership itself never
    /// changes here — only whether a group counts as a byte-exact duplicate.
    private func verifyExactMatches(
        groups: [DuplicateGroup],
        settings: ScanSettings,
        assetsByID: [String: PHAsset]
    ) async -> [DuplicateGroup] {
        var updatedGroups: [DuplicateGroup] = []
        updatedGroups.reserveCapacity(groups.count)

        for group in groups {
            guard group.assets.count > 1, !group.isExactDuplicateGroup else {
                updatedGroups.append(group)
                continue
            }

            var updatedAssets: [ScannedAssetMetadata] = []
            updatedAssets.reserveCapacity(group.assets.count)

            for var asset in group.assets {
                if !isCancelled, !asset.isVideo, asset.contentHashHex == nil {
                    let allowNetwork = settings.iCloudPolicy == .forceDownload
                    if (asset.isLocallyAvailable || allowNetwork), let phAsset = assetsByID[asset.localIdentifier] {
                        if let data = await imageLoader.loadResourceData(for: phAsset, allowNetworkAccess: allowNetwork) {
                            asset.contentHashHex = ContentHasher.hashHex(of: data)
                            try? await cacheStore.upsert(asset)
                        }
                    }
                }
                updatedAssets.append(asset)
            }

            var refreshedGroup = group
            refreshedGroup.assets = updatedAssets
            updatedGroups.append(DuplicateClusterBuilder.recomputeExactness(of: refreshedGroup, sensitivity: settings.sensitivity))
        }

        return updatedGroups
    }

    private static func estimateRemaining(progress: ScanProgress) -> Double? {
        guard let started = progress.startedAt, progress.processedCount > 0, progress.totalCount > 0 else { return nil }
        let elapsed = Date().timeIntervalSince(started)
        let rate = elapsed / Double(progress.processedCount)
        let remaining = Double(progress.totalCount - progress.processedCount) * rate
        return max(0, remaining)
    }
}
