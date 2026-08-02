import Foundation
import CryptoKit

/// Streaming SHA-256 hashing for exact-duplicate detection over raw asset resource bytes.
public struct ContentHasher {
    private var hasher = SHA256()

    public init() {}

    public mutating func update(_ data: Data) {
        hasher.update(data: data)
    }

    public mutating func finalizeHex() -> String {
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Convenience one-shot hash of an in-memory buffer.
    public static func hashHex(of data: Data) -> String {
        var hasher = SHA256()
        hasher.update(data: data)
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
