import AppKit

enum RegionSelectionResult {
    /// Selected rect in Quartz global display coordinates (top-left origin).
    case success(CGRect)
    case cancelled
    case failure(Error)
}

@MainActor
final class RegionSelectionManager {
    private var overlayWindows: [RegionSelectionWindow] = []
    private var completion: ((RegionSelectionResult) -> Void)?
    private var escapeMonitor: Any?
    private var isActive = false

    func cancel() {
        finish(.cancelled)
    }

    func begin(completion: @escaping (RegionSelectionResult) -> Void) {
        guard !isActive else { return }
        isActive = true
        self.completion = completion

        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            finish(.failure(ScreenCaptureError.captureFailed))
            return
        }

        NSApp.activate(ignoringOtherApps: true)

        for screen in screens {
            let window = RegionSelectionWindow(screen: screen) { [weak self] event in
                Task { @MainActor in
                    self?.handle(event: event)
                }
            }
            overlayWindows.append(window)
            window.orderFrontRegardless()
        }
        focusWindowUnderCursor()
        installEscapeMonitor()
    }

    private func focusWindowUnderCursor() {
        let mouse = NSEvent.mouseLocation
        let target = overlayWindows.first { window in
            window.frame.contains(mouse)
        } ?? overlayWindows.first

        target?.makeKeyAndOrderFront(nil)
        if let view = target?.contentView as? RegionSelectionView {
            target?.makeFirstResponder(view)
        }
    }

    private func installEscapeMonitor() {
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            Task { @MainActor in
                self?.finish(.cancelled)
            }
            return nil
        }
    }

    private func handle(event: RegionSelectionEvent) {
        switch event {
        case .cancelled:
            finish(.cancelled)
        case .completed(let rectInScreenSpace):
            finish(.success(Self.quartzRect(fromCocoa: rectInScreenSpace)))
        }
    }

    /// Cocoa screen space (origin bottom-left of the primary display, y up) →
    /// Quartz display space (origin top-left of the primary display, y down),
    /// which ScreenCaptureKit (`CGDisplayBounds`, `sourceRect`) uses.
    private static func quartzRect(fromCocoa rect: CGRect) -> CGRect {
        guard let primaryHeight = NSScreen.screens.first?.frame.maxY else { return rect }
        return CGRect(
            x: rect.minX,
            y: primaryHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    private func finish(_ result: RegionSelectionResult) {
        guard isActive else { return }
        isActive = false

        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }

        // Only order out: `close()` + dropping our strong reference double-released the
        // window mid-animation (EXC_BAD_ACCESS in _NSWindowTransformAnimation dealloc).
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()
        NSCursor.arrow.set()

        let handler = completion
        completion = nil
        handler?(result)
    }
}

enum RegionSelectionEvent {
    case cancelled
    case completed(CGRect)
}

final class RegionSelectionWindow: NSWindow {
    init(screen: NSScreen, handler: @escaping (RegionSelectionEvent) -> Void) {
        let frame = screen.frame
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        setFrame(frame, display: true)

        // Swift owns this window; AppKit must not release it again on close.
        isReleasedWhenClosed = false
        animationBehavior = .none

        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hasShadow = false

        let view = RegionSelectionView(screenFrame: frame, handler: handler)
        contentView = view
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
