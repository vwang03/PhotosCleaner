import XCTest
@testable import PhotoCleanerCore

final class DuplicateClusterBuilderTests: XCTestCase {
    func testExactDuplicatesGroupWithFullConfidence() {
        let a = TestFixtures.asset(id: "a", perceptualHash: 0x0F0F_0F0F_0F0F_0F0F, contentHashHex: "sha-x")
        let b = TestFixtures.asset(id: "b", perceptualHash: 0x0F0F_0F0F_0F0F_0F0F, contentHashHex: "sha-x")

        let groups = DuplicateClusterBuilder.buildGroups(from: [a, b], sensitivity: .moderate)

        XCTAssertEqual(groups.count, 1)
        XCTAssertTrue(groups[0].isExactDuplicateGroup)
        XCTAssertEqual(groups[0].confidence, 1.0)
        XCTAssertEqual(Set(groups[0].assets.map(\.localIdentifier)), Set(["a", "b"]))
    }

    func testNearDuplicatesWithinThresholdGroupButAreNotExact() {
        // Hamming distance of 3 between these two hashes.
        let hashA: UInt64 = 0b0000_0000
        let hashB: UInt64 = 0b0000_0111
        let a = TestFixtures.asset(id: "a", perceptualHash: hashA)
        let b = TestFixtures.asset(id: "b", perceptualHash: hashB)

        let groups = DuplicateClusterBuilder.buildGroups(from: [a, b], sensitivity: .moderate)

        XCTAssertEqual(groups.count, 1)
        XCTAssertFalse(groups[0].isExactDuplicateGroup)
        XCTAssertLessThan(groups[0].confidence, 1.0)
    }

    func testDissimilarImagesAreNotGrouped() {
        let a = TestFixtures.asset(id: "a", perceptualHash: 0x0000_0000_0000_0000)
        let b = TestFixtures.asset(id: "b", perceptualHash: 0xFFFF_FFFF_FFFF_FFFF)

        let groups = DuplicateClusterBuilder.buildGroups(from: [a, b], sensitivity: .strict)

        XCTAssertTrue(groups.isEmpty)
    }

    func testStrictSensitivityIsMoreConservativeThanLoose() {
        // Distance of 7 (no feature print in these fixtures, so the pHash-only
        // fallback threshold applies): exceeds strict's fallback max (2), but is
        // within loose's fallback max (9), so it should not cluster under strict but
        // should under loose.
        let hashA: UInt64 = 0
        let hashB: UInt64 = 0b111_1111 // 7 bits set

        let a1 = TestFixtures.asset(id: "a", perceptualHash: hashA)
        let b1 = TestFixtures.asset(id: "b", perceptualHash: hashB)
        let strictGroups = DuplicateClusterBuilder.buildGroups(from: [a1, b1], sensitivity: .strict)
        XCTAssertTrue(strictGroups.isEmpty)

        let a2 = TestFixtures.asset(id: "a", perceptualHash: hashA)
        let b2 = TestFixtures.asset(id: "b", perceptualHash: hashB)
        let looseGroups = DuplicateClusterBuilder.buildGroups(from: [a2, b2], sensitivity: .loose)
        XCTAssertEqual(looseGroups.count, 1)
    }

    func testPerceptualHashOnlyMatchRequiresTighterFallbackDistanceWithoutFeaturePrint() {
        // Distance of 12 is within loose's pHash pre-filter (14) but exceeds loose's
        // stricter pHash-only fallback max (9) that applies when no Vision feature
        // print is available to confirm the match — so these should NOT cluster, even
        // though the old, looser pre-filter-only behavior would have grouped them.
        let hashA: UInt64 = 0
        let hashB: UInt64 = 0b1111_1111_1111 // 12 bits set

        let a = TestFixtures.asset(id: "a", perceptualHash: hashA)
        let b = TestFixtures.asset(id: "b", perceptualHash: hashB)
        let groups = DuplicateClusterBuilder.buildGroups(from: [a, b], sensitivity: .loose)

        XCTAssertTrue(groups.isEmpty)
    }

    func testBurstPhotosAreFlaggedAndLowerConfidence() {
        let a = TestFixtures.asset(id: "a", burstIdentifier: "burst-1", perceptualHash: 0)
        let b = TestFixtures.asset(id: "b", burstIdentifier: "burst-1", perceptualHash: 1)

        let groups = DuplicateClusterBuilder.buildGroups(from: [a, b], sensitivity: .moderate)

        XCTAssertEqual(groups.count, 1)
        XCTAssertTrue(groups[0].isBurst)
        XCTAssertLessThan(groups[0].confidence, 0.5)
    }

    func testVideosGroupOnlyByExactContentHash() {
        let v1 = TestFixtures.asset(id: "v1", isVideo: true, contentHashHex: "hash-1")
        let v2 = TestFixtures.asset(id: "v2", isVideo: true, contentHashHex: "hash-1")
        let v3 = TestFixtures.asset(id: "v3", isVideo: true, contentHashHex: "hash-2")

        let groups = DuplicateClusterBuilder.buildGroups(from: [v1, v2, v3], sensitivity: .loose)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(Set(groups[0].assets.map(\.localIdentifier)), Set(["v1", "v2"]))
        XCTAssertTrue(groups[0].isExactDuplicateGroup)
    }

    func testVideosNeverClusterWithImagesEvenIfPerceptualHashPresent() {
        let image = TestFixtures.asset(id: "img", perceptualHash: 42)
        let video = TestFixtures.asset(id: "vid", isVideo: true, perceptualHash: 42)

        let groups = DuplicateClusterBuilder.buildGroups(from: [image, video], sensitivity: .loose)

        XCTAssertTrue(groups.isEmpty)
    }

    func testGroupsSortedByTotalBytesDescending() {
        let smallGroupA = TestFixtures.asset(id: "s1", pixelWidth: 100, pixelHeight: 100, fileSizeBytes: 1000, perceptualHash: 0)
        let smallGroupB = TestFixtures.asset(id: "s2", pixelWidth: 100, pixelHeight: 100, fileSizeBytes: 1000, perceptualHash: 0)

        // 16 bits apart from hash 0, which exceeds .moderate's max distance of 8, keeping
        // this group distinct from the "small" group above.
        let bigGroupA = TestFixtures.asset(id: "b1", pixelWidth: 100, pixelHeight: 100, fileSizeBytes: 50_000_000, perceptualHash: 0xFFFF)
        let bigGroupB = TestFixtures.asset(id: "b2", pixelWidth: 100, pixelHeight: 100, fileSizeBytes: 50_000_000, perceptualHash: 0xFFFF)

        let groups = DuplicateClusterBuilder.buildGroups(
            from: [smallGroupA, smallGroupB, bigGroupA, bigGroupB],
            sensitivity: .moderate
        )

        XCTAssertEqual(groups.count, 2)
        XCTAssertGreaterThan(groups[0].totalBytes, groups[1].totalBytes)
    }

    func testVisuallySimilarPhotosFarApartInTimeAreNotGrouped() {
        let a = TestFixtures.asset(
            id: "a",
            creationDate: Date(timeIntervalSince1970: 0),
            perceptualHash: 0
        )
        let b = TestFixtures.asset(
            id: "b",
            // Two days later — far beyond even .loose's 24-hour capture-time window.
            creationDate: Date(timeIntervalSince1970: 2 * 24 * 60 * 60),
            perceptualHash: 0
        )

        let groups = DuplicateClusterBuilder.buildGroups(from: [a, b], sensitivity: .loose)

        XCTAssertTrue(groups.isEmpty)
    }

    func testVisuallySimilarPhotosFarApartInLocationAreNotGrouped() {
        let a = TestFixtures.asset(id: "a", latitude: 40.7128, longitude: -74.0060, perceptualHash: 0) // New York
        let b = TestFixtures.asset(id: "b", latitude: 35.6762, longitude: 139.6503, perceptualHash: 0) // Tokyo

        let groups = DuplicateClusterBuilder.buildGroups(from: [a, b], sensitivity: .loose)

        XCTAssertTrue(groups.isEmpty)
    }

    func testMatchingTimeAndLocationStillGroupsSimilarPhotos() {
        let sharedDate = Date(timeIntervalSince1970: 1_000_000)
        let a = TestFixtures.asset(id: "a", creationDate: sharedDate, latitude: 40.7128, longitude: -74.0060, perceptualHash: 0)
        let b = TestFixtures.asset(id: "b", creationDate: sharedDate, latitude: 40.7130, longitude: -74.0061, perceptualHash: 0)

        let groups = DuplicateClusterBuilder.buildGroups(from: [a, b], sensitivity: .strict)

        XCTAssertEqual(groups.count, 1)
    }

    func testMissingMetadataDoesNotBlockAnOtherwiseValidMatch() {
        // Neither asset has a creation date or location, so the metadata gate should
        // simply be skipped rather than rejecting the match.
        let a = TestFixtures.asset(id: "a", creationDate: nil, perceptualHash: 0)
        let b = TestFixtures.asset(id: "b", creationDate: nil, perceptualHash: 0)

        let groups = DuplicateClusterBuilder.buildGroups(from: [a, b], sensitivity: .strict)

        XCTAssertEqual(groups.count, 1)
    }

    func testSingleAssetProducesNoGroups() {
        let a = TestFixtures.asset(id: "a", perceptualHash: 0)
        XCTAssertTrue(DuplicateClusterBuilder.buildGroups(from: [a], sensitivity: .loose).isEmpty)
    }
}
