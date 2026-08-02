import XCTest
@testable import PhotoCleanerCore

final class MetadataSimilarityTests: XCTestCase {
    func testHaversineDistanceIsZeroForIdenticalCoordinates() {
        let distance = MetadataSimilarity.haversineDistanceMeters(lat1: 40.7128, lon1: -74.0060, lat2: 40.7128, lon2: -74.0060)
        XCTAssertEqual(distance, 0, accuracy: 0.001)
    }

    func testHaversineDistanceMatchesKnownNYCToLondon() {
        // New York to London is approximately 5,570 km.
        let distance = MetadataSimilarity.haversineDistanceMeters(lat1: 40.7128, lon1: -74.0060, lat2: 51.5074, lon2: -0.1278)
        XCTAssertEqual(distance, 5_570_000, accuracy: 50_000)
    }

    func testIsConsistentTrueWhenMetadataMissing() {
        let a = TestFixtures.asset(id: "a", creationDate: nil, perceptualHash: 0)
        let b = TestFixtures.asset(id: "b", creationDate: nil, perceptualHash: 0)
        XCTAssertTrue(MetadataSimilarity.isConsistent(a, b, sensitivity: .strict))
    }

    func testIsConsistentFalseWhenTimeDeltaExceedsThreshold() {
        let a = TestFixtures.asset(id: "a", creationDate: Date(timeIntervalSince1970: 0), perceptualHash: 0)
        let b = TestFixtures.asset(id: "b", creationDate: Date(timeIntervalSince1970: 10_000), perceptualHash: 0)
        XCTAssertFalse(MetadataSimilarity.isConsistent(a, b, sensitivity: .strict))
    }

    func testIsConsistentTrueWhenTimeDeltaWithinThreshold() {
        let a = TestFixtures.asset(id: "a", creationDate: Date(timeIntervalSince1970: 0), perceptualHash: 0)
        let b = TestFixtures.asset(id: "b", creationDate: Date(timeIntervalSince1970: 30), perceptualHash: 0)
        XCTAssertTrue(MetadataSimilarity.isConsistent(a, b, sensitivity: .strict))
    }

    func testIsConsistentFalseWhenLocationDeltaExceedsThreshold() {
        let a = TestFixtures.asset(id: "a", latitude: 40.7128, longitude: -74.0060, perceptualHash: 0)
        let b = TestFixtures.asset(id: "b", latitude: 51.5074, longitude: -0.1278, perceptualHash: 0)
        XCTAssertFalse(MetadataSimilarity.isConsistent(a, b, sensitivity: .loose))
    }

    func testIsConsistentTrueWhenLocationDeltaWithinThreshold() {
        let a = TestFixtures.asset(id: "a", latitude: 40.71280, longitude: -74.00600, perceptualHash: 0)
        let b = TestFixtures.asset(id: "b", latitude: 40.71281, longitude: -74.00601, perceptualHash: 0)
        XCTAssertTrue(MetadataSimilarity.isConsistent(a, b, sensitivity: .strict))
    }
}
