import SwiftUI
import PhotoCleanerCore

struct ClusterCardView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let group: DuplicateGroup
    @State private var showingDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                badges
                Spacer()
                Text("\(group.assets.count) photos · \(Formatters.bytesString(group.totalBytes))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(group.assets) { asset in
                        thumbnail(for: asset)
                    }
                }
            }

            HStack {
                Text("Will free \(Formatters.bytesString(viewModel.reclaimableBytes(for: group)))")
                    .font(.callout)
                    .foregroundStyle(.tint)

                Spacer()

                Button("Select All") { viewModel.selectAll(groupID: group.id) }
                Button("Deselect All") { viewModel.keepAll(groupID: group.id) }
                Button("Skip") { viewModel.skipGroup(groupID: group.id) }
                Button("Review…") { showingDetail = true }
                    .buttonStyle(.borderedProminent)
            }
            .font(.callout)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.08)))
        .sheet(isPresented: $showingDetail) {
            ClusterDetailSheet(group: group)
                .environmentObject(viewModel)
        }
    }

    @ViewBuilder
    private var badges: some View {
        if group.isExactDuplicateGroup {
            Label("Exact Duplicate", systemImage: "equal.circle.fill")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(Color.red))
        } else {
            Label("Similar", systemImage: "sparkles")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(Color.orange))
        }
        if group.isBurst {
            Label("Burst", systemImage: "square.stack.3d.up")
                .font(.caption.bold())
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(Color.gray.opacity(0.3)))
        }
        Text("\(Int(group.confidence * 100))% confidence")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func thumbnail(for asset: ScannedAssetMetadata) -> some View {
        let isSelected = viewModel.isSelectedForDeletion(groupID: group.id, assetID: asset.localIdentifier)

        return ZStack(alignment: .topTrailing) {
            AsyncThumbnailView(localIdentifier: asset.localIdentifier, targetSize: 110)
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
        }
    }
}
