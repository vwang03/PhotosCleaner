import SwiftUI
import PhotoCleanerCore

struct RootView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    enum Section: String, CaseIterable, Identifiable {
        case scan = "Scan & Review"
        case settings = "Settings"
        case history = "History"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .scan: return "photo.on.rectangle.angled"
            case .settings: return "gearshape"
            case .history: return "clock.arrow.circlepath"
            }
        }
    }

    @State private var selection: Section? = .scan

    var body: some View {
        Group {
            if viewModel.authorizationStatus.canProceed {
                NavigationSplitView {
                    List(Section.allCases, selection: $selection) { section in
                        Label(section.rawValue, systemImage: section.systemImage)
                            .tag(section)
                    }
                    .navigationSplitViewColumnWidth(min: 180, ideal: 200)
                } detail: {
                    switch selection ?? .scan {
                    case .scan: ScanView()
                    case .settings: SettingsView()
                    case .history: HistoryView()
                    }
                }
            } else {
                PermissionView()
            }
        }
        .onAppear {
            viewModel.refreshAuthorizationStatus()
        }
    }
}
