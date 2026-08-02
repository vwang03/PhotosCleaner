import XCTest
@testable import PhotoCleanerCore

final class ScanCacheStoreTests: XCTestCase {
    private func makeTempStore() throws -> (ScanCacheStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("test.sqlite3")
        return (try ScanCacheStore(path: path.path), dir)
    }

    override func tearDown() {
        super.tearDown()
    }

    func testUpsertAndFetchRoundTrip() async throws {
        let (store, dir) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let asset = TestFixtures.asset(
            id: "asset-1",
            fileSizeBytes: 12345,
            burstIdentifier: "burst-a",
            albumNames: ["Vacation", "Family"],
            latitude: 40.7128,
            longitude: -74.0060,
            perceptualHash: 0xDEAD_BEEF_0000_0001,
            featurePrintData: Data([1, 2, 3, 4]),
            contentHashHex: "abc123"
        )

        try await store.upsert(asset)
        let fetched = try await store.fetch(localIdentifier: "asset-1")

        XCTAssertEqual(fetched?.localIdentifier, asset.localIdentifier)
        XCTAssertEqual(fetched?.fileSizeBytes, asset.fileSizeBytes)
        XCTAssertEqual(fetched?.burstIdentifier, asset.burstIdentifier)
        XCTAssertEqual(fetched?.albumNames, asset.albumNames)
        XCTAssertEqual(fetched?.latitude, asset.latitude)
        XCTAssertEqual(fetched?.longitude, asset.longitude)
        XCTAssertEqual(fetched?.perceptualHash, asset.perceptualHash)
        XCTAssertEqual(fetched?.featurePrintData, asset.featurePrintData)
        XCTAssertEqual(fetched?.contentHashHex, asset.contentHashHex)
    }

    func testUpsertOverwritesExistingRow() async throws {
        let (store, dir) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        try await store.upsert(TestFixtures.asset(id: "a", fileSizeBytes: 100))
        try await store.upsert(TestFixtures.asset(id: "a", fileSizeBytes: 999))

        let all = try await store.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.fileSizeBytes, 999)
    }

    func testCachedIfCurrentReturnsNilWhenModificationDateChanged() async throws {
        let (store, dir) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let originalDate = Date(timeIntervalSince1970: 1_000_000)
        try await store.upsert(TestFixtures.asset(id: "a", modificationDate: originalDate))

        let stillCurrent = try await store.cachedIfCurrent(localIdentifier: "a", currentModificationDate: originalDate)
        XCTAssertNotNil(stillCurrent)

        let staleCheck = try await store.cachedIfCurrent(
            localIdentifier: "a",
            currentModificationDate: originalDate.addingTimeInterval(3600)
        )
        XCTAssertNil(staleCheck)
    }

    func testPruneCacheRemovesStaleEntries() async throws {
        let (store, dir) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        try await store.upsertBatch([
            TestFixtures.asset(id: "keep"),
            TestFixtures.asset(id: "stale")
        ])

        try await store.pruneCache(keepingOnly: ["keep"])

        let all = try await store.fetchAll()
        XCTAssertEqual(all.map(\.localIdentifier), ["keep"])
    }

    func testFetchMissingReturnsNil() async throws {
        let (store, dir) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = try await store.fetch(localIdentifier: "does-not-exist")
        XCTAssertNil(result)
    }
}
