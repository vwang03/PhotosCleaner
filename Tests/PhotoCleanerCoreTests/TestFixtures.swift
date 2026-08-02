import Foundation
@testable import PhotoCleanerCore

enum TestFixtures {
    static func asset(
        id: String,
        modificationDate: Date = Date(),
        creationDate: Date? = Date(),
        pixelWidth: Int = 3000,
        pixelHeight: Int = 2000,
        fileSizeBytes: Int64 = 4_000_000,
        isFavorite: Bool = false,
        hasAdjustments: Bool = false,
        isScreenshot: Bool = false,
        isVideo: Bool = false,
        isLocallyAvailable: Bool = true,
        burstIdentifier: String? = nil,
        albumNames: [String] = [],
        latitude: Double? = nil,
        longitude: Double? = nil,
        perceptualHash: UInt64? = nil,
        featurePrintData: Data? = nil,
        contentHashHex: String? = nil
    ) -> ScannedAssetMetadata {
        ScannedAssetMetadata(
            localIdentifier: id,
            modificationDate: modificationDate,
            creationDate: creationDate,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            fileSizeBytes: fileSizeBytes,
            isFavorite: isFavorite,
            hasAdjustments: hasAdjustments,
            isScreenshot: isScreenshot,
            isVideo: isVideo,
            isLocallyAvailable: isLocallyAvailable,
            burstIdentifier: burstIdentifier,
            albumNames: albumNames,
            latitude: latitude,
            longitude: longitude,
            perceptualHash: perceptualHash,
            featurePrintData: featurePrintData,
            contentHashHex: contentHashHex
        )
    }
}
