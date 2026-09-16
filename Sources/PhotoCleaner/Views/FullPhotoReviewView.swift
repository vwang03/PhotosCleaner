import SwiftUI
import PhotoCleanerCore

/// Single-photo review mode for a duplicate group: shows one photo at a time, full
/// frame and uncropped, with zoom, keyboard navigation, per-photo metadata, and a
/// filmstrip for moving between the group's photos.
struct FullPhotoReviewView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let group: DuplicateGroup
    let assets: [ScannedAssetMetadata]
    @Binding var focusedAssetID: String?

    @State private var zoom: CGFloat = 1
    @State private var zoomAtGestureStart: CGFloat = 1

    private static let maxZoom: CGFloat = 6

    var body: some View {
        VStack(spacing: 0) {
            if let asset = focusedAsset {
                photoStage(for: asset)
                Divider()
                infoBar(for: asset)
            } else {
                Color.clear
            }
            Divider()
            filmstrip
        }
        .onChange(of: focusedAssetID) { _ in
            zoom = 1
            zoomAtGestureStart = 1
        }
    }

    // MARK: - Focus

    private var focusedIndex: Int {
        guard let focusedAssetID,
              let index = assets.firstIndex(where: { $0.localIdentifier == focusedAssetID }) else { return 0 }
        return index
    }

    private var focusedAsset: ScannedAssetMetadata? {
        assets.indices.contains(focusedIndex) ? assets[focusedIndex] : nil
    }

    private func focus(offset: Int) {
        guard !assets.isEmpty else { return }
        let next = (focusedIndex + offset + assets.count) % assets.count
        focusedAssetID = assets[next].localIdentifier
    }

    private func toggleFocusedSelection() {
        guard let focusedAssetID else { return }
        viewModel.toggleSelection(groupID: group.id, assetID: focusedAssetID)
    }

    // MARK: - Photo stage

    private func photoStage(for asset: ScannedAssetMetadata) -> some View {
        GeometryReader { proxy in
            let fit = fittedSize(for: asset, in: proxy.size)

            ScrollView([.horizontal, .vertical], showsIndicators: zoom > 1) {
                FullPhotoImageView(
                    localIdentifier: asset.localIdentifier,
                    maxPixelSize: pixelBudget(for: proxy.size)
                )
                .frame(width: fit.width * zoom, height: fit.height * zoom)
                // Centers the photo while it's smaller than the stage, and lets the
                // scroll view pan once zooming makes it larger.
                .frame(minWidth: proxy.size.width, minHeight: proxy.size.height)
                .onTapGesture(count: 2) {
                    zoom = zoom > 1 ? 1 : min(Self.maxZoom, actualPixelZoom(for: asset, fit: fit))
                }
            }
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        zoom = min(max(zoomAtGestureStart * value, 1), Self.maxZoom)
                    }
                    .onEnded { _ in zoomAtGestureStart = zoom }
            )
            .overlay(alignment: .leading) {
                stepButton(systemImage: "chevron.left", shortcut: .leftArrow, offset: -1)
                    .padding(.leading, 12)
            }
            .overlay(alignment: .trailing) {
                stepButton(systemImage: "chevron.right", shortcut: .rightArrow, offset: 1)
                    .padding(.trailing, 12)
            }
            .overlay(alignment: .topTrailing) {
                zoomControls(for: asset, fit: fit)
                    .padding(10)
            }
            .overlay(alignment: .topLeading) {
                Text("\(focusedIndex + 1) of \(assets.count)")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.black.opacity(0.55)))
                    .foregroundStyle(.white)
                    .padding(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.9))
    }

    private func stepButton(systemImage: String, shortcut: KeyEquivalent, offset: Int) -> some View {
        Button {
            focus(offset: offset)
        } label: {
            Image(systemName: systemImage)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .padding(10)
                .background(Circle().fill(.black.opacity(0.55)))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(shortcut, modifiers: [])
        .disabled(assets.count < 2)
        .opacity(assets.count < 2 ? 0 : 1)
        .help(offset < 0 ? "Previous photo (←)" : "Next photo (→)")
    }

    private func zoomControls(for asset: ScannedAssetMetadata, fit: CGSize) -> some View {
        HStack(spacing: 6) {
            Button {
                zoom = max(1, zoom - 0.5)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .disabled(zoom <= 1)

            Button(zoom > 1 ? String(format: "%.1f×", zoom) : "Fit") {
                zoom = zoom > 1 ? 1 : min(Self.maxZoom, actualPixelZoom(for: asset, fit: fit))
            }
            .frame(minWidth: 44)
            .help(zoom > 1 ? "Back to fit" : "Zoom to actual pixels")

            Button {
                zoom = min(Self.maxZoom, zoom + 0.5)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .disabled(zoom >= Self.maxZoom)
        }
        .font(.callout)
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.45)))
        .foregroundStyle(.white)
    }

    /// Zoom factor at which one image pixel maps to one screen point-pixel.
    private func actualPixelZoom(for asset: ScannedAssetMetadata, fit: CGSize) -> CGFloat {
        guard fit.width > 0, asset.pixelWidth > 0 else { return 2 }
        return max(1, CGFloat(asset.pixelWidth) / fit.width)
    }

    private func fittedSize(for asset: ScannedAssetMetadata, in container: CGSize) -> CGSize {
        guard asset.pixelWidth > 0, asset.pixelHeight > 0,
              container.width > 0, container.height > 0 else { return container }
        let aspect = CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
        if container.width / container.height > aspect {
            return CGSize(width: container.height * aspect, height: container.height)
        }
        return CGSize(width: container.width, height: container.width / aspect)
    }

    private func pixelBudget(for container: CGSize) -> CGFloat {
        let longestEdge = max(container.width, container.height) * 2 // retina
        let zoomAllowance = min(max(zoom, 1), 2)
        let quantized = ((longestEdge * zoomAllowance) / 256).rounded(.up) * 256
        return min(max(quantized, 512), 4096)
    }

    // MARK: - Info bar

    private func infoBar(for asset: ScannedAssetMetadata) -> some View {
        let isSelected = viewModel.isSelectedForDeletion(groupID: group.id, assetID: asset.localIdentifier)

        return HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(asset.resolutionDescription)
                        .font(.callout.bold())
                    Text(String(format: "%.1f MP", asset.megapixels))
                    Text(Formatters.bytesString(asset.fileSizeBytes))
                    if let creationDate = asset.creationDate {
                        Text(Formatters.dateAndTime.string(from: creationDate))
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)

                chips(for: asset)
            }

            Spacer()

            // The action must not capture `asset`: the key-equivalent registration for
            // this button can outlive the render it came from, so a captured value
            // would toggle whichever photo was focused back then. Resolving through
            // the binding reads whatever is focused at the moment the key is pressed.
            Button(isSelected ? "Keep This Photo" : "Mark for Deletion") {
                toggleFocusedSelection()
            }
            .buttonStyle(.borderedProminent)
            .tint(isSelected ? .green : .red)
            .keyboardShortcut(KeyEquivalent("d"), modifiers: [])
            .help(isSelected ? "Keep this photo (D)" : "Mark this photo for deletion (D)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func chips(for asset: ScannedAssetMetadata) -> some View {
        let isSelected = viewModel.isSelectedForDeletion(groupID: group.id, assetID: asset.localIdentifier)

        HStack(spacing: 6) {
            Text(isSelected ? "Marked for Deletion" : "Kept")
                .foregroundStyle(isSelected ? .red : .green)
            if isHighestResolution(asset) {
                Label("Highest resolution", systemImage: "arrow.up.right.square")
            }
            if isLargestFile(asset) {
                Label("Largest file", systemImage: "internaldrive")
            }
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
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func isHighestResolution(_ asset: ScannedAssetMetadata) -> Bool {
        guard assets.count > 1, let best = assets.map(\.megapixels).max() else { return false }
        return asset.megapixels >= best
    }

    private func isLargestFile(_ asset: ScannedAssetMetadata) -> Bool {
        guard assets.count > 1, let biggest = assets.map(\.fileSizeBytes).max() else { return false }
        return asset.fileSizeBytes >= biggest
    }

    // MARK: - Filmstrip

    private var filmstrip: some View {
        ScrollViewReader { scroller in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(assets) { asset in
                        filmstripItem(for: asset)
                            .id(asset.localIdentifier)
                    }
                }
                .padding(10)
            }
            .onChange(of: focusedAssetID) { newValue in
                guard let newValue else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    scroller.scrollTo(newValue, anchor: .center)
                }
            }
        }
        .frame(height: 96)
    }

    private func filmstripItem(for asset: ScannedAssetMetadata) -> some View {
        let isFocused = asset.localIdentifier == focusedAssetID
        let isSelected = viewModel.isSelectedForDeletion(groupID: group.id, assetID: asset.localIdentifier)

        return ZStack(alignment: .topTrailing) {
            AsyncThumbnailView(localIdentifier: asset.localIdentifier, targetSize: 68, highQuality: false)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .opacity(isSelected ? 0.55 : 1.0)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.red : Color.clear, lineWidth: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 3)
                )

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.red)
                    .background(Circle().fill(.black.opacity(0.4)))
                    .padding(3)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            focusedAssetID = asset.localIdentifier
        }
        .help("Show this photo full size")
    }
}
