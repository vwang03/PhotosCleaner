import SwiftUI
import AppKit
import PhotoCleanerCore

struct PermissionView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.stack")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("PhotoCleaner needs access to your Photos library")
                .font(.title2)
                .fontWeight(.semibold)

            Text("PhotoCleaner scans your library on-device to find duplicate and similar photos. Nothing is uploaded anywhere, and deleted photos always go to Recently Deleted so you can recover them for about 30 days.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            statusMessage

            Button(action: requestAccess) {
                if isRequesting {
                    ProgressView().controlSize(.small)
                } else {
                    Text(buttonTitle)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRequesting || viewModel.authorizationStatus == .restricted)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var buttonTitle: String {
        switch viewModel.authorizationStatus {
        case .denied: return "Open System Settings"
        case .restricted: return "Access Restricted"
        default: return "Grant Access"
        }
    }

    @ViewBuilder
    private var statusMessage: some View {
        switch viewModel.authorizationStatus {
        case .denied:
            Text("Access was previously denied. Please enable Photos access for PhotoCleaner in System Settings → Privacy & Security → Photos.")
                .font(.callout)
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)
        case .restricted:
            Text("Photos access is restricted on this Mac (e.g. by parental controls or a management profile).")
                .font(.callout)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        case .limited:
            Text("PhotoCleaner currently has limited access. For best results, grant access to your full library.")
                .font(.callout)
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)
        default:
            EmptyView()
        }
    }

    private func requestAccess() {
        if viewModel.authorizationStatus == .denied {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos") {
                NSWorkspace.shared.open(url)
            }
            return
        }
        isRequesting = true
        Task {
            await viewModel.requestAccess()
            isRequesting = false
        }
    }
}
