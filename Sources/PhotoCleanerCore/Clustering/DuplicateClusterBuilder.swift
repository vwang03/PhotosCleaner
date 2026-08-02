import Foundation

/// Builds duplicate/near-duplicate groups from a flat list of scanned asset metadata.
///
/// Strategy:
/// 1. Images are pre-filtered by perceptual-hash Hamming distance (fast, catches the
///    overwhelming majority of true near-duplicates), then optionally confirmed with
///    Vision feature-print distance when available (higher accuracy, slower).
/// 2. Videos are grouped only by exact content-hash equality, since near-duplicate
///    video detection is explicitly out of scope for v1 (PRD section 11).
/// 3. Union-Find merges transitively-similar assets into clusters.
/// 4. Burst-photo sequences are flagged (not excluded) so the UI/batch logic can give
///    them extra scrutiny per PRD's burst/Live-Photo/RAW+JPEG risk callout.
///
/// Note: pairwise pHash comparison is O(n^2). This is intentional for prototype/MVP
/// correctness and is fast in practice up to tens of thousands of assets (a 64-bit XOR +
/// popcount per comparison). A future optimization pass (per PRD Milestone "Beta:
/// performance tuning for large libraries") could add LSH banding to reduce this for
/// 50k+ libraries.
public enum DuplicateClusterBuilder {
    public static func buildGroups(
        from assets: [ScannedAssetMetadata],
        sensitivity: SimilaritySensitivity
    ) -> [DuplicateGroup] {
        guard assets.count > 1 else { return [] }

        var uf = UnionFind(count: assets.count)

        clusterImagesByPerceptualSimilarity(assets: assets, sensitivity: sensitivity, into: &uf)
        clusterVideosByExactContent(assets: assets, into: &uf)

        return uf.groups()
            .map { makeGroup(indices: $0, assets: assets, sensitivity: sensitivity) }
            .sorted { $0.totalBytes > $1.totalBytes }
    }

    private static func clusterImagesByPerceptualSimilarity(
        assets: [ScannedAssetMetadata],
        sensitivity: SimilaritySensitivity,
        into uf: inout UnionFind
    ) {
        let candidates = assets.indices.filter { !assets[$0].isVideo && assets[$0].perceptualHash != nil }
        guard candidates.count > 1 else { return }

        for i in 0..<(candidates.count - 1) {
            let ai = candidates[i]
            guard let hashA = assets[ai].perceptualHash else { continue }
            for j in (i + 1)..<candidates.count {
                let bi = candidates[j]
                guard let hashB = assets[bi].perceptualHash else { continue }

                let distance = PerceptualHash.hammingDistance(hashA, hashB)
                guard distance <= sensitivity.perceptualHashMaxDistance else { continue }

                if let fpA = assets[ai].featurePrintData, let fpB = assets[bi].featurePrintData,
                   let fpDistance = FeaturePrintMath.distance(fpA, fpB) {
                    guard fpDistance <= sensitivity.featurePrintMaxDistance else { continue }
                } else {
                    // No higher-accuracy feature-print confirmation available — only
                    // trust a much tighter pHash-only match to avoid grouping unrelated
                    // photos that merely share a coarse brightness/gradient pattern.
                    guard distance <= sensitivity.perceptualHashOnlyFallbackMaxDistance else { continue }
                }

                // Visually-similar photos taken far apart in time or space are very
                // unlikely to be true duplicates (e.g. two similar-looking sunsets shot
                // months or continents apart) — use capture metadata as a further gate
                // wherever it's available, without penalizing assets that lack it.
                guard MetadataSimilarity.isConsistent(assets[ai], assets[bi], sensitivity: sensitivity) else { continue }

                uf.union(ai, bi)
            }
        }
    }

    private static func clusterVideosByExactContent(
        assets: [ScannedAssetMetadata],
        into uf: inout UnionFind
    ) {
        var buckets: [String: [Int]] = [:]
        for i in assets.indices where assets[i].isVideo {
            guard let hash = assets[i].contentHashHex else { continue }
            buckets[hash, default: []].append(i)
        }
        for indices in buckets.values where indices.count > 1 {
            for k in 1..<indices.count {
                uf.union(indices[0], indices[k])
            }
        }
    }

    private static func makeGroup(
        indices: [Int],
        assets: [ScannedAssetMetadata],
        sensitivity: SimilaritySensitivity
    ) -> DuplicateGroup {
        let groupAssets = indices.map { assets[$0] }

        let contentHashes = groupAssets.compactMap { $0.contentHashHex }
        let isExact = !contentHashes.isEmpty
            && contentHashes.count == groupAssets.count
            && Set(contentHashes).count == 1

        let isBurst = groupAssets.allSatisfy { $0.burstIdentifier != nil }
            && Set(groupAssets.compactMap { $0.burstIdentifier }).count == 1

        let confidence = computeConfidence(isExact: isExact, isBurst: isBurst, sensitivity: sensitivity)

        return DuplicateGroup(
            assets: groupAssets,
            isExactDuplicateGroup: isExact,
            confidence: confidence,
            isBurst: isBurst
        )
    }

    /// Re-derives `isExactDuplicateGroup`/`confidence` for a single group after its
    /// assets' `contentHashHex` values have been filled in post-hoc (e.g. by a
    /// verification pass that hashes full resource bytes only for already-clustered
    /// candidates). Cluster membership itself is untouched — only these two fields.
    public static func recomputeExactness(of group: DuplicateGroup, sensitivity: SimilaritySensitivity) -> DuplicateGroup {
        var updated = group
        let contentHashes = group.assets.compactMap { $0.contentHashHex }
        let isExact = !contentHashes.isEmpty
            && contentHashes.count == group.assets.count
            && Set(contentHashes).count == 1
        updated.isExactDuplicateGroup = isExact
        updated.confidence = computeConfidence(isExact: isExact, isBurst: group.isBurst, sensitivity: sensitivity)
        return updated
    }

    private static func computeConfidence(isExact: Bool, isBurst: Bool, sensitivity: SimilaritySensitivity) -> Double {
        if isExact { return isBurst ? 0.85 : 1.0 }
        let base: Double
        switch sensitivity {
        case .strict: base = 0.9
        case .moderate: base = 0.75
        case .loose: base = 0.55
        }
        return isBurst ? base * 0.5 : base
    }
}
