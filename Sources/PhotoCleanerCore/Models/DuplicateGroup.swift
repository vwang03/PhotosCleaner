import Foundation

/// A cluster of assets considered duplicates or near-duplicates of one another.
public struct DuplicateGroup: Identifiable, Equatable, Sendable {
    public let id: String
    public var assets: [ScannedAssetMetadata]
    /// True if every asset in the group is a byte-for-byte content match.
    public var isExactDuplicateGroup: Bool
    /// 0...1 confidence that this group truly represents redundant photos.
    public var confidence: Double
    /// True when every asset in the group shares the same burst identifier (or is a
    /// Live Photo / RAW+JPEG pairing signal). Such groups are intentionally kept together
    /// by photographers, so review UI gives them extra scrutiny.
    public var isBurst: Bool

    public init(
        id: String = UUID().uuidString,
        assets: [ScannedAssetMetadata],
        isExactDuplicateGroup: Bool,
        confidence: Double,
        isBurst: Bool = false
    ) {
        self.id = id
        self.assets = assets
        self.isExactDuplicateGroup = isExactDuplicateGroup
        self.confidence = confidence
        self.isBurst = isBurst
    }

    public var totalBytes: Int64 {
        assets.reduce(0) { $0 + $1.fileSizeBytes }
    }
}
