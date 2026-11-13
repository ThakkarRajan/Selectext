import AppKit
import SwiftUI

/// Builds auxiliary windows once and reuses them. The Dock icon is shown while one is open
/// and removed again when the last one closes, so ScreenOCR stays a menu bar app.
@MainActor
final class AuxiliaryWindowPresenter: NSObject, NSWindowDelegate {
    static let shared = AuxiliaryWindowPresenter()

    private override init() {}

    func makeWindow<Content: View>(
        title: String,
        size: NSSize,
        resizable: Bool = true,
        @ViewBuilder content: () -> Content
    ) -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: content()))
        window.title = title
        window.styleMask = resizable
            ? [.titled, .closable, .miniaturizable, .resizable]
            : [.titled, .closable, .miniaturizable]
        window.setContentSize(size)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }

    func show(_ window: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        let closing = notification.object as? NSWindow
        DispatchQueue.main.async {
            let anotherWindowOpen = NSApp.windows.contains { window in
                window !== closing
                    && window.isVisible
                    && window.styleMask.contains(.titled)
                    && !(window is NSPanel)
            }
            if !anotherWindowOpen {
                MenuBarLaunchSupport.applyLaunchPolicy()
            }
        }
    }
}

@MainActor
final class FeatureWindowController {
    static let shared = FeatureWindowController()

    private var previewWindow: NSWindow?

    private init() {}

    func showPreview(appModel: AppModel) {
        appModel.previewDraftText = appModel.lastExtractedText
        let window = previewWindow ?? AuxiliaryWindowPresenter.shared.makeWindow(
            title: "Last Extraction",
            size: NSSize(width: 480, height: 320)
        ) {
            PreviewWindow(appModel: appModel) { [weak self] in
                self?.closePreview()
            }
            .frame(minWidth: 420, minHeight: 280)
        }
        previewWindow = window
        AuxiliaryWindowPresenter.shared.show(window)
    }

    func closePreview() {
        previewWindow?.close()
    }
}
