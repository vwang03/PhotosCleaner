import Foundation
#if canImport(SQLite3)
import SQLite3
#endif

/// Persists per-session cleanup outcomes so the app can show a historical "total space
/// saved across all sessions" view (PRD 4.5).
public actor ReportStore {
    private let db: SQLiteDatabase

    public init(path: String) throws {
        db = try SQLiteDatabase(path: path)
        try db.exec("""
        CREATE TABLE IF NOT EXISTS session_report (
            id TEXT PRIMARY KEY,
            date REAL NOT NULL,
            photos_deleted INTEGER NOT NULL,
            bytes_freed INTEGER NOT NULL
        );
        """)
    }

    public static func defaultStoreURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("PhotoCleaner", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("reports.sqlite3")
    }

    public func record(_ report: SessionReport) throws {
        try db.query(
            "INSERT INTO session_report (id, date, photos_deleted, bytes_freed) VALUES (?, ?, ?, ?);",
            bind: { stmt in
                sqlite3_bind_text(stmt, 1, report.id, -1, SQLITE_TRANSIENT)
                sqlite3_bind_double(stmt, 2, report.date.timeIntervalSince1970)
                sqlite3_bind_int64(stmt, 3, Int64(report.photosDeleted))
                sqlite3_bind_int64(stmt, 4, report.bytesFreed)
            }
        )
    }

    public func allReports() throws -> [SessionReport] {
        var results: [SessionReport] = []
        try db.query("SELECT id, date, photos_deleted, bytes_freed FROM session_report ORDER BY date DESC;", row: { stmt in
            guard let idCString = sqlite3_column_text(stmt, 0) else { return }
            let id = String(cString: idCString)
            let date = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1))
            let photosDeleted = Int(sqlite3_column_int64(stmt, 2))
            let bytesFreed = sqlite3_column_int64(stmt, 3)
            results.append(SessionReport(id: id, date: date, photosDeleted: photosDeleted, bytesFreed: bytesFreed))
        })
        return results
    }

    public func totalBytesFreed() throws -> Int64 {
        try allReports().reduce(0) { $0 + $1.bytesFreed }
    }

    public func totalPhotosDeleted() throws -> Int {
        try allReports().reduce(0) { $0 + $1.photosDeleted }
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
