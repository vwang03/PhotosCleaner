import Foundation

/// Controls how aggressively the similarity clustering groups photos together.
public enum SimilaritySensitivity: String, Codable, CaseIterable, Identifiable, Sendable {
    case strict
    case moderate
    case loose

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .strict: return "Strict (near-identical only)"
        case .moderate: return "Moderate"
        case .loose: return "Loose (same scene / burst)"
        }
    }

    /// Maximum Hamming distance between two 64-bit perceptual hashes to be considered
    /// candidates for the same cluster. Used as a fast pre-filter; a Vision
    /// feature-print check (when available) still has to confirm the match below
    /// `featurePrintMaxDistance`, so this can stay a little wider than the true
    /// "same photo" threshold without causing false positives on its own.
    public var perceptualHashMaxDistance: Int {
        switch self {
        case .strict: return 3
        case .moderate: return 8
        case .loose: return 14
        }
    }

    /// Maximum Vision feature-print distance (roughly 0...~2, lower = more similar)
    /// used to confirm a cluster membership after pHash pre-filtering.
    public var featurePrintMaxDistance: Float {
        switch self {
        case .strict: return 0.12
        case .moderate: return 0.20
        case .loose: return 0.30
        }
    }

    /// Maximum Hamming distance permitted when a Vision feature print isn't
    /// available for one or both assets, so a pHash-only match (with no
    /// higher-accuracy confirmation) has to be much tighter to avoid grouping
    /// unrelated photos together.
    public var perceptualHashOnlyFallbackMaxDistance: Int {
        switch self {
        case .strict: return 2
        case .moderate: return 5
        case .loose: return 9
        }
    }

    /// Maximum difference between two assets' capture times for them to still be
    /// considered potential duplicates, when both have a known creation date. Real
    /// duplicates/near-duplicates (re-exports, bursts, quick retakes) are almost
    /// always captured within a short window of each other; two visually-similar
    /// photos captured far apart in time (different days/events) are very unlikely to
    /// be true duplicates, even if their pixels look alike.
    public var maxCaptureTimeIntervalSeconds: TimeInterval {
        switch self {
        case .strict: return 5 * 60        // 5 minutes
        case .moderate: return 60 * 60     // 1 hour
        case .loose: return 24 * 60 * 60   // 24 hours
        }
    }

    /// Maximum distance (in meters) between two assets' capture locations for them to
    /// still be considered potential duplicates, when both have known GPS coordinates.
    /// Photos without location data are never penalized by this check.
    public var maxLocationDistanceMeters: Double {
        switch self {
        case .strict: return 50
        case .moderate: return 200
        case .loose: return 1000
        }
    }
}

/// Strategy for handling assets whose original data is not stored locally
/// (e.g. iCloud "Optimize Mac Storage" libraries).
public enum ICloudAssetPolicy: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Use only the Photos-cached thumbnail/preview for perceptual hashing & feature
    /// prints. Never triggers a download. Exact-duplicate (content hash) detection is
    /// skipped for non-local assets.
    case thumbnailOnly
    /// Skip non-local assets entirely (they will not appear in scan results).
    case skipNonLocal
    /// Request full original data even if it requires downloading from iCloud.
    /// May consume significant bandwidth and temporary local storage.
    case forceDownload

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .thumbnailOnly: return "Use cached thumbnails only (recommended)"
        case .skipNonLocal: return "Skip photos not downloaded locally"
        case .forceDownload: return "Force download originals (uses bandwidth)"
        }
    }
}

public struct ScanSettings: Codable, Equatable, Sendable {
    public var sensitivity: SimilaritySensitivity
    public var includeScreenshots: Bool
    public var includeVideos: Bool
    public var includeHiddenAlbum: Bool
    public var includeFavorites: Bool
    public var iCloudPolicy: ICloudAssetPolicy

    public init(
        sensitivity: SimilaritySensitivity = .moderate,
        includeScreenshots: Bool = true,
        includeVideos: Bool = false,
        includeHiddenAlbum: Bool = false,
        includeFavorites: Bool = true,
        iCloudPolicy: ICloudAssetPolicy = .thumbnailOnly
    ) {
        self.sensitivity = sensitivity
        self.includeScreenshots = includeScreenshots
        self.includeVideos = includeVideos
        self.includeHiddenAlbum = includeHiddenAlbum
        self.includeFavorites = includeFavorites
        self.iCloudPolicy = iCloudPolicy
    }

    public static let `default` = ScanSettings()
}
