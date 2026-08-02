import SwiftUI
import PhotoCleanerCore

struct SettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        Form {
            Section("Similarity Sensitivity") {
                Picker("Sensitivity", selection: $viewModel.settings.sensitivity) {
                    ForEach(SimilaritySensitivity.allCases) { sensitivity in
                        Text(sensitivity.displayName).tag(sensitivity)
                    }
                }
                .pickerStyle(.radioGroup)

                Text(sensitivityExplanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("What to Scan") {
                Toggle("Include Screenshots", isOn: $viewModel.settings.includeScreenshots)
                Toggle("Include Videos (exact duplicates only)", isOn: $viewModel.settings.includeVideos)
                Toggle("Include Hidden Album", isOn: $viewModel.settings.includeHiddenAlbum)
                Toggle("Include Favorites", isOn: $viewModel.settings.includeFavorites)
            }

            Section("iCloud Photos (Optimize Mac Storage)") {
                Picker("When a photo isn't downloaded locally", selection: $viewModel.settings.iCloudPolicy) {
                    ForEach(ICloudAssetPolicy.allCases) { policy in
                        Text(policy.displayName).tag(policy)
                    }
                }
                .pickerStyle(.radioGroup)

                Text(iCloudExplanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("All scanning and comparison happens on this Mac. No photo data ever leaves your device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 560)
        .padding()
    }

    private var sensitivityExplanation: String {
        switch viewModel.settings.sensitivity {
        case .strict:
            return "Only groups near-identical photos together. Fewer false positives, may miss some near-duplicates."
        case .moderate:
            return "Balanced default: catches most re-exports, re-compressions, and burst near-duplicates."
        case .loose:
            return "Groups broader scene-level similarity (e.g. whole bursts). Review suggestions carefully before batch-deleting."
        }
    }

    private var iCloudExplanation: String {
        switch viewModel.settings.iCloudPolicy {
        case .thumbnailOnly:
            return "Uses the small preview Photos already has cached locally. Never triggers a download; exact-duplicate byte comparison is skipped for these photos."
        case .skipNonLocal:
            return "Photos not already downloaded to this Mac are left out of the scan entirely."
        case .forceDownload:
            return "Downloads full-resolution originals as needed for the most accurate comparison. This can use significant bandwidth and temporary disk space for large libraries."
        }
    }
}
