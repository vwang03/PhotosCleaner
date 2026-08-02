# Product Requirements Document: PhotoCleaner (working title)

## 1. Overview

### 1.1 Summary
PhotoCleaner is a native macOS application that scans a user's Photos library, identifies duplicate and visually similar photos, and provides an interface for reviewing and deleting unwanted copies to reclaim disk space.

### 1.2 Problem Statement
Users accumulate large numbers of duplicate and near-duplicate photos over time — burst shots, re-imports, edited versions, screenshots taken multiple times, AirDrop re-sends, etc. The built-in Photos app has limited native duplicate detection (basic exact-duplicate merging only, introduced in recent macOS versions) and no tool for finding *visually similar* (not byte-identical) photos. This leads to wasted local and iCloud storage.

### 1.3 Goals
- Automatically detect exact and visually similar duplicate photos in a user's Photos library.
- Present duplicates in clear, reviewable groups.
- Let users quickly select and delete unwanted photos, safely (via Photos' "Recently Deleted," not permanent deletion).
- Report estimated and actual storage space reclaimed.

### 1.4 Non-Goals
- This is not a general-purpose photo manager, editor, or organizer.
- Not intended to modify, tag, or reorganize albums.
- Not responsible for iCloud storage management directly (only reflects the effect of deletions made through the app).
- No cross-device sync features in v1 — this is a single-Mac, local tool.

---

## 2. Target Users
- Mac users with large Photos libraries (thousands+ images) who feel their library or iCloud storage is bloated.
- Users comfortable granting a third-party app access to their Photos library.
- Not targeting professional photographers/DAM workflows in v1 (no RAW-specific handling, no versioning tools).

---

## 3. User Stories
1. As a user, I want to scan my Photos library so I can see how many duplicate/similar photos I have and how much space they take up.
2. As a user, I want to review groups of similar photos side-by-side so I can decide which to keep.
3. As a user, I want the app to suggest which photo in a group is the "best" (highest resolution, no blur, etc.) so I can delete faster.
4. As a user, I want batch actions ("keep best, delete rest") so I don't have to manually review every single group.
5. As a user, I want deleted photos to go to "Recently Deleted" (matching Photos app default behavior) so I have a safety net.
6. As a user, I want to see how much space I've saved after cleanup.
7. As a user, I want the scan to run in the background/incrementally so I'm not stuck waiting on a frozen UI for a large library.

---

## 4. Functional Requirements

### 4.1 Photos Library Access
- Request read/write access to the Photos library via `PHPhotoLibrary` authorization.
- Support libraries using iCloud Photos, including "Optimize Mac Storage" mode (see Open Questions on handling non-local originals).

### 4.2 Scanning & Duplicate Detection
- **Exact duplicates**: detect via content hash (e.g., SHA-256 of asset data) or matching `PHAsset` resource checksums.
- **Near-duplicates / visually similar**: generate perceptual fingerprints (perceptual hash and/or Vision framework `VNGenerateImageFeaturePrintRequest`) for each photo and cluster photos within a configurable similarity threshold.
- Support adjustable sensitivity (e.g., "Strict" = near-identical only, "Loose" = broader similarity like same scene/burst).
- Cache scan results locally (e.g., SQLite/Core Data) keyed by asset ID + modification date, so re-scans are incremental, not full re-processes.
- Display scan progress (photos processed / total, estimated time remaining).

### 4.3 Review & Selection UI
- Group duplicates into clusters, displayed as a grid or stack.
- For each cluster, show: thumbnail previews, resolution, file size, date taken, and (if available) which is favorited/edited/in an album.
- Auto-suggest a "keeper" per group based on heuristics (resolution, file size, EXIF completeness, favorite status) — user can override.
- Support single-photo full-size preview / zoom comparison within a cluster.
- Selection controls: individual checkboxes, "select all but best," "keep all," "skip group."
- Batch mode: apply "keep best, delete rest" across all clusters above a confidence threshold, with a review step before committing.

### 4.4 Deletion
- Deletions go through `PHPhotoLibrary.performChanges` / `PHAssetChangeRequest.deleteAssets`, sending items to "Recently Deleted" (consistent with native Photos behavior — recoverable for ~30 days).
- Show a confirmation summary before committing a batch delete (count of photos, estimated space freed).
- No in-app "permanent delete" bypass in v1 — permanent deletion remains the responsibility of the native Photos app / Recently Deleted flow.

### 4.5 Reporting
- Post-cleanup summary: number of photos deleted, estimated space freed.
- Persistent/historical view: total space saved across all sessions.

### 4.6 Settings
- Similarity sensitivity control.
- Include/exclude Screenshots, Videos, Hidden album, Favorites from scanning.
- Option to skip photos not yet downloaded locally (iCloud-optimized libraries) or force-download for scanning (with user warning about bandwidth/storage impact).

---

## 5. Non-Functional Requirements
- **Performance**: initial scan of a 20,000-photo library should complete in a reasonable background timeframe (target benchmark TBD after prototyping) without blocking the UI.
- **Safety**: no destructive action without explicit user confirmation; no permanent deletion in v1.
- **Privacy**: all processing happens on-device; no photo data leaves the Mac.
- **Reliability**: scan/cache state must survive app restarts and handle interruptions gracefully (e.g., app quit mid-scan).
- **Platform**: native macOS app (SwiftUI/AppKit), macOS 13+ target (TBD based on Vision/Photos API availability requirements).

---

## 6. Technical Approach (High-Level)
- **Language/Framework**: Swift, SwiftUI (with AppKit where needed for finer control).
- **Photo access**: `Photos` framework (`PHPhotoLibrary`, `PHAsset`, `PHAssetResource`).
- **Similarity detection**: `Vision` framework (`VNGenerateImageFeaturePrintRequest`) and/or custom perceptual hashing (pHash/dHash) for speed; feature-print comparison for higher-accuracy clustering.
- **Local storage**: Core Data or SQLite for caching fingerprints/scan state per asset.
- **Concurrency**: background queues (e.g., `Task`/`OperationQueue`) for scanning so the UI remains responsive; incremental/batched processing with progress callbacks.

---

## 7. Permissions & Entitlements
- `NSPhotoLibraryUsageDescription` in `Info.plist`.
- Photos library read/write entitlement.
- If distributed via Mac App Store: App Sandbox compliance and the appropriate Photos entitlement; note potential App Review scrutiny around deletion functionality.

---

## 8. Risks & Open Questions
| Risk / Question | Notes |
|---|---|
| iCloud "Optimize Mac Storage" libraries | Full-res originals may not be local; fetching for hashing could trigger downloads, consuming bandwidth/temporary storage. Need a strategy: thumbnail-only hashing vs. forced download vs. user opt-in. |
| Similarity threshold tuning | Risk of false positives (distinct but similar photos grouped) or false negatives (missed near-duplicates). Needs testing against real libraries and a tunable sensitivity setting. |
| Performance at scale | Large libraries (50k+ photos) may require significant processing time; need to validate feasible approach (feature-print generation cost) early via prototyping. |
| App Store approval | Photo-deletion apps face extra scrutiny; may need to evaluate direct distribution (notarized, outside App Store) as an alternative. |
| Burst photos / Live Photos / RAW+JPEG pairs | These may be flagged as "duplicates" but are often intentionally kept together — needs special-case handling so the app doesn't encourage deleting paired assets incorrectly. |
| Recently Deleted grace period | Since deletions aren't permanent, "space saved" reporting should clarify space is reclaimed once Recently Deleted is emptied (by system, after ~30 days, or manually). |

---

## 9. Success Metrics (v1)
- % of scanned libraries where the app successfully identifies duplicate clusters with acceptable accuracy (measured via user feedback / manual spot-check during beta).
- Average space reclaimed per user session.
- Scan completion time for libraries of representative sizes (5k / 20k / 50k photos).
- Crash-free session rate.

---

## 10. Milestones (Suggested)
1. **Prototype**: Photos framework access + basic exact-duplicate (hash) detection, no UI polish.
2. **MVP**: Add perceptual similarity clustering, review UI, deletion flow, Recently Deleted integration.
3. **Beta**: Incremental caching, performance tuning for large libraries, iCloud-optimized-library handling.
4. **v1 Release**: Polished UI, settings, reporting, distribution decision (App Store vs. direct/notarized).

---

## 11. Out of Scope for v1
- iOS/iPadOS companion app.
- Cloud-based processing or sync across devices.
- Video duplicate detection (only photos in v1; videos may be excluded or handled in a future version).
- Editing, tagging, or album management features.
