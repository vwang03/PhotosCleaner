import SwiftUI
import PhotoCleanerCore

struct ClusterDetailSheet: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let group: DuplicateGroup

    @State private var focusedAssetID: String?

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 200), spacing: 16)]
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if let focusedAssetID, let focusedAsset = group.assets.first(where: { $0.localIdentifier == focusedAssetID }) {
                zoomedPreview(for: focusedAsset)
            }

            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(group.assets.sorted(by: { $0.megapixels > $1.megapixels })) { asset in
                        detailCard(for: asset)
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 720, minHeight: 560)
    }

    private var header: some View {
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
            Button("Deselect All") { viewModel.keepAll(groupID: group.id) }
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func zoomedPreview(for asset: ScannedAssetMetadata) -> some View {
        AsyncThumbnailView(localIdentifier: asset.localIdentifier, targetSize: 900, highQuality: true, allowNetworkAccess: true)
            .frame(height: 300)
            .padding(.vertical, 8)
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
                    focusedAssetID = asset.localIdentifier
                } label: {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .foregroundStyle(.white)
                        .background(Circle().fill(.black.opacity(0.4)))
                }
                .buttonStyle(.plain)
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
}
