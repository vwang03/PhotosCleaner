import XCTest
@testable import PhotoCleanerCore

final class FeaturePrintMathTests: XCTestCase {
    func testIdenticalVectorsHaveZeroDistance() {
        let vector: [Float] = [0.1, 0.2, 0.3, 0.4]
        let data = FeaturePrintMath.data(from: vector)
        XCTAssertEqual(FeaturePrintMath.distance(data, data), 0)
    }

    func testRoundTripPreservesValues() {
        let vector: [Float] = [1.5, -2.25, 3.75]
        let data = FeaturePrintMath.data(from: vector)
        let decoded = FeaturePrintMath.floats(from: data)
        XCTAssertEqual(decoded, vector)
    }

    func testDifferentVectorsHavePositiveDistance() {
        let a = FeaturePrintMath.data(from: [0, 0, 0])
        let b = FeaturePrintMath.data(from: [1, 1, 1])
        let distance = FeaturePrintMath.distance(a, b)
        XCTAssertNotNil(distance)
        XCTAssertGreaterThan(distance!, 0)
    }

    func testMismatchedLengthReturnsNil() {
        let a = FeaturePrintMath.data(from: [0, 0])
        let b = FeaturePrintMath.data(from: [0, 0, 0])
        XCTAssertNil(FeaturePrintMath.distance(a, b))
    }

    func testEmptyVectorReturnsNil() {
        let a = FeaturePrintMath.data(from: [])
        let b = FeaturePrintMath.data(from: [])
        XCTAssertNil(FeaturePrintMath.distance(a, b))
    }
}
