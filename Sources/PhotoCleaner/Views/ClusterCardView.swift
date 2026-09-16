import SwiftUI
import PhotoCleanerCore

struct ClusterCardView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let group: DuplicateGroup
    @State private var detailRequest: DetailRequest?

    /// Which photo (if any) the review sheet should open on, and in which mode.
    struct DetailRequest: Identifiable {
        let id = UUID()
        var assetID: String?
        var mode: ClusterDetailSheet.Mode = .fullPhoto
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                badges
                Spacer()
                Text("\(group.assets.count) photos · \(Formatters.bytesString(group.totalBytes))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            // Lets clicks fall through to the card background, so double-clicking the
            // group's header counts as double-clicking the section.
            .allowsHitTesting(false)

            ScrollView(.horizontal, showsIndicators: false) {
                // Lazy so a 50-photo group only builds the thumbnails on screen; the
                // eager version rebuilt every thumbnail in every group on each
                // selection change, which showed up as click latency.
                LazyHStack(spacing: 8) {
                    ForEach(group.assets) { asset in
                        thumbnail(for: asset)
                    }
                }
            }

            HStack {
                Text("Will free \(Formatters.bytesString(viewModel.reclaimableBytes(for: group)))")
                    .font(.callout)
                    .foregroundStyle(.tint)
                    .allowsHitTesting(false)

                Spacer()

                Button("Select All") { viewModel.selectAll(groupID: group.id) }
                Button("Deselect All") { viewModel.keepAll(groupID: group.id) }
                Button("Skip") { viewModel.skipGroup(groupID: group.id) }
                Button("Review…") { detailRequest = DetailRequest() }
                    .buttonStyle(.borderedProminent)
            }
            .font(.callout)
        }
        .padding(12)
        .background(cardBackground)
        .help("Double-click to review this group")
        .sheet(item: $detailRequest) { request in
            ClusterDetailSheet(
                group: group,
                initialFocusedAssetID: request.assetID,
                initialMode: request.mode
            )
            .environmentObject(viewModel)
        }
    }

    /// Double-click-to-review lives on the card's *background* rather than on the card
    /// itself. As an ancestor of the thumbnails, a card-level double-click gesture
    /// competes with their single-click gesture, which forces every mark-for-deletion
    /// click to wait out the system double-click interval before it registers.
    /// Hit-testing hands clicks to the topmost view instead, so thumbnails never see
    /// this gesture and stay instant.
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.08))
            .onTapGesture(count: 2) {
                detailRequest = DetailRequest()
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

            Button {
                detailRequest = DetailRequest(assetID: asset.localIdentifier)
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
        .help("Click to mark for deletion")
    }
}
