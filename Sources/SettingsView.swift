import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable, Hashable {
    case general = "General"
    case schedule = "Schedule"
    case detection = "Detection"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .schedule: return "calendar"
        case .detection: return "eye.fill"
        case .about: return "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .general: return .gray
        case .schedule: return .red
        case .detection: return .teal
        case .about: return .blue
        }
    }
}

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var engine: JiggleEngine
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 170)
            Divider()
            detail
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(width: 640, height: 460)
        .ignoresSafeArea(edges: .top)
    }

    // A plain, statically-laid-out sidebar. No NavigationSplitView, so there's
    // no adaptive collapsing logic that can misfire between tabs.
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 9) {
                        SettingsIcon(systemName: tab.icon, tint: tab.tint, size: 22)
                        Text(LocalizedStringKey(tab.rawValue))
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selectedTab == tab ? Color.accentColor.opacity(0.9) : Color.clear)
                    )
                    .foregroundColor(selectedTab == tab ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .padding(.top, 34) // fixed clearance for the traffic lights
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial)
    }

    private var detail: some View {
        Group {
            switch selectedTab {
            case .general: GeneralPane(store: store, engine: engine)
            case .schedule: SchedulePane(store: store)
            case .detection: DetectionPane(store: store)
            case .about: AboutPane()
            }
        }
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
