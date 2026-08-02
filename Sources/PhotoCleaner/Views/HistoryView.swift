import SwiftUI
import PhotoCleanerCore

struct HistoryView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 40) {
                statCard(title: "Total Space Reclaimed", value: Formatters.bytesString(viewModel.totalBytesFreedAllTime))
                statCard(title: "Total Photos Deleted", value: "\(viewModel.totalPhotosDeletedAllTime)")
            }

            Text("Space is fully reclaimed once Recently Deleted is emptied — by the system after about 30 days, or manually in the Photos app.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Text("Session History")
                .font(.headline)

            if viewModel.sessionHistory.isEmpty {
                Text("No cleanup sessions yet.")
                    .foregroundStyle(.secondary)
            } else {
                Table(viewModel.sessionHistory) {
                    TableColumn("Date") { report in
                        Text(Formatters.dateAndTime.string(from: report.date))
                    }
                    TableColumn("Photos Deleted") { report in
                        Text("\(report.photosDeleted)")
                    }
                    TableColumn("Space Freed") { report in
                        Text(Formatters.bytesString(report.bytesFreed))
                    }
                }
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await viewModel.loadHistory()
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
    }
}
