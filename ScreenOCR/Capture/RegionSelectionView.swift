import AppKit

final class RegionSelectionView: NSView {
    private let handler: (RegionSelectionEvent) -> Void

    private var dragStart: NSPoint?
    private var selectionRect: CGRect = .zero
    private var isDragging = false

    init(screenFrame: CGRect, handler: @escaping (RegionSelectionEvent) -> Void) {
        self.handler = handler
        super.init(frame: screenFrame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        resetCursorRects()
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        let dimPath = NSBezierPath(rect: bounds)
        if selectionRect.width > 1, selectionRect.height > 1 {
            dimPath.append(NSBezierPath(rect: selectionRect))
            dimPath.windingRule = .evenOdd
        }
        NSColor.black.withAlphaComponent(0.42).setFill()
        dimPath.fill()

        if !isDragging || selectionRect.width <= 1 || selectionRect.height <= 1 {
            drawInstructionBanner()
        }

        guard selectionRect.width > 1, selectionRect.height > 1 else { return }

        let border = NSBezierPath(rect: selectionRect)
        NSColor.systemBlue.setStroke()
        border.lineWidth = 2
        border.stroke()

        NSColor.systemBlue.withAlphaComponent(0.12).setFill()
        selectionRect.fill()

        let w = Int(selectionRect.width.rounded())
        let h = Int(selectionRect.height.rounded())
        let label = "\(w) × \(h)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let size = (label as NSString).size(withAttributes: attributes)
        let labelRect = CGRect(
            x: selectionRect.midX - size.width / 2 - 8,
            y: selectionRect.maxY + 8,
            width: size.width + 16,
            height: size.height + 6
        )
        NSColor.black.withAlphaComponent(0.65).setFill()
        NSBezierPath(roundedRect: labelRect, xRadius: 6, yRadius: 6).fill()
        (label as NSString).draw(in: labelRect.insetBy(dx: 8, dy: 3), withAttributes: attributes)
    }

    private func drawInstructionBanner() {
        let text = "Drag to select a region · Esc to cancel"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let banner = CGRect(
            x: bounds.midX - size.width / 2 - 20,
            y: 48,
            width: size.width + 40,
            height: size.height + 16
        )
        NSColor.black.withAlphaComponent(0.72).setFill()
        NSBezierPath(roundedRect: banner, xRadius: 10, yRadius: 10).fill()
        (text as NSString).draw(
            in: banner.insetBy(dx: 20, dy: 8),
            withAttributes: attributes
        )
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            handler(.cancelled)
            return
        }
        super.keyDown(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(self)
        NSCursor.crosshair.set()
        dragStart = convert(event.locationInWindow, from: nil)
        isDragging = true
        selectionRect = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging, let start = dragStart else { return }
        let current = convert(event.locationInWindow, from: nil)
        selectionRect = rectFromPoints(start, current)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        isDragging = false
        dragStart = nil

        guard selectionRect.width >= 4, selectionRect.height >= 4 else {
            selectionRect = .zero
            needsDisplay = true
            return
        }

        handler(.completed(convertSelectionToScreenSpace(selectionRect)))
    }

    private func rectFromPoints(_ a: NSPoint, _ b: NSPoint) -> CGRect {
        CGRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(a.x - b.x),
            height: abs(a.y - b.y)
        )
    }

    private func convertSelectionToScreenSpace(_ localRect: CGRect) -> CGRect {
        guard let window else { return localRect }

        let topLeft = convert(NSPoint(x: localRect.minX, y: localRect.minY), to: nil)
        let bottomRight = convert(NSPoint(x: localRect.maxX, y: localRect.maxY), to: nil)

        let screenTopLeft = window.convertPoint(toScreen: topLeft)
        let screenBottomRight = window.convertPoint(toScreen: bottomRight)

        let minX = min(screenTopLeft.x, screenBottomRight.x)
        let minY = min(screenTopLeft.y, screenBottomRight.y)
        let width = abs(screenBottomRight.x - screenTopLeft.x)
        let height = abs(screenBottomRight.y - screenTopLeft.y)

        return CGRect(x: minX, y: minY, width: width, height: height)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }
}
