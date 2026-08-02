import Foundation
import Photos

public enum PhotoLibraryAuthorizationStatus: Sendable, Equatable {
    case notDetermined
    case restricted
    case denied
    case authorized
    case limited

    public var canProceed: Bool {
        self == .authorized || self == .limited
    }
}

/// Thin wrapper around `PHPhotoLibrary` authorization so the rest of the app never
/// touches `PHAuthorizationStatus` directly (keeps call sites simple and testable).
public struct PhotoLibraryAuthorizationService: Sendable {
    public init() {}

    public func currentStatus() -> PhotoLibraryAuthorizationStatus {
        Self.map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    @discardableResult
    public func requestAuthorization() async -> PhotoLibraryAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: Self.map(status))
            }
        }
    }

    private static func map(_ status: PHAuthorizationStatus) -> PhotoLibraryAuthorizationStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized: return .authorized
        case .limited: return .limited
        @unknown default: return .denied
        }
    }
}
