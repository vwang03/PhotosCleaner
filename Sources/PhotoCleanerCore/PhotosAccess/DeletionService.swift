import Foundation
import Photos

public enum DeletionError: Error, LocalizedError {
    case noMatchingAssets
    case changeFailed(underlying: Error?)

    public var errorDescription: String? {
        switch self {
        case .noMatchingAssets:
            return "None of the selected photos could be found in the library."
        case .changeFailed(let underlying):
            return "Failed to delete photos: \(underlying?.localizedDescription ?? "unknown error")."
        }
    }
}

/// Deletes assets via the standard Photos "move to Recently Deleted" flow (PRD 4.4).
/// There is no permanent-delete bypass — this always goes through
/// `PHAssetChangeRequest.deleteAssets`, which is exactly what the native Photos app's
/// delete button does, giving users the same ~30 day recovery window.
public struct DeletionService: Sendable {
    public init() {}

    /// Deletes the given assets and returns the total byte size of what was deleted,
    /// computed from their resources before the change request runs.
    @discardableResult
    public func deleteAssets(identifiers: [String]) async throws -> Int {
        guard !identifiers.isEmpty else { return 0 }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var assets: [PHAsset] = []
        assets.reserveCapacity(fetchResult.count)
        fetchResult.enumerateObjects { asset, _, _ in assets.append(asset) }

        guard !assets.isEmpty else { throw DeletionError.noMatchingAssets }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
            }, completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: DeletionError.changeFailed(underlying: error))
                }
            })
        }

        return assets.count
    }
}
