import Foundation

/// A lightweight, Photos-framework-agnostic representation of a single asset's
/// metadata and computed fingerprints. This is what gets cached and clustered.
public struct ScannedAssetMetadata: Codable, Equatable, Sendable, Identifiable {
    public var id: String { localIdentifier }

    public let localIdentifier: String
    public let modificationDate: Date
    public let creationDate: Date?
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let fileSizeBytes: Int64
    public let isFavorite: Bool
    public let hasAdjustments: Bool
    public let isScreenshot: Bool
    public let isVideo: Bool
    public let isLocallyAvailable: Bool
    public let burstIdentifier: String?
    public let albumNames: [String]

    /// Capture location, if the asset has one. Used as an additional similarity signal
    /// (visually-similar photos taken far apart are unlikely to be true duplicates).
    public let latitude: Double?
    public let longitude: Double?

    /// 64-bit perceptual hash (dHash) of the image. `nil` for videos or when hashing failed.
    public var perceptualHash: UInt64?

    /// Vision feature-print serialized as raw Float32 data, used for higher accuracy
    /// similarity confirmation. `nil` if not computed (e.g. thumbnail-only policy skipped it).
    public var featurePrintData: Data?

    /// SHA-256 hex digest of the full asset resource data, used for exact-duplicate
    /// detection. `nil` if not computed (e.g. asset not local and policy skips it).
    public var contentHashHex: String?

    public var megabytes: Double {
        Double(fileSizeBytes) / 1_048_576.0
    }

    public var resolutionDescription: String {
        "\(pixelWidth) × \(pixelHeight)"
    }

    public var megapixels: Double {
        Double(pixelWidth * pixelHeight) / 1_000_000.0
    }

    public init(
        localIdentifier: String,
        modificationDate: Date,
        creationDate: Date?,
        pixelWidth: Int,
        pixelHeight: Int,
        fileSizeBytes: Int64,
        isFavorite: Bool,
        hasAdjustments: Bool,
        isScreenshot: Bool,
        isVideo: Bool,
        isLocallyAvailable: Bool,
        burstIdentifier: String?,
        albumNames: [String],
        latitude: Double? = nil,
        longitude: Double? = nil,
        perceptualHash: UInt64? = nil,
        featurePrintData: Data? = nil,
        contentHashHex: String? = nil
    ) {
        self.localIdentifier = localIdentifier
        self.modificationDate = modificationDate
        self.creationDate = creationDate
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.fileSizeBytes = fileSizeBytes
        self.isFavorite = isFavorite
        self.hasAdjustments = hasAdjustments
        self.isScreenshot = isScreenshot
        self.isVideo = isVideo
        self.isLocallyAvailable = isLocallyAvailable
        self.burstIdentifier = burstIdentifier
        self.albumNames = albumNames
        self.latitude = latitude
        self.longitude = longitude
        self.perceptualHash = perceptualHash
        self.featurePrintData = featurePrintData
        self.contentHashHex = contentHashHex
    }
}
