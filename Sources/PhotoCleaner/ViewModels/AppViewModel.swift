import Foundation
import SwiftUI
import Photos
import PhotoCleanerCore

@MainActor
final class AppViewModel: ObservableObject {
    @Published var authorizationStatus: PhotoLibraryAuthorizationStatus = .notDetermined
    @Published var settings: ScanSettings {
        didSet { persistSettings() }
    }

    @Published private(set) var scanProgress: ScanProgress = .idle
    @Published private(set) var isScanning = false
    @Published var groups: [DuplicateGroup] = []
    @Published var deletionSelections: [String: Set<String>] = [:]
    @Published var skippedGroupIDs: Set<String> = []

    @Published var errorMessage: String?
    @Published var pendingBatchConfirmation: BatchConfirmation?
    @Published private(set) var totalBytesFreedAllTime: Int64 = 0
    @Published private(set) var totalPhotosDeletedAllTime: Int = 0
    @Published private(set) var sessionHistory: [SessionReport] = []
    @Published private(set) var lastSessionSummary: SessionSummary?

    struct BatchConfirmation: Identifiable {
        let id = UUID()
        let groupIDs: [String]
        let photoCount: Int
        let bytesToFree: Int64
    }

    struct SessionSummary: Identifiable {
        let id = UUID()
        let photosDeleted: Int
        let bytesFreed: Int64
    }

    private let authorizationService = PhotoLibraryAuthorizationService()
    private let deletionService = DeletionService()
    private let cacheStore: ScanCacheStore
    private let reportStore: ReportStore
    private var scanCoordinator: ScanCoordinator?
    private var activeScanTask: Task<Void, Never>?

    private static let settingsDefaultsKey = "PhotoCleaner.ScanSettings"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.settingsDefaultsKey),
           let decoded = try? JSONDecoder().decode(ScanSettings.self, from: data) {
            settings = decoded
        } else {
            settings = .default
        }

        do {
            cacheStore = try ScanCacheStore(path: ScanCacheStore.defaultStoreURL().path)
        } catch {
            fatalError("Failed to initialize scan cache store: \(error)")
        }
        do {
            reportStore = try ReportStore(path: ReportStore.defaultStoreURL().path)
        } catch {
            fatalError("Failed to initialize report store: \(error)")
        }

        authorizationStatus = authorizationService.currentStatus()
    }

    private func persistSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.settingsDefaultsKey)
        }
    }

    // MARK: - Authorization

    func refreshAuthorizationStatus() {
        authorizationStatus = authorizationService.currentStatus()
    }

    func requestAccess() async {
        let status = await authorizationService.requestAuthorization()
        authorizationStatus = status
    }

    // MARK: - History

    func loadHistory() async {
        do {
            sessionHistory = try await reportStore.allReports()
            totalBytesFreedAllTime = try await reportStore.totalBytesFreed()
            totalPhotosDeletedAllTime = try await reportStore.totalPhotosDeleted()
        } catch {
            errorMessage = "Failed to load history: \(error.localizedDescription)"
        }
    }

    // MARK: - Scanning

    func startScan() {
        guard !isScanning else { return }
        isScanning = true
        groups = []
        // No photo is selected for deletion by default — the user has complete
        // control over which specific photos, if any, get marked for deletion.
        deletionSelections = [:]
        skippedGroupIDs = []
        scanProgress = ScanProgress(phase: .enumeratingLibrary, startedAt: Date())

        let coordinator = ScanCoordinator(cacheStore: cacheStore)
        scanCoordinator = coordinator
        let currentSettings = settings

        activeScanTask = Task { [weak self] in
            let resultGroups = await coordinator.runScan(settings: currentSettings) { progress in
                Task { @MainActor in
                    self?.scanProgress = progress
                }
            }
            guard let self else { return }
            self.groups = resultGroups
            self.isScanning = false
        }
    }

    func cancelScan() {
        guard let scanCoordinator else { return }
        Task {
            await scanCoordinator.cancel()
        }
        activeScanTask?.cancel()
        isScanning = false
    }

    // MARK: - Selection controls

    func toggleSelection(groupID: String, assetID: String) {
        var current = deletionSelections[groupID] ?? []
        if current.contains(assetID) {
            current.remove(assetID)
        } else {
            current.insert(assetID)
        }
        deletionSelections[groupID] = current
    }

    func isSelectedForDeletion(groupID: String, assetID: String) -> Bool {
        deletionSelections[groupID]?.contains(assetID) ?? false
    }

    func selectedCount(groupID: String) -> Int {
        deletionSelections[groupID]?.count ?? 0
    }

    /// Selects every photo in the group for deletion. There's no protected "keeper" —
    /// the user has complete control and can freely deselect any of them afterward.
    func selectAll(groupID: String) {
        guard let group = groups.first(where: { $0.id == groupID }) else { return }
        deletionSelections[groupID] = Set(group.assets.map(\.localIdentifier))
    }

    func keepAll(groupID: String) {
        deletionSelections[groupID] = []
    }

    func clearSessionSummary() {
        lastSessionSummary = nil
    }

    func skipGroup(groupID: String) {
        skippedGroupIDs.insert(groupID)
    }

    func unskipGroup(groupID: String) {
        skippedGroupIDs.remove(groupID)
    }

    var visibleGroups: [DuplicateGroup] {
        groups.filter { !skippedGroupIDs.contains($0.id) }
    }

    func reclaimableBytes(for group: DuplicateGroup) -> Int64 {
        let selected = deletionSelections[group.id] ?? []
        return group.assets.filter { selected.contains($0.localIdentifier) }.reduce(0) { $0 + $1.fileSizeBytes }
    }

    var totalReclaimableBytes: Int64 {
        visibleGroups.reduce(0) { $0 + reclaimableBytes(for: $1) }
    }

    var totalSelectedPhotoCount: Int {
        visibleGroups.reduce(0) { $0 + (deletionSelections[$1.id]?.count ?? 0) }
    }

    /// Prepares the confirmation sheet for whatever is currently checked across all
    /// visible groups, regardless of confidence (manual "Delete Selected" flow).
    func prepareManualDeleteConfirmation() {
        let count = totalSelectedPhotoCount
        guard count > 0 else {
            errorMessage = "No photos are currently selected for deletion."
            return
        }
        pendingBatchConfirmation = BatchConfirmation(
            groupIDs: visibleGroups.map(\.id),
            photoCount: count,
            bytesToFree: totalReclaimableBytes
        )
    }

    // MARK: - Deletion (PRD 4.4)

    func confirmAndDelete() async {
        let identifiers = visibleGroups.flatMap { group -> [String] in
            Array(deletionSelections[group.id] ?? [])
        }
        await deletePhotos(identifiers: identifiers)
    }

    /// Deletes only the photos marked within a single group, for finishing one group at
    /// a time in the review sheet instead of batching every group together.
    func deleteMarkedPhotos(inGroupID groupID: String) async {
        await deletePhotos(identifiers: Array(deletionSelections[groupID] ?? []))
    }

    private func deletePhotos(identifiers: [String]) async {
        guard !identifiers.isEmpty else { return }

        do {
            let identifierSet = Set(identifiers)
            let bytesFreed = groups
                .flatMap(\.assets)
                .filter { identifierSet.contains($0.localIdentifier) }
                .reduce(Int64(0)) { $0 + $1.fileSizeBytes }

            let deletedCount = try await deletionService.deleteAssets(identifiers: identifiers)

            let report = SessionReport(photosDeleted: deletedCount, bytesFreed: bytesFreed)
            try await reportStore.record(report)

            removeDeletedAssets(identifiers: identifierSet)
            lastSessionSummary = SessionSummary(photosDeleted: deletedCount, bytesFreed: bytesFreed)
            await loadHistory()
        } catch {
            errorMessage = "Deletion failed: \(error.localizedDescription)"
        }
    }

    private func removeDeletedAssets(identifiers: Set<String>) {
        var newGroups: [DuplicateGroup] = []
        for var group in groups {
            group.assets.removeAll { identifiers.contains($0.localIdentifier) }
            if group.assets.count > 1 {
                newGroups.append(group)
                deletionSelections[group.id]?.subtract(identifiers)
            } else {
                deletionSelections[group.id] = nil
            }
        }
        groups = newGroups
    }
}
