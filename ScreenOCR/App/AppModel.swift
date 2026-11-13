import AppKit
import Combine
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var lastExtractedText: String = ""
    @Published var previewDraftText: String = ""
    @Published var isSelectingRegion = false
    @Published var statusMessage: String?
    /// Increments after each capture whose text reached the clipboard.
    @Published private(set) var captureCount = 0
    @Published private(set) var shortcutDisplay = ShortcutManager.displayString
    @Published var mainWindowSection: MainWindowSection = .clipboard
    @Published private(set) var screenCaptureGranted = ScreenCaptureAccess.hasWorkingAccess()

    @Published var saveCopiedText = UserDefaults.standard.object(forKey: "saveCopiedText") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(saveCopiedText, forKey: "saveCopiedText")
            updateClipboardMonitor()
        }
    }

    @AppStorage("showPreviewAfterCapture") var showPreviewAfterCapture = false
    @AppStorage("recognitionLanguages") private var recognitionLanguagesStorage = "en-US"

    let historyManager = OCRHistoryManager()
    private let clipboardManager = ClipboardManager()
    private let notificationManager = NotificationManager()
    private let regionSelectionManager = RegionSelectionManager()
    private lazy var clipboardMonitor = ClipboardMonitor { [weak self] text in
        self?.historyManager.add(text: text, source: .copied)
    }

    var recognitionLanguages: [String] {
        get {
            recognitionLanguagesStorage
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        set {
            recognitionLanguagesStorage = newValue.joined(separator: ",")
        }
    }

    init() {
        AppModelRef.current = self
        ShortcutManager.shared.configure(appModel: self)
        updateClipboardMonitor()
        scheduleLaunchPresentation()
    }

    private func updateClipboardMonitor() {
        if saveCopiedText {
            clipboardMonitor.start()
        } else {
            clipboardMonitor.stop()
        }
    }

    func showMainWindow(section: MainWindowSection = .clipboard) {
        MainWindowController.shared.present(appModel: self, section: section)
    }

    func showGettingStarted() {
        showMainWindow(section: .gettingStarted)
    }

    func showPreviewWindow() {
        FeatureWindowController.shared.showPreview(appModel: self)
    }

    func presentMainUIOnLaunch() {
        let completedWelcome = UserDefaults.standard.bool(forKey: "hasCompletedWelcome")
        showMainWindow(section: completedWelcome ? .clipboard : .gettingStarted)
    }

    /// Finder, Launchpad, Spotlight, and Dock send a reopen Apple event when the user opens the app.
    func presentMainUIOnLaunchIfNeeded() {
        guard !LaunchSessionState.didPresentMainWindowThisSession else { return }
        LaunchSessionState.didPresentMainWindowThisSession = true
        presentMainUIOnLaunch()
    }

    func openMainWindowFromExternalLaunch() {
        showMainWindow()
    }

    private func scheduleLaunchPresentation() {
        Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(150))
                presentMainUIOnLaunchIfNeeded()
                let completedWelcome = UserDefaults.standard.bool(forKey: "hasCompletedWelcome")
                if !completedWelcome, !LaunchSessionState.hasShownReadyNotice {
                    LaunchSessionState.hasShownReadyNotice = true
                    notificationManager.showAppReady(shortcut: ShortcutManager.displayString)
                }
            } catch {
                reportUnexpected(error, context: "launch presentation")
            }
        }
    }

    func refreshShortcutDisplay() {
        shortcutDisplay = ShortcutManager.displayString
    }

    func notifyWelcomeCompleted() {
        notificationManager.showWelcomeCompleted(shortcut: ShortcutManager.displayString)
    }

    func beginCaptureFromShortcut() {
        guard !isSelectingRegion else { return }
        startRegionSelection()
    }

    func startRegionSelection() {
        guard !isSelectingRegion else { return }

        guard ensureScreenCaptureAccess() else { return }
        beginRegionSelectionOverlay()
    }

    /// Never shows the overlay without access: it sits above the system prompt and the
    /// capture would only contain the wallpaper.
    @discardableResult
    func ensureScreenCaptureAccess() -> Bool {
        syncPermissionsAfterSystemChange()
        if screenCaptureGranted { return true }

        if !ScreenCaptureAccess.hasRequestedSystemPrompt {
            // First time ever: let macOS show its own prompt, no custom dialog on top.
            let granted = ScreenCaptureAccess.requestSystemPrompt()
            syncPermissionsAfterSystemChange()
            return granted
        }

        ScreenCapturePermissionAlert.present()
        return false
    }

    func syncPermissionsAfterSystemChange() {
        let granted = ScreenCaptureAccess.hasWorkingAccess()
        if granted != screenCaptureGranted {
            screenCaptureGranted = granted
        }
    }

    private func beginRegionSelectionOverlay() {
        guard !isSelectingRegion else { return }
        isSelectingRegion = true

        regionSelectionManager.begin { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                defer { self.isSelectingRegion = false }

                switch result {
                case .cancelled:
                    break
                case .failure(let error):
                    self.reportUserError(title: "Capture Failed", error: error)
                case .success(let rect):
                    await self.processCapture(in: rect)
                }
            }
        }
    }

    private func processCapture(in rect: CGRect) async {
        do {
            guard rect.width >= 2, rect.height >= 2 else {
                reportUserError(title: "Selection Too Small", message: "Drag a larger region and try again.")
                return
            }

            guard rect.origin.x.isFinite, rect.origin.y.isFinite, rect.size.width.isFinite, rect.size.height.isFinite else {
                reportUserError(title: "Invalid Selection", message: "Could not determine the selected region. Try again.")
                return
            }

            let languages = recognitionLanguages
            let text = try await CapturePipeline.extractText(from: rect, languages: languages)

            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                reportUserError(title: "No Text Found", message: "Vision did not detect text in that region.")
                return
            }

            statusMessage = nil
            lastExtractedText = text
            previewDraftText = text
            historyManager.add(text: text)

            guard clipboardManager.copy(text: text) else {
                reportUserError(title: "Clipboard Error", message: "Could not write text to the clipboard.")
                return
            }
            captureCount += 1

            notificationManager.requestAuthorizationIfNeeded()

            if showPreviewAfterCapture {
                showPreviewWindow()
            }
        } catch let error as ScreenCaptureError {
            reportScreenCaptureError(error)
        } catch let error as OCRError {
            reportUserError(title: "OCR Failed", error: error)
        } catch {
            reportUnexpected(error, context: "process capture")
        }
    }

    private func reportScreenCaptureError(_ error: ScreenCaptureError) {
        switch error {
        case .permissionDenied:
            syncPermissionsAfterSystemChange()
            ScreenCapturePermissionAlert.present()
        case .captureFailed:
            reportUserError(
                title: "Capture Failed",
                message: "Could not read the selected region. Try a different area or display."
            )
        }
    }

    func copyPreviewDraft() {
        guard !previewDraftText.isEmpty else { return }
        _ = clipboardManager.copy(text: previewDraftText)
    }

    private func reportUserError(title: String, message: String) {
        statusMessage = message
        notificationManager.showError(title: title, body: message)
    }

    private func reportUserError(title: String, error: Error) {
        reportUserError(title: title, message: error.localizedDescription)
    }

    private func reportUnexpected(_ error: Error, context: String) {
        let message = error.localizedDescription
        statusMessage = message
        notificationManager.showError(
            title: "Something went wrong",
            body: "\(context): \(message)"
        )
        NSLog("Selectext unexpected error (\(context)): \(error)")
    }
}
