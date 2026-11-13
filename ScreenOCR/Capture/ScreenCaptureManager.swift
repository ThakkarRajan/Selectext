import AppKit
import CoreGraphics
import ScreenCaptureKit

enum ScreenCaptureError: LocalizedError {
    case permissionDenied
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen Recording is not enabled for Selectext, or the app needs a restart after you enabled it."
        case .captureFailed:
            return "Unable to capture the selected screen region."
        }
    }
}

enum ScreenCaptureAccess {
    /// TCC state for this process. Note: after the user enables Screen Recording,
    /// macOS usually reports `false` until the app is relaunched.
    static func hasWorkingAccess() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Tracked per launch, not persisted: after a TCC reset or re-signing, the request is
    /// what re-adds the app to the Screen Recording list in System Settings.
    private(set) static var hasRequestedSystemPrompt = false

    /// Triggers the system prompt at most once per launch. Returns `true` only if access is already granted.
    @discardableResult
    static func requestSystemPrompt() -> Bool {
        hasRequestedSystemPrompt = true
        return CGRequestScreenCaptureAccess()
    }

    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Screen Recording grants only take effect in a new process.
    static func relaunchApp() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            if let error {
                NSLog("Selectext relaunch failed: \(error)")
                return
            }
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}

struct ScreenCaptureManager {
    /// Captures `rectInScreenSpace` (Quartz global display coordinates, top-left origin)
    /// with ScreenCaptureKit. ScreenOCR's selection overlay and menu bar panel are excluded,
    /// so they never end up in the image.
    func captureRegion(_ rectInScreenSpace: CGRect) async throws -> CGImage {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            throw Self.mapError(error)
        }

        // The overlay runs per display, so a selection lies on a single display.
        let match = content.displays
            .map { display in (display, CGDisplayBounds(display.displayID)) }
            .max { lhs, rhs in
                Self.area(lhs.1.intersection(rectInScreenSpace)) < Self.area(rhs.1.intersection(rectInScreenSpace))
            }
        guard let (display, displayBounds) = match else {
            throw ScreenCaptureError.captureFailed
        }

        let clipped = rectInScreenSpace.intersection(displayBounds)
        guard !clipped.isNull, clipped.width >= 1, clipped.height >= 1 else {
            throw ScreenCaptureError.captureFailed
        }

        // Normal-level windows (tutorial, history, preview) stay capturable so the tutorial's
        // sample text can be read; overlays and the menu bar panel sit above that level.
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let ownOverlayWindows = content.windows.filter {
            $0.owningApplication?.processID == ownPID && $0.windowLayer != 0
        }
        let filter = SCContentFilter(display: display, excludingWindows: ownOverlayWindows)

        let scale = CGFloat(filter.pointPixelScale)
        let configuration = SCStreamConfiguration()
        // sourceRect is in display-local points, top-left origin.
        configuration.sourceRect = clipped.offsetBy(dx: -displayBounds.minX, dy: -displayBounds.minY)
        configuration.width = max(1, Int((clipped.width * scale).rounded()))
        configuration.height = max(1, Int((clipped.height * scale).rounded()))
        configuration.scalesToFit = false
        configuration.showsCursor = false
        configuration.capturesAudio = false

        do {
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        } catch {
            throw Self.mapError(error)
        }
    }

    private static func area(_ rect: CGRect) -> CGFloat {
        rect.isNull ? 0 : rect.width * rect.height
    }

    private static func mapError(_ error: Error) -> ScreenCaptureError {
        if let scError = error as? SCStreamError, scError.code == .userDeclined {
            return .permissionDenied
        }
        if !ScreenCaptureAccess.hasWorkingAccess() {
            return .permissionDenied
        }
        NSLog("Selectext ScreenCaptureKit error: \(error)")
        return .captureFailed
    }
}
