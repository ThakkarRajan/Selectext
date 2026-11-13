import AppKit
import SwiftUI

enum MainWindowSection: String, CaseIterable, Identifiable {
    case clipboard
    case gettingStarted
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .clipboard: "Clipboard"
        case .gettingStarted: "Getting Started"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .clipboard: "doc.on.clipboard"
        case .gettingStarted: "questionmark.circle"
        case .settings: "gearshape"
        }
    }
}

/// The window shown when the user opens Selectext from Finder, Launchpad or Spotlight.
@MainActor
final class MainWindowController {
    static let shared = MainWindowController()

    private var window: NSWindow?

    private init() {}

    func present(appModel: AppModel, section: MainWindowSection) {
        appModel.mainWindowSection = section

        if let window, let host = window.contentViewController as? NSHostingController<MainWindowView> {
            host.rootView = MainWindowView(appModel: appModel)
            AuxiliaryWindowPresenter.shared.show(window)
            return
        }

        let window = AuxiliaryWindowPresenter.shared.makeWindow(
            title: "Selectext",
            size: NSSize(width: 820, height: 580)
        ) {
            MainWindowView(appModel: appModel)
        }
        self.window = window
        AuxiliaryWindowPresenter.shared.show(window)
    }
}

struct MainWindowView: View {
    @ObservedObject var appModel: AppModel

    private let sidebarWidth: CGFloat = 220

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: sidebarWidth)
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 720, minHeight: 520)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarHeader

            VStack(spacing: 4) {
                ForEach(MainWindowSection.allCases) { section in
                    sidebarRow(section)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)

            Spacer(minLength: 0)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var sidebarHeader: some View {
        HStack(spacing: 10) {
            Image("MenuBarIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundStyle(ScreenOCRDesign.brandGradient)
            VStack(alignment: .leading, spacing: 2) {
                Text("Selectext")
                    .font(.headline)
                Text(appModel.shortcutDisplay)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func sidebarRow(_ section: MainWindowSection) -> some View {
        let selected = appModel.mainWindowSection == section
        return Button {
            appModel.mainWindowSection = section
        } label: {
            Label(section.title, systemImage: section.systemImage)
                .font(.body.weight(selected ? .semibold : .regular))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    selected
                        ? ScreenOCRDesign.accent.opacity(0.18)
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var detail: some View {
        switch appModel.mainWindowSection {
        case .clipboard:
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Button {
                        appModel.startRegionSelection()
                    } label: {
                        Label("Capture Text", systemImage: "viewfinder")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ScreenOCRDesign.accent)
                    .controlSize(.large)
                    .disabled(appModel.isSelectingRegion)
                    Text("or press \(appModel.shortcutDisplay)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .screenOCRCard()
                .padding(.horizontal, 20)
                .padding(.top, 16)
                HistoryView(history: appModel.historyManager, title: "Clipboard History")
            }

        case .gettingStarted:
            WelcomeView(appModel: appModel) {
                appModel.mainWindowSection = .clipboard
            }

        case .settings:
            ScrollView {
                SettingsView(appModel: appModel)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
            }
        }
    }
}
