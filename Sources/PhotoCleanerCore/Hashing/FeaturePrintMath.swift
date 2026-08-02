import Foundation

/// Pure-math distance computation over serialized Vision feature-print vectors, kept
/// free of the `Vision` import so it stays trivially unit-testable.
public enum FeaturePrintMath {
    /// Decodes `data` as a contiguous array of Float32 values (little-endian, native).
    public static func floats(from data: Data) -> [Float] {
        data.withUnsafeBytes { rawBuffer in
            Array(rawBuffer.bindMemory(to: Float.self))
        }
    }

    public static func data(from floats: [Float]) -> Data {
        floats.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    /// Normalized Euclidean distance between two feature-print vectors. Returns nil if
    /// the vectors are empty or of mismatched length.
    public static func distance(_ a: Data, _ b: Data) -> Float? {
        let fa = floats(from: a)
        let fb = floats(from: b)
        guard !fa.isEmpty, fa.count == fb.count else { return nil }

        var sumSquares: Float = 0
        for i in 0..<fa.count {
            let diff = fa[i] - fb[i]
            sumSquares += diff * diff
        }
        // Normalize by dimensionality so the distance scale is comparable across
        // feature-print versions of differing lengths.
        return (sumSquares / Float(fa.count)).squareRoot()
    }
}
