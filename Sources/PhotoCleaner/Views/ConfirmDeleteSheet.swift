import SwiftUI

struct ConfirmDeleteSheet: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let confirmation: AppViewModel.BatchConfirmation
    @State private var isDeleting = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "trash.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text("Delete \(confirmation.photoCount) Photos?")
                .font(.title2.bold())

            Text("This will move \(confirmation.photoCount) photos (\(Formatters.bytesString(confirmation.bytesToFree))) to Recently Deleted, matching the native Photos app. They can be recovered for about 30 days.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)

            HStack(spacing: 16) {
                Button("Cancel") { dismiss() }
                    .disabled(isDeleting)

                Button(role: .destructive) {
                    isDeleting = true
                    Task {
                        await viewModel.confirmAndDelete()
                        isDeleting = false
                        dismiss()
                    }
                } label: {
                    if isDeleting {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Delete Photos")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(isDeleting)
            }
        }
        .padding(32)
        .frame(width: 480)
    }
}
