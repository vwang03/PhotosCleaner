import SwiftUI
import PhotoCleanerCore

struct ScanView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Divider()

            if viewModel.isScanning {
                progressView
            } else if viewModel.groups.isEmpty {
                emptyState
            } else {
                clusterList
            }
        }
        .sheet(item: $viewModel.pendingBatchConfirmation) { confirmation in
            ConfirmDeleteSheet(confirmation: confirmation)
                .environmentObject(viewModel)
        }
        .alert("Session Complete", isPresented: sessionSummaryBinding, presenting: viewModel.lastSessionSummary) { _ in
            Button("OK") {}
        } message: { summary in
            Text("Deleted \(summary.photosDeleted) photos, freeing \(Formatters.bytesString(summary.bytesFreed)). Space is fully reclaimed once Recently Deleted is emptied.")
        }
        .alert("Error", isPresented: errorBinding, presenting: viewModel.errorMessage) { _ in
            Button("OK") {}
        } message: { message in
            Text(message)
        }
    }

    private var sessionSummaryBinding: Binding<Bool> {
        Binding(get: { viewModel.lastSessionSummary != nil }, set: { if !$0 { viewModel.clearSessionSummary() } })
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })
    }

    private var toolbar: some View {
        HStack {
            if viewModel.isScanning {
                Button("Cancel Scan", role: .cancel) { viewModel.cancelScan() }
            } else {
                Button(viewModel.groups.isEmpty ? "Start Scan" : "Re-scan") {
                    viewModel.startScan()
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()

            if !viewModel.groups.isEmpty {
                Text("\(viewModel.visibleGroups.count) groups · \(viewModel.totalSelectedPhotoCount) selected · \(Formatters.bytesString(viewModel.totalReclaimableBytes)) to free")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Button("Delete Selected") {
                    viewModel.prepareManualDeleteConfirmation()
                }
                .disabled(viewModel.totalSelectedPhotoCount == 0)
            }
        }
        .padding()
    }

    private var progressView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView(value: viewModel.scanProgress.fractionComplete) {
                Text(viewModel.scanProgress.phase.rawValue)
            }
            .frame(maxWidth: 420)

            Text("\(viewModel.scanProgress.processedCount) / \(viewModel.scanProgress.totalCount) photos")
                .font(.callout)
                .foregroundStyle(.secondary)

            if let remaining = viewModel.scanProgress.estimatedSecondsRemaining, remaining > 1 {
                Text("About \(Int(remaining))s remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.seal")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No scan results yet")
                .font(.title3.bold())
            Text("Start a scan to find duplicate and similar photos in your library.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var clusterList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.visibleGroups) { group in
                    ClusterCardView(group: group)
                        .environmentObject(viewModel)
                }
            }
            .padding()
        }
    }
}
