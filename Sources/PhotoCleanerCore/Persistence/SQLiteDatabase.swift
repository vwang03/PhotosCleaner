import Foundation
#if canImport(SQLite3)
import SQLite3
#endif

/// Minimal thread-confined SQLite wrapper. Each `SQLiteDatabase` instance should be
/// used from a single queue/actor; callers in this app access it via actor isolation
/// in `ScanCacheStore` / `ReportStore`.
final class SQLiteDatabase {
    private var db: OpaquePointer?

    init(path: String) throws {
        if sqlite3_open(path, &db) != SQLITE_OK {
            let message = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw SQLiteError.openFailed(message)
        }
        sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA foreign_keys=ON;", nil, nil, nil)
    }

    deinit {
        sqlite3_close(db)
    }

    enum SQLiteError: Error, CustomStringConvertible {
        case openFailed(String)
        case execFailed(String)
        case prepareFailed(String)
        case stepFailed(String)

        var description: String {
            switch self {
            case .openFailed(let m): return "SQLite open failed: \(m)"
            case .execFailed(let m): return "SQLite exec failed: \(m)"
            case .prepareFailed(let m): return "SQLite prepare failed: \(m)"
            case .stepFailed(let m): return "SQLite step failed: \(m)"
            }
        }
    }

    func exec(_ sql: String) throws {
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            throw SQLiteError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    /// Prepares and runs `sql`, calling `bind` to attach parameters and `step` once per
    /// resulting row so callers can read columns via the provided statement pointer.
    @discardableResult
    func query(
        _ sql: String,
        bind: (OpaquePointer?) -> Void = { _ in },
        row: (OpaquePointer?) -> Void = { _ in }
    ) throws -> Int32 {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            throw SQLiteError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        bind(statement)

        var result: Int32 = SQLITE_DONE
        while true {
            result = sqlite3_step(statement)
            if result == SQLITE_ROW {
                row(statement)
                continue
            }
            break
        }
        if result != SQLITE_DONE {
            throw SQLiteError.stepFailed(String(cString: sqlite3_errmsg(db)))
        }
        return result
    }
}
