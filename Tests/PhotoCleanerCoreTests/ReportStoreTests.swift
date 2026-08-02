import XCTest
@testable import PhotoCleanerCore

final class ReportStoreTests: XCTestCase {
    private func makeTempStore() throws -> (ReportStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("reports.sqlite3")
        return (try ReportStore(path: path.path), dir)
    }

    func testRecordAndTotals() async throws {
        let (store, dir) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        try await store.record(SessionReport(photosDeleted: 10, bytesFreed: 1_000_000))
        try await store.record(SessionReport(photosDeleted: 5, bytesFreed: 500_000))

        let total = try await store.totalBytesFreed()
        let totalPhotos = try await store.totalPhotosDeleted()

        XCTAssertEqual(total, 1_500_000)
        XCTAssertEqual(totalPhotos, 15)
    }

    func testAllReportsOrderedByDateDescending() async throws {
        let (store, dir) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let older = SessionReport(date: Date(timeIntervalSince1970: 1000), photosDeleted: 1, bytesFreed: 1)
        let newer = SessionReport(date: Date(timeIntervalSince1970: 2000), photosDeleted: 2, bytesFreed: 2)

        try await store.record(older)
        try await store.record(newer)

        let all = try await store.allReports()
        XCTAssertEqual(all.map(\.id), [newer.id, older.id])
    }

    func testEmptyStoreReturnsZeroTotals() async throws {
        let (store, dir) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let bytesFreed = try await store.totalBytesFreed()
        let photosDeleted = try await store.totalPhotosDeleted()
        let reports = try await store.allReports()
        XCTAssertEqual(bytesFreed, 0)
        XCTAssertEqual(photosDeleted, 0)
        XCTAssertTrue(reports.isEmpty)
    }
}
