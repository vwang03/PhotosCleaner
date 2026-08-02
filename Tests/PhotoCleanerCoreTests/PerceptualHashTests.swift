import XCTest
import CoreGraphics
@testable import PhotoCleanerCore

final class PerceptualHashTests: XCTestCase {
    private func makeSolidImage(width: Int, height: Int, color: CGFloat) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue
        )!
        ctx.setFillColor(gray: color, alpha: 1.0)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()!
    }

    /// dHash encodes "is this pixel brighter than the pixel to its right", so a
    /// monotonic left-to-right gradient can go either direction to produce two
    /// maximally-distinguishable hashes (all-0 bits vs. all-1 bits).
    private func makeGradientImage(width: Int, height: Int, ascending: Bool = true) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue
        )!
        for x in 0..<width {
            let t = CGFloat(x) / CGFloat(width)
            let gray = ascending ? t : 1 - t
            ctx.setFillColor(gray: gray, alpha: 1.0)
            ctx.fill(CGRect(x: x, y: 0, width: 1, height: height))
        }
        return ctx.makeImage()!
    }

    func testIdenticalImagesProduceIdenticalHashes() {
        let image = makeGradientImage(width: 64, height: 64)
        let hashA = PerceptualHash.hash(of: image)
        let hashB = PerceptualHash.hash(of: image)
        XCTAssertNotNil(hashA)
        XCTAssertEqual(hashA, hashB)
        XCTAssertEqual(PerceptualHash.hammingDistance(hashA!, hashB!), 0)
    }

    func testDifferentImagesProduceDistantHashes() {
        let solidBlack = makeSolidImage(width: 64, height: 64, color: 0.0)
        let solidWhite = makeSolidImage(width: 64, height: 64, color: 1.0)
        let ascending = makeGradientImage(width: 64, height: 64, ascending: true)
        let descending = makeGradientImage(width: 64, height: 64, ascending: false)

        guard let hashBlack = PerceptualHash.hash(of: solidBlack),
              let hashWhite = PerceptualHash.hash(of: solidWhite),
              let hashAscending = PerceptualHash.hash(of: ascending),
              let hashDescending = PerceptualHash.hash(of: descending) else {
            XCTFail("Expected hashes to be computed")
            return
        }

        // Solid colors have no horizontal gradient anywhere, so both should hash to all-zero bits.
        XCTAssertEqual(PerceptualHash.hammingDistance(hashBlack, hashWhite), 0)

        // Opposite-direction gradients should be maximally distinguishable.
        XCTAssertGreaterThan(PerceptualHash.hammingDistance(hashAscending, hashDescending), 32)
    }

    func testHammingDistanceIsSymmetricAndZeroForSelf() {
        let a: UInt64 = 0b1010_1010
        let b: UInt64 = 0b0101_0101
        XCTAssertEqual(PerceptualHash.hammingDistance(a, a), 0)
        XCTAssertEqual(PerceptualHash.hammingDistance(a, b), PerceptualHash.hammingDistance(b, a))
        XCTAssertEqual(PerceptualHash.hammingDistance(a, b), 8)
    }

    func testZeroSizedImageReturnsNil() {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        // A 1x1 image is valid; verify it doesn't crash and produces *some* hash.
        let ctx = CGContext(
            data: nil, width: 1, height: 1,
            bitsPerComponent: 8, bytesPerRow: 1,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue
        )!
        ctx.setFillColor(gray: 0.5, alpha: 1.0)
        ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        let image = ctx.makeImage()!
        XCTAssertNotNil(PerceptualHash.hash(of: image))
    }
}
