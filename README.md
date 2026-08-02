# PhotoCleaner

A native macOS app that scans your Photos library for exact and visually-similar
duplicate photos, lets you review them in clusters, and deletes unwanted copies to
Recently Deleted (recoverable for ~30 days) to reclaim disk space. Implements the
requirements in `PhotoCleaner_PRD.md`.

## Project layout

This is a Swift Package with two targets plus tests, rather than a `.xcodeproj`, so
everything can be built/tested from the command line:

```
Sources/
  PhotoCleanerCore/        Library: all business logic, Photos/Vision access, persistence
    Models/                ScanSettings, ScannedAssetMetadata, DuplicateGroup, ScanProgress, SessionReport
    Hashing/               Perceptual hash (dHash), SHA-256 content hash, feature-print math
    Clustering/            Union-Find + DuplicateClusterBuilder
    Heuristics/            KeeperHeuristic ("best" photo suggestion)
    Persistence/           SQLite-backed ScanCacheStore (incremental re-scans) + ReportStore (history)
    PhotosAccess/          PHPhotoLibrary authorization, asset enumeration, thumbnails, Vision
                           feature prints, deletion
    Scanning/              ScanCoordinator — orchestrates a full background scan
  PhotoCleaner/            Executable: SwiftUI app (views, view model)
Tests/
  PhotoCleanerCoreTests/   Unit tests for everything in PhotoCleanerCore (no Photos
                           access required — these run in CI / sandboxes)
Packaging/
  Info.plist               App bundle Info.plist (incl. NSPhotoLibraryUsageDescription)
  PhotoCleaner.entitlements
  build_app.sh             Assembles + ad-hoc signs a runnable PhotoCleaner.app
```

### Why a Swift Package instead of an .xcodeproj?

It lets the whole app — including the SwiftUI executable — be built, tested, and
packaged into a real, launchable `.app` bundle entirely from the terminal, which is
what made it possible to iterate and verify this build incrementally. It also builds
fine if you open `Package.swift` directly in Xcode.

## Building & testing

```bash
swift build          # build library + app
swift test           # run the unit test suite (39 tests, no Photos permission needed)
```

## Running the app

`swift run` alone won't get a working Photos permission prompt (bare SwiftPM
executables don't have a real `Info.plist`), so use the packaging script, which
builds, assembles a proper `.app` bundle, and ad-hoc code-signs it:

```bash
Packaging/build_app.sh debug      # or `release`
open .build/PhotoCleaner.app
```

The first launch will show a "Grant access" screen; clicking through it triggers the
real macOS Photos permission dialog (this requires a human to click "Allow" — it
can't be scripted, by design).

## Feature coverage vs. the PRD

- **Access & scanning (4.1–4.2)**: `PhotoLibraryAuthorizationService`, `AssetCatalog`,
  `ScanCoordinator`. Exact duplicates via SHA-256 content hashing; near-duplicates via
  dHash perceptual hashing pre-filter + Vision `VNGenerateImageFeaturePrintRequest`
  confirmation. Results are cached in SQLite (`ScanCacheStore`) keyed by asset ID +
  modification date so re-scans skip unchanged photos. Progress is reported
  incrementally via a callback so the UI never blocks.
- **Review & selection UI (4.3)**: `ScanView` / `ClusterCardView` /
  `ClusterDetailSheet` show grouped clusters with thumbnails, resolution, file size,
  favorite/edited/album badges, a heuristic "keeper" suggestion (`KeeperHeuristic`,
  overridable), full-size zoom preview, and selection controls (individual checkboxes,
  "select all but best," "keep all," "skip group"). Batch "keep best, delete rest" is
  gated by a confidence threshold with a confirmation step before committing
  (`ConfirmDeleteSheet`).
- **Deletion (4.4)**: `DeletionService` uses `PHAssetChangeRequest.deleteAssets`
  exclusively — the same path the native Photos app uses for "Recently Deleted."
  There is no permanent-delete bypass.
- **Reporting (4.5)**: `HistoryView` + `ReportStore` show both the current session's
  summary and the all-time total across sessions.
- **Settings (4.6)**: sensitivity (Strict/Moderate/Loose), include/exclude
  Screenshots/Videos/Hidden/Favorites, and an iCloud "Optimize Mac Storage" policy
  (thumbnail-only / skip non-local / force download) are all wired end-to-end into the
  scan.
- **Burst/Live Photo safety net**: groups where every asset shares a burst identifier
  are flagged (`DuplicateGroup.isBurst`) and excluded from confidence-gated batch
  auto-apply, per the PRD's callout about not encouraging deletion of intentionally
  paired assets.

## Known limitations / what would come next

- **Clustering is O(n²)** over perceptual hashes (a 64-bit XOR + popcount per pair),
  which is fast in absolute terms but would benefit from LSH banding for 50k+ photo
  libraries, per the PRD's "Beta: performance tuning for large libraries" milestone.
- **Album name lookup** does one `PHAssetCollection` fetch per asset, which is
  correctness-first rather than optimized; worth batching for very large libraries.
- **End-to-end testing of the Photos permission grant, a real scan against your
  library, and the delete flow all require interacting with live system dialogs and
  your actual photo library**, which isn't something that can be safely scripted from
  here. What *was* verified in this environment:
  - All 39 unit tests pass (`swift test`), covering perceptual hashing, content
    hashing, clustering, keeper heuristics, and both SQLite-backed stores.
  - The full app builds cleanly with zero warnings and packages into a signed,
    launchable `.app`.
  - The packaged app was launched and confirmed to render its window and run
    without crashing or logging errors, then shut down cleanly.
  - **Not yet exercised**: granting real Photos access, scanning a real library, and
    performing a real delete. Please launch `.build/PhotoCleaner.app` yourself,
    grant access when prompted, and try a scan — from there everything is driven by
    the UI described above.
