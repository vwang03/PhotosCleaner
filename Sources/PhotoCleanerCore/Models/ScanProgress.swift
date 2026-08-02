import Foundation

public enum ScanPhase: String, Sendable, Equatable {
    case idle
    case enumeratingLibrary = "Enumerating library"
    case fingerprinting = "Generating fingerprints"
    case clustering = "Clustering duplicates"
    case verifyingExactMatches = "Verifying exact matches"
    case completed = "Completed"
    case cancelled = "Cancelled"
    case failed = "Failed"
}

public struct ScanProgress: Equatable, Sendable {
    public var phase: ScanPhase
    public var processedCount: Int
    public var totalCount: Int
    public var startedAt: Date?
    public var estimatedSecondsRemaining: Double?
    public var errorDescription: String?

    public init(
        phase: ScanPhase = .idle,
        processedCount: Int = 0,
        totalCount: Int = 0,
        startedAt: Date? = nil,
        estimatedSecondsRemaining: Double? = nil,
        errorDescription: String? = nil
    ) {
        self.phase = phase
        self.processedCount = processedCount
        self.totalCount = totalCount
        self.startedAt = startedAt
        self.estimatedSecondsRemaining = estimatedSecondsRemaining
        self.errorDescription = errorDescription
    }

    public var fractionComplete: Double {
        guard totalCount > 0 else { return 0 }
        return min(1.0, Double(processedCount) / Double(totalCount))
    }

    public static let idle = ScanProgress()
}
