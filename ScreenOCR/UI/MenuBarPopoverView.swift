import SwiftUI

/// Clip-style dropdown under the menu bar icon: recent clips + actions.
struct MenuBarPopoverView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var history: OCRHistoryManager
    var onClose: () -> Void

    @State private var confirmingClear = false

    private let rowLimit = 10
    private let clipboard = ClipboardManager()

    private var recent: [OCRHistoryEntry] {
        Array(history.entries.prefix(rowLimit))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if recent.isEmpty {
                ContentUnavailableView {
                    Label("No clips yet", systemImage: "doc.on.clipboard")
                } description: {
                    Text("Capture text or copy something in another app.")
                }
                .frame(height: 140)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(Array(recent.enumerated()), id: \.element.id) { index, entry in
                            clipRow(entry, index: index)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 300)
            }

            thinDivider

            actionsFooter
        }
        .frame(width: ScreenOCRDesign.popoverWidth)
        .background {
            RoundedRectangle(cornerRadius: ScreenOCRDesign.cornerRadius, style: .continuous)
                .fill(.thickMaterial)
                .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
        }
        .clipShape(RoundedRectangle(cornerRadius: ScreenOCRDesign.cornerRadius, style: .continuous))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image("MenuBarIcon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(ScreenOCRDesign.brandGradient)
                Text("Selectext")
                    .font(.headline)
            }
            Text("Select a clip to copy to your clipboard")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var thinDivider: some View {
        Divider().opacity(0.45)
    }

    private var actionsFooter: some View {
        VStack(spacing: 0) {
            actionRow("Capture Text…", icon: "viewfinder", shortcut: appModel.shortcutDisplay) {
                onClose()
                appModel.startRegionSelection()
            }

            thinDivider

            actionRow("Delete All History", icon: "trash", shortcut: nil, role: .destructive) {
                confirmingClear = true
            }
            .disabled(history.entries.isEmpty)
            .confirmationDialog("Delete all history?", isPresented: $confirmingClear) {
                Button("Delete All", role: .destructive) { history.clearAll() }
            } message: {
                Text("This removes every saved capture and copied text and can't be undone.")
            }

            actionRow("Preferences…", icon: "gearshape", shortcut: "⌘,") {
                onClose()
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }

            actionRow("Open Full Window…", icon: "macwindow", shortcut: nil) {
                onClose()
                appModel.showMainWindow(section: .clipboard)
            }

            actionRow("Getting Started", icon: "book", shortcut: nil) {
                onClose()
                appModel.showMainWindow(section: .gettingStarted)
            }

            thinDivider

            actionRow("Quit", icon: "power", shortcut: "⌘Q") {
                onClose()
                NSApp.terminate(nil)
            }
        }
        .padding(.bottom, 6)
    }

    private func clipRow(_ entry: OCRHistoryEntry, index: Int) -> some View {
        Button {
            _ = clipboard.copy(text: entry.text)
            onClose()
        } label: {
            HStack(alignment: .center, spacing: 10) {
                SourceBadge(source: entry.source)
                Text(entry.text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " "))
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if index < 10 {
                    Text("⌘\(index)")
                        .font(.caption2.monospacedDigit().weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.quaternary.opacity(0.9), in: RoundedRectangle(cornerRadius: 5))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(HoverRowButtonStyle())
        .keyboardShortcut(KeyEquivalent(Character(Unicode.Scalar(48 + index)!)), modifiers: .command)
    }

    private func actionRow(
        _ title: String,
        icon: String,
        shortcut: String?,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundStyle(role == .destructive ? Color.red : Color.secondary)
                    .frame(width: 18)
                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let shortcut {
                    Text(shortcut)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(HoverRowButtonStyle())
    }
}

/// Anchors the popover to the status bar button.
@MainActor
final class MenuBarPopoverController: NSObject, NSPopoverDelegate {
    static let shared = MenuBarPopoverController()

    private let popover = NSPopover()
    private var hosting: NSHostingController<AnyView>?

    private override init() {
        super.init()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
    }

    func toggle(from button: NSStatusBarButton, appModel: AppModel) {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        let view = MenuBarPopoverView(appModel: appModel, history: appModel.historyManager) { [weak self] in
            self?.popover.performClose(nil)
        }
        let host = NSHostingController(rootView: AnyView(view))
        host.sizingOptions = [.intrinsicContentSize]
        hosting = host
        popover.contentViewController = host
        popover.contentSize = NSSize(width: ScreenOCRDesign.popoverWidth, height: 460)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    func popoverDidClose(_ notification: Notification) {
        hosting = nil
        popover.contentViewController = nil
    }
}
