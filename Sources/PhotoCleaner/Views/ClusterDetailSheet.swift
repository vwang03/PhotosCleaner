import SwiftUI
import PhotoCleanerCore

struct ClusterDetailSheet: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let group: DuplicateGroup

    /// One photo at a time shown full size for judging a single candidate, or
    /// side-by-side thumbnails for comparing the whole group at a glance.
    enum Mode: String, CaseIterable, Identifiable {
        case fullPhoto = "Full Photo"
        case compare = "Compare"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .fullPhoto: return "arrow.up.left.and.arrow.down.right"
            case .compare: return "square.grid.2x2"
            }
        }
    }

    @State private var mode: Mode
    @State private var focusedAssetID: String?
    @State private var isDeleting = false

    init(group: DuplicateGroup, initialFocusedAssetID: String? = nil, initialMode: Mode = .fullPhoto) {
        self.group = group
        _mode = State(initialValue: initialMode)
        _focusedAssetID = State(
            initialValue: initialFocusedAssetID ?? Self.sorted(group.assets).first?.localIdentifier
        )
    }

    /// Largest-first, so the most likely keeper is the first thing the user sees in
    /// either mode.
    static func sorted(_ assets: [ScannedAssetMetadata]) -> [ScannedAssetMetadata] {
        assets.sorted(by: { $0.megapixels > $1.megapixels })
    }

    private var sortedAssets: [ScannedAssetMetadata] {
        Self.sorted(group.assets)
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 200), spacing: 16)]
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            switch mode {
            case .fullPhoto:
                FullPhotoReviewView(
                    group: group,
                    assets: sortedAssets,
                    focusedAssetID: $focusedAssetID
                )
                .environmentObject(viewModel)
            case .compare:
                compareGrid
            }
        }
        .frame(minWidth: 820, idealWidth: 1100, minHeight: 640, idealHeight: 820)
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Review Group")
                        .font(.title2.bold())
                    Text("\(group.assets.count) photos · \(Formatters.bytesString(group.totalBytes)) total · will free \(Formatters.bytesString(viewModel.reclaimableBytes(for: group)))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Select All") { viewModel.selectAll(groupID: group.id) }
                    .disabled(isDeleting)
                Button("Deselect All") { viewModel.keepAll(groupID: group.id) }
                    .disabled(isDeleting)
                doneButton
            }

            HStack {
                Picker("View", selection: $mode) {
                    ForEach(Mode.allCases) { option in
                        Label(option.rawValue, systemImage: option.systemImage)
                            .tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 260)

                Spacer()

                if mode == .fullPhoto {
                    Text("← → to switch photos · D to mark or keep · double-click to zoom")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }

    /// Finishing a group deletes what's marked in it, so the primary button states the
    /// count rather than a bare "Done" — "Close" is there to leave the marks pending
    /// for the toolbar's all-groups "Delete Selected" flow instead.
    @ViewBuilder
    private var doneButton: some View {
        let markedCount = viewModel.selectedCount(groupID: group.id)

        if markedCount > 0 {
            Button("Close") { dismiss() }
                .disabled(isDeleting)

            Button(role: .destructive) {
                deleteMarkedPhotosAndClose()
            } label: {
                if isDeleting {
                    ProgressView().controlSize(.small)
                } else {
                    Text(markedCount == 1 ? "Delete 1 Photo" : "Delete \(markedCount) Photos")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(isDeleting)
            .help("Move the \(markedCount) marked photos to Recently Deleted and close")
        } else {
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
    }

    private func deleteMarkedPhotosAndClose() {
        isDeleting = true
        Task {
            await viewModel.deleteMarkedPhotos(inGroupID: group.id)
            isDeleting = false
            dismiss()
        }
    }

    private var compareGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(sortedAssets) { asset in
                    detailCard(for: asset)
                }
            }
            .padding()
        }
    }

    private func detailCard(for asset: ScannedAssetMetadata) -> some View {
        let isSelected = viewModel.isSelectedForDeletion(groupID: group.id, assetID: asset.localIdentifier)

        return VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                AsyncThumbnailView(localIdentifier: asset.localIdentifier, targetSize: 200, highQuality: true)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.red : Color.clear, lineWidth: 3)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .opacity(isSelected ? 0.55 : 1.0)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.toggleSelection(groupID: group.id, assetID: asset.localIdentifier)
                    }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .red : .white)
                    .background(Circle().fill(.black.opacity(0.4)))
                    .padding(4)
                    .allowsHitTesting(false)

                Button {
                    showFullPhoto(asset)
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right.circle.fill")
                        .foregroundStyle(.white)
                        .background(Circle().fill(.black.opacity(0.4)))
                }
                .buttonStyle(.plain)
                .help("See this photo full size")
                .padding(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            HStack {
                Text(asset.resolutionDescription)
                Spacer()
                Text(Formatters.bytesString(asset.fileSizeBytes))
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                if asset.isFavorite {
                    Label("Favorite", systemImage: "heart.fill").foregroundStyle(.pink)
                }
                if asset.hasAdjustments {
                    Label("Edited", systemImage: "slider.horizontal.3")
                }
                if !asset.albumNames.isEmpty {
                    Label(asset.albumNames.joined(separator: ", "), systemImage: "folder")
                        .lineLimit(1)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            Text(isSelected ? "Marked for Deletion" : "Kept")
                .font(.caption)
                .foregroundStyle(isSelected ? .red : .secondary)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.08)))
    }

    private func showFullPhoto(_ asset: ScannedAssetMetadata) {
        focusedAssetID = asset.localIdentifier
        mode = .fullPhoto
    }
}
