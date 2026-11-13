import AppKit

/// App-level alert (not tied to the menu bar panel) so it also appears for ⌘⇧T captures.
@MainActor
enum ScreenCapturePermissionAlert {
    static func present() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Allow Screen Recording"
        alert.informativeText = """
        Selectext needs Screen Recording to read the region you select. Text is recognized \
        on your Mac and never uploaded.

        Turn on Selectext in System Settings → Privacy & Security → Screen Recording. \
        If it is already on, quit and reopen Selectext.
        """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit & Reopen")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            ScreenCaptureAccess.openSystemSettings()
        case .alertSecondButtonReturn:
            ScreenCaptureAccess.relaunchApp()
        default:
            break
        }
    }
}
