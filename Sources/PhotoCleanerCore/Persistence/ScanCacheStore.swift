import Foundation
#if canImport(SQLite3)
import SQLite3
#endif

/// Persists computed fingerprints/metadata per asset, keyed by local identifier, so
/// re-scans can skip assets whose modification date hasn't changed (PRD 4.2: "Cache
/// scan results locally ... so re-scans are incremental, not full re-processes").
public actor ScanCacheStore {
    private let db: SQLiteDatabase

    public init(path: String) throws {
        db = try SQLiteDatabase(path: path)
        try db.exec("""
        CREATE TABLE IF NOT EXISTS asset_cache (
            local_identifier TEXT PRIMARY KEY,
            modification_date REAL NOT NULL,
            creation_date REAL,
            pixel_width INTEGER NOT NULL,
            pixel_height INTEGER NOT NULL,
            file_size_bytes INTEGER NOT NULL,
            is_favorite INTEGER NOT NULL,
            has_adjustments INTEGER NOT NULL,
            is_screenshot INTEGER NOT NULL,
            is_video INTEGER NOT NULL,
            is_locally_available INTEGER NOT NULL,
            burst_identifier TEXT,
            album_names TEXT,
            latitude REAL,
            longitude REAL,
            perceptual_hash INTEGER,
            feature_print_data BLOB,
            content_hash_hex TEXT
        );
        """)
        // Existing installs created `asset_cache` before `latitude`/`longitude`
        // existed; `CREATE TABLE IF NOT EXISTS` won't retroactively add columns, so add
        // them here. `try?` ignores the "duplicate column" failure when they already exist.
        try? db.exec("ALTER TABLE asset_cache ADD COLUMN latitude REAL;")
        try? db.exec("ALTER TABLE asset_cache ADD COLUMN longitude REAL;")
    }

    public static func defaultStoreURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("PhotoCleaner", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("scan_cache.sqlite3")
    }

    /// Returns the cached record only if its stored modification date matches
    /// `currentModificationDate`, indicating the asset hasn't changed since last scan.
    public func cachedIfCurrent(localIdentifier: String, currentModificationDate: Date) throws -> ScannedAssetMetadata? {
        guard let cached = try fetch(localIdentifier: localIdentifier) else { return nil }
        // Treat sub-second jitter as equal; Photos modification dates are stable to the second.
        if abs(cached.modificationDate.timeIntervalSince(currentModificationDate)) < 1.0 {
            return cached
        }
        return nil
    }

    /// Explicit column list (rather than `SELECT *`) so decoding always sees a fixed
    /// column order, regardless of whether `latitude`/`longitude` physically live next
    /// to `album_names` (fresh installs) or at the end of the table (installs migrated
    /// via `ALTER TABLE ... ADD COLUMN`, which always appends).
    private static let selectColumns = """
    local_identifier, modification_date, creation_date, pixel_width, pixel_height,
    file_size_bytes, is_favorite, has_adjustments, is_screenshot, is_video,
    is_locally_available, burst_identifier, album_names, latitude, longitude,
    perceptual_hash, feature_print_data, content_hash_hex
    """

    public func fetch(localIdentifier: String) throws -> ScannedAssetMetadata? {
        var result: ScannedAssetMetadata?
        try db.query(
            "SELECT \(Self.selectColumns) FROM asset_cache WHERE local_identifier = ?;",
            bind: { stmt in sqlite3_bind_text(stmt, 1, localIdentifier, -1, SQLITE_TRANSIENT) },
            row: { stmt in result = Self.decode(stmt) }
        )
        return result
    }

    public func fetchAll() throws -> [ScannedAssetMetadata] {
        var results: [ScannedAssetMetadata] = []
        try db.query("SELECT \(Self.selectColumns) FROM asset_cache;", row: { stmt in
            if let decoded = Self.decode(stmt) {
                results.append(decoded)
            }
        })
        return results
    }

    public func upsert(_ asset: ScannedAssetMetadata) throws {
        try upsertBatch([asset])
    }

    public func upsertBatch(_ assets: [ScannedAssetMetadata]) throws {
        guard !assets.isEmpty else { return }
        try db.exec("BEGIN TRANSACTION;")
        do {
            for asset in assets {
                try insertOrReplace(asset)
            }
            try db.exec("COMMIT;")
        } catch {
            try? db.exec("ROLLBACK;")
            throw error
        }
    }

    /// Removes cache rows for assets no longer present in the library (e.g. deleted
    /// outside the app, or deleted by a previous PhotoCleaner session).
    public func pruneCache(keepingOnly liveIdentifiers: Set<String>) throws {
        let all = try fetchAll()
        let stale = all.map(\.localIdentifier).filter { !liveIdentifiers.contains($0) }
        guard !stale.isEmpty else { return }
        try db.exec("BEGIN TRANSACTION;")
        do {
            for id in stale {
                try db.query("DELETE FROM asset_cache WHERE local_identifier = ?;", bind: { stmt in
                    sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
                })
            }
            try db.exec("COMMIT;")
        } catch {
            try? db.exec("ROLLBACK;")
            throw error
        }
    }

    public func removeAll() throws {
        try db.exec("DELETE FROM asset_cache;")
    }

    private func insertOrReplace(_ asset: ScannedAssetMetadata) throws {
        let sql = """
        INSERT INTO asset_cache (
            local_identifier, modification_date, creation_date, pixel_width, pixel_height,
            file_size_bytes, is_favorite, has_adjustments, is_screenshot, is_video,
            is_locally_available, burst_identifier, album_names, latitude, longitude,
            perceptual_hash, feature_print_data, content_hash_hex
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(local_identifier) DO UPDATE SET
            modification_date = excluded.modification_date,
            creation_date = excluded.creation_date,
            pixel_width = excluded.pixel_width,
            pixel_height = excluded.pixel_height,
            file_size_bytes = excluded.file_size_bytes,
            is_favorite = excluded.is_favorite,
            has_adjustments = excluded.has_adjustments,
            is_screenshot = excluded.is_screenshot,
            is_video = excluded.is_video,
            is_locally_available = excluded.is_locally_available,
            burst_identifier = excluded.burst_identifier,
            album_names = excluded.album_names,
            latitude = excluded.latitude,
            longitude = excluded.longitude,
            perceptual_hash = excluded.perceptual_hash,
            feature_print_data = excluded.feature_print_data,
            content_hash_hex = excluded.content_hash_hex;
        """
        let albumNamesJSON = (try? JSONEncoder().encode(asset.albumNames)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        try db.query(sql, bind: { stmt in
            sqlite3_bind_text(stmt, 1, asset.localIdentifier, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 2, asset.modificationDate.timeIntervalSince1970)
            if let creation = asset.creationDate {
                sqlite3_bind_double(stmt, 3, creation.timeIntervalSince1970)
            } else {
                sqlite3_bind_null(stmt, 3)
            }
            sqlite3_bind_int64(stmt, 4, Int64(asset.pixelWidth))
            sqlite3_bind_int64(stmt, 5, Int64(asset.pixelHeight))
            sqlite3_bind_int64(stmt, 6, asset.fileSizeBytes)
            sqlite3_bind_int(stmt, 7, asset.isFavorite ? 1 : 0)
            sqlite3_bind_int(stmt, 8, asset.hasAdjustments ? 1 : 0)
            sqlite3_bind_int(stmt, 9, asset.isScreenshot ? 1 : 0)
            sqlite3_bind_int(stmt, 10, asset.isVideo ? 1 : 0)
            sqlite3_bind_int(stmt, 11, asset.isLocallyAvailable ? 1 : 0)
            if let burst = asset.burstIdentifier {
                sqlite3_bind_text(stmt, 12, burst, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 12)
            }
            sqlite3_bind_text(stmt, 13, albumNamesJSON, -1, SQLITE_TRANSIENT)
            if let latitude = asset.latitude {
                sqlite3_bind_double(stmt, 14, latitude)
            } else {
                sqlite3_bind_null(stmt, 14)
            }
            if let longitude = asset.longitude {
                sqlite3_bind_double(stmt, 15, longitude)
            } else {
                sqlite3_bind_null(stmt, 15)
            }
            if let hash = asset.perceptualHash {
                sqlite3_bind_int64(stmt, 16, Int64(bitPattern: hash))
            } else {
                sqlite3_bind_null(stmt, 16)
            }
            if let fp = asset.featurePrintData {
                _ = fp.withUnsafeBytes { raw in
                    sqlite3_bind_blob(stmt, 17, raw.baseAddress, Int32(raw.count), SQLITE_TRANSIENT)
                }
            } else {
                sqlite3_bind_null(stmt, 17)
            }
            if let hex = asset.contentHashHex {
                sqlite3_bind_text(stmt, 18, hex, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 18)
            }
        })
    }

    private static func decode(_ stmt: OpaquePointer?) -> ScannedAssetMetadata? {
        guard let stmt else { return nil }
        guard let idCString = sqlite3_column_text(stmt, 0) else { return nil }
        let localIdentifier = String(cString: idCString)
        let modificationDate = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1))
        let creationDate: Date? = sqlite3_column_type(stmt, 2) == SQLITE_NULL
            ? nil : Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2))
        let pixelWidth = Int(sqlite3_column_int64(stmt, 3))
        let pixelHeight = Int(sqlite3_column_int64(stmt, 4))
        let fileSizeBytes = sqlite3_column_int64(stmt, 5)
        let isFavorite = sqlite3_column_int(stmt, 6) != 0
        let hasAdjustments = sqlite3_column_int(stmt, 7) != 0
        let isScreenshot = sqlite3_column_int(stmt, 8) != 0
        let isVideo = sqlite3_column_int(stmt, 9) != 0
        let isLocallyAvailable = sqlite3_column_int(stmt, 10) != 0
        let burstIdentifier: String? = sqlite3_column_text(stmt, 11).map { String(cString: $0) }
        let albumNamesJSON: String = sqlite3_column_text(stmt, 12).map { String(cString: $0) } ?? "[]"
        let albumNames = (try? JSONDecoder().decode([String].self, from: Data(albumNamesJSON.utf8))) ?? []
        let latitude: Double? = sqlite3_column_type(stmt, 13) == SQLITE_NULL
            ? nil : sqlite3_column_double(stmt, 13)
        let longitude: Double? = sqlite3_column_type(stmt, 14) == SQLITE_NULL
            ? nil : sqlite3_column_double(stmt, 14)
        let perceptualHash: UInt64? = sqlite3_column_type(stmt, 15) == SQLITE_NULL
            ? nil : UInt64(bitPattern: sqlite3_column_int64(stmt, 15))
        let featurePrintData: Data? = {
            guard let blob = sqlite3_column_blob(stmt, 16) else { return nil }
            let count = Int(sqlite3_column_bytes(stmt, 16))
            guard count > 0 else { return nil }
            return Data(bytes: blob, count: count)
        }()
        let contentHashHex: String? = sqlite3_column_text(stmt, 17).map { String(cString: $0) }

        return ScannedAssetMetadata(
            localIdentifier: localIdentifier,
            modificationDate: modificationDate,
            creationDate: creationDate,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            fileSizeBytes: fileSizeBytes,
            isFavorite: isFavorite,
            hasAdjustments: hasAdjustments,
            isScreenshot: isScreenshot,
            isVideo: isVideo,
            isLocallyAvailable: isLocallyAvailable,
            burstIdentifier: burstIdentifier,
            albumNames: albumNames,
            latitude: latitude,
            longitude: longitude,
            perceptualHash: perceptualHash,
            featurePrintData: featurePrintData,
            contentHashHex: contentHashHex
        )
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
