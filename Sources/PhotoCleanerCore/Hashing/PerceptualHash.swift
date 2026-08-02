import Foundation
import CoreGraphics
import CoreImage

/// Computes perceptual hashes ("dHash") for images and provides distance comparison.
///
/// dHash works by shrinking the image to a small fixed grayscale grid, then encoding
/// whether each pixel is brighter than its horizontal neighbor as a single bit. The
/// result is stable under resizing, mild recompression, and small edits — exactly the
/// kind of near-duplicates (re-imports, re-exports, screenshots) this app targets.
public enum PerceptualHash {
    /// Grid is (hashSize+1) x hashSize so we can diff each row of hashSize+1 pixels
    /// down to hashSize bits, producing hashSize*hashSize = 64 bits total.
    private static let hashSize = 8

    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    /// Computes a 64-bit dHash from a CGImage. Returns nil if the image couldn't be
    /// processed (e.g. zero-sized).
    public static func hash(of cgImage: CGImage) -> UInt64? {
        guard cgImage.width > 0, cgImage.height > 0 else { return nil }

        let width = hashSize + 1
        let height = hashSize

        guard let pixels = grayscalePixels(from: cgImage, width: width, height: height) else {
            return nil
        }

        var hash: UInt64 = 0
        var bitIndex = 0
        for row in 0..<height {
            for col in 0..<hashSize {
                let left = pixels[row * width + col]
                let right = pixels[row * width + col + 1]
                if left > right {
                    hash |= (1 << UInt64(bitIndex))
                }
                bitIndex += 1
            }
        }
        return hash
    }

    /// Renders `cgImage` into a `width`x`height` 8-bit grayscale buffer and returns the
    /// raw pixel bytes (0...255 each), or nil on failure.
    private static func grayscalePixels(from cgImage: CGImage, width: Int, height: Int) -> [UInt8]? {
        var buffer = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }
        ctx.interpolationQuality = .high
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }

    /// Hamming distance between two 64-bit hashes (0 = identical, 64 = maximally different).
    public static func hammingDistance(_ a: UInt64, _ b: UInt64) -> Int {
        (a ^ b).nonzeroBitCount
    }
}
