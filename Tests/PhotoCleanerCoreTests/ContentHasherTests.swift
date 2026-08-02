import XCTest
@testable import PhotoCleanerCore

final class ContentHasherTests: XCTestCase {
    func testSHA256MatchesKnownVector() {
        // SHA-256("abc") is a well-known test vector.
        let data = Data("abc".utf8)
        let hex = ContentHasher.hashHex(of: data)
        XCTAssertEqual(hex, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    func testStreamingMatchesOneShot() {
        let part1 = Data("hello ".utf8)
        let part2 = Data("world".utf8)
        var hasher = ContentHasher()
        hasher.update(part1)
        hasher.update(part2)
        let streamed = hasher.finalizeHex()

        let oneShot = ContentHasher.hashHex(of: part1 + part2)
        XCTAssertEqual(streamed, oneShot)
    }

    func testDifferentDataProducesDifferentHash() {
        let hashA = ContentHasher.hashHex(of: Data("foo".utf8))
        let hashB = ContentHasher.hashHex(of: Data("bar".utf8))
        XCTAssertNotEqual(hashA, hashB)
    }
}
