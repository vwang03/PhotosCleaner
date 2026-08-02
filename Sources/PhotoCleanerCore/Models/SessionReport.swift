import Foundation

/// A record of a single cleanup session's outcome, persisted for historical reporting.
public struct SessionReport: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let date: Date
    public let photosDeleted: Int
    public let bytesFreed: Int64

    public init(id: String = UUID().uuidString, date: Date = Date(), photosDeleted: Int, bytesFreed: Int64) {
        self.id = id
        self.date = date
        self.photosDeleted = photosDeleted
        self.bytesFreed = bytesFreed
    }
}
