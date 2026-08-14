//
//  SelectionWindow.swift
//  Mio
//
//  Multi-screen selection window manager
//

import Foundation
import AppKit

@MainActor
protocol SelectionWindowDelegate: AnyObject {
    func selectionWindow(_ window: SelectionWindow, didSelect selection: VirtualDesktopSelection)
    func selectionWindow(_ window: SelectionWindow, didSelectWindow windowResult: WindowHitTestResult)
    func selectionWindowDidSelectFullScreen(_ window: SelectionWindow)
    func selectionWindowDidCancel(_ window: SelectionWindow)
}

// MARK: - Overlay Window for Multi-Screen Support

@MainActor
final class OverlayWindow: NSPanel {
    init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: backing,
            defer: flag
        )

        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = false
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
class SelectionWindow: NSWindow {
    weak var selectionDelegate: SelectionWindowDelegate?

    // Multi-screen support: one window per screen
    private var overlayWindows: [OverlayWindow] = []
    private var overlayViews: [SelectionOverlayView] = []
    private let frozenScreens: [CGDirectDisplayID: CaptureImage]
    private let overlayConfiguration: SelectionOverlayView.Configuration
    private var mode: CaptureMode
    private var captureToolbar: CaptureToolbarPanel?
    private var escapeKeyMonitor: Any?
    private var localEscapeKeyMonitor: Any?
    private var hasCommitted = false
    private var previousApplication: NSRunningApplication?

    init(
        frozenScreens: [CGDirectDisplayID: CaptureImage],
        overlayConfiguration: SelectionOverlayView.Configuration = .screenshot,
        mode: CaptureMode = .rectangle
    ) {
        self.frozenScreens = frozenScreens
        self.overlayConfiguration = overlayConfiguration
        self.mode = mode
        // Create main window (first screen) for NSWindow inheritance
        let mainScreen = NSScreen.main ?? NSScreen.screens.first!

        super.init(
            contentRect: mainScreen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        setupMultiScreenOverlays()
        captureToolbar = CaptureToolbarPanel(
            mode: mode,
            onMode: { [weak self] in self?.setMode($0) },
            onCancel: { [weak self] in self?.cancel() }
        )
    }

    private func setupMultiScreenOverlays() {
        // Create one window per screen
        for screen in NSScreen.screens {
            // Create window WITHOUT screen parameter to avoid auto-repositioning
            let window = OverlayWindow(contentRect: screen.frame, backing: .buffered, defer: false)

            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .screenSaver
            window.ignoresMouseEvents = false
            window.hasShadow = false
            window.acceptsMouseMovedEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            // Manually position window to this screen's frame
            window.setFrame(screen.frame, display: false)

            // Per-screen frozen snapshot lookup. The CaptureCoordinator
            // captures every screen before constructing SelectionWindow, so
            // each NSScreen here has a corresponding CaptureImage entry.
            let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            let snapshot = displayID.flatMap { frozenScreens[$0] }

            // Create overlay view for this screen - frame must be relative to window (0,0 origin)
            let overlayFrame = NSRect(x: 0, y: 0, width: screen.frame.width, height: screen.frame.height)
            let overlayView = SelectionOverlayView(
                frame: overlayFrame,
                configuration: overlayConfiguration,
                displayID: displayID,
                backgroundImage: snapshot,
                mode: mode
            )
            overlayView.onPreview = { [weak self] selection in self?.showPreview(selection) }
            overlayView.onComplete = { [weak self] selection in
                guard let self = self else { return }
                self.commit { self.selectionDelegate?.selectionWindow(self, didSelect: selection) }
            }
            overlayView.onWindowSelect = { [weak self] hitResult in
                guard let self = self else { return }
                self.commit { self.selectionDelegate?.selectionWindow(self, didSelectWindow: hitResult) }
            }
            overlayView.onCancel = { [weak self] in
                guard let self = self else { return }
                self.selectionDelegate?.selectionWindowDidCancel(self)
            }

            window.contentView = overlayView
            overlayWindows.append(window)
            overlayViews.append(overlayView)
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // Convenience methods for showing/hiding
    func show() {
        if escapeKeyMonitor == nil {
            escapeKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard event.keyCode == 53 else { return } // ESC
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.selectionDelegate?.selectionWindowDidCancel(self)
                }
            }
        }
        if localEscapeKeyMonitor == nil {
            localEscapeKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard event.keyCode == 53 else { return event }
                self?.cancel()
                return nil
            }
        }

        previousApplication = NSWorkspace.shared.frontmostApplication
        NSApp.activate(ignoringOtherApps: true)
        for window in overlayWindows {
            window.ignoresMouseEvents = false
            window.orderFrontRegardless()
        }
        captureToolbar?.show()
        (overlayWindows.first { $0.frame.contains(NSEvent.mouseLocation) } ?? overlayWindows.first)?.makeKey()
        updateCursor()
    }

    func hide() {
        if let escapeKeyMonitor {
            NSEvent.removeMonitor(escapeKeyMonitor)
            self.escapeKeyMonitor = nil
        }
        if let localEscapeKeyMonitor {
            NSEvent.removeMonitor(localEscapeKeyMonitor)
            self.localEscapeKeyMonitor = nil
        }

        // Hide all overlay windows immediately
        for window in overlayWindows {
            window.orderOut(nil)
            window.ignoresMouseEvents = true
        }
        captureToolbar?.hide()
        NSCursor.arrow.set()
        previousApplication?.activate(options: [])
        previousApplication = nil
    }

    private func showPreview(_ selection: VirtualDesktopSelection?) {
        overlayViews.forEach { $0.displaySelection = selection }
    }

    private func setMode(_ mode: CaptureMode) {
        self.mode = mode
        showPreview(nil)
        overlayViews.forEach { $0.mode = mode }
        (overlayWindows.first { $0.frame.contains(NSEvent.mouseLocation) } ?? overlayWindows.first)?.makeKey()
        updateCursor()
        if mode == .fullScreen { commitFullScreen() }
    }

    private func updateCursor() {
        (mode == .rectangle || mode == .freeform ? NSCursor.crosshair : NSCursor.arrow).set()
    }

    private func cancel() { selectionDelegate?.selectionWindowDidCancel(self) }

    private func commit(_ action: () -> Void) {
        guard !hasCommitted else { return }
        hasCommitted = true
        action()
    }

    private func commitFullScreen() {
        commit { selectionDelegate?.selectionWindowDidSelectFullScreen(self) }
    }
}

@MainActor
class SelectionOverlayView: NSView {
    var onPreview: ((VirtualDesktopSelection?) -> Void)?
    var onComplete: ((VirtualDesktopSelection) -> Void)?
    var onWindowSelect: ((WindowHitTestResult) -> Void)?
    var onCancel: (() -> Void)?
    var mode: CaptureMode {
        didSet {
            resetSelection()
            window?.invalidateCursorRects(for: self)
        }
    }
    var displaySelection: VirtualDesktopSelection? {
        didSet {
            guard let window else {
                needsDisplay = true
                return
            }
            let dirtyGlobal = [oldValue, displaySelection]
                .compactMap(selectionBounds)
                .reduce(CGRect.null) { $0.union($1) }
            guard !dirtyGlobal.isNull, dirtyGlobal.intersects(window.frame) else { return }
            let dirtyWindow = window.convertFromScreen(dirtyGlobal)
            setNeedsDisplay(convert(dirtyWindow, from: nil).insetBy(dx: -3, dy: -3))
        }
    }

    struct Configuration {
        var overlayOpacity: CGFloat
        var minSelectionSize: CGFloat

        static let screenshot = Configuration(overlayOpacity: 0.2, minSelectionSize: 0)
    }

    private let configuration: Configuration
    private(set) var displayID: CGDirectDisplayID?
    private let backgroundImage: CaptureImage?

    private var startPoint: NSPoint?
    private var endPoint: NSPoint?
    private var freeformPoints: [CGPoint] = []
    private var isDragging = false
    private var pendingWindowHit: WindowHitTestResult?
    private var hoverWindowHit: WindowHitTestResult?
    private var highlightRect: NSRect?
    private var trackingArea: NSTrackingArea?

    init(frame: NSRect,
         configuration: Configuration = .screenshot,
         displayID: CGDirectDisplayID? = nil,
         backgroundImage: CaptureImage? = nil,
         mode: CaptureMode = .rectangle) {
        self.configuration = configuration
        self.displayID = displayID
        self.backgroundImage = backgroundImage
        self.mode = mode
        super.init(frame: frame)
        self.wantsLayer = true
        // Keep layer clear; dimming is drawn in draw(_:) to allow full transparency in the selection hole
        self.layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let scale = window?.backingScaleFactor {
            layer?.contentsScale = scale
        }
        hoverWindowHit = nil
        pendingWindowHit = nil
        highlightRect = nil
        needsDisplay = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.mouseMoved, .cursorUpdate, .activeAlways, .inVisibleRect]
        let area = NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    // CRITICAL: Accept first mouse click even when app is not active
    // Without this, users need to click twice when Finder/Desktop is frontmost
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    // CRITICAL: Don't delay window ordering when clicking
    // This ensures immediate event processing even when app was not frontmost
    override func shouldDelayWindowOrdering(for event: NSEvent) -> Bool {
        return false
    }

    /// 只有 `highlightRect` 真的变化才重绘。
    ///
    /// 指针在**同一个窗口内部**移动时 hit-test 返回同一个窗口，`highlightRect`
    /// 算出来完全一样，重绘的是逐像素相同的一帧。而 `draw(_:)` 在有 hole rect
    /// 时要画两遍全屏冻结图 + 一次全屏 dim 填充（5K 屏约 3000 万次像素写入），
    /// 鼠标移动事件在现代设备上能到 100+Hz —— 无条件 `needsDisplay = true`
    /// 是纯浪费，直接压 PRODUCT.md §5 的 60% CPU 硬约束。
    ///
    /// 等价性论证：`draw(_:)` 只读 `backgroundImage`（immutable let）、
    /// `configuration`（immutable let）、`startPoint`、`endPoint`、`highlightRect`。
    /// 本方法被 `!isDragging` 守卫，不碰 `startPoint` / `endPoint`；它写的
    /// `hoverWindowHit` 与 `pendingWindowHit` 不被 `draw` 读取。所以本方法能够
    /// 影响绘制结果的状态**只有** `highlightRect` —— 它没变就意味着帧内容没变。
    override func mouseMoved(with event: NSEvent) {
        desiredCursor.set()
        guard !isDragging, mode == .window else { return }
        let previousHighlight = highlightRect
        hoverWindowHit = resolveWindowHit()   // 副作用：写 highlightRect
        pendingWindowHit = hoverWindowHit
        if highlightRect != previousHighlight {
            onPreview?(hoverWindowHit.map { .rectangle($0.bounds) })
            needsDisplay = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard mode != .fullScreen else { return }
        startPoint = globalPoint(for: event)
        endPoint = startPoint
        freeformPoints = startPoint.map { [$0] } ?? []
        isDragging = true
        pendingWindowHit = mode == .window ? (hoverWindowHit ?? resolveWindowHit()) : nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        desiredCursor.set()
        guard isDragging else { return }
        endPoint = globalPoint(for: event)
        guard let start = startPoint, let end = endPoint else { return }
        switch mode {
        case .rectangle:
            onPreview?(.rectangle(rect(from: start, to: end)))
        case .freeform:
            freeformPoints.append(end)
            onPreview?(.freeform(freeformPoints))
        case .window, .fullScreen:
            break
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging, let start = startPoint else { return }
        isDragging = false
        let end = globalPoint(for: event) ?? start
        let selection: VirtualDesktopSelection?
        switch mode {
        case .rectangle:
            let value = rect(from: start, to: end)
            if value.width > configuration.minSelectionSize
                && value.height > configuration.minSelectionSize {
                selection = .rectangle(value)
            } else {
                selection = nil
            }
        case .freeform:
            freeformPoints.append(end)
            let bounds = freeformPoints.reduce(CGRect.null) { $0.union(CGRect(origin: $1, size: .zero)) }
            if freeformPoints.count > 2
                && bounds.width > configuration.minSelectionSize
                && bounds.height > configuration.minSelectionSize {
                selection = .freeform(freeformPoints)
            } else {
                selection = nil
            }
        case .window:
            selection = nil
            if let windowHit = pendingWindowHit { Task { [weak self] in self?.onWindowSelect?(windowHit) } }
        case .fullScreen:
            selection = nil
        }
        if let selection { Task { [weak self] in self?.onComplete?(selection) } }
        resetSelection()
    }

    override func rightMouseDown(with event: NSEvent) {
        resetSelection()
        Task { [weak self] in self?.onCancel?() }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Step 1: paint the frozen full-screen snapshot as the background.
        // PRODUCT.md §2: every screen is frozen at trigger time and the user
        // picks the region from those frozen pixels.
        if let backgroundImage, let context = NSGraphicsContext.current?.cgContext {
            context.draw(backgroundImage.cgImage, in: bounds)
        }

        // Step 2: dim the entire screen so unselected area visibly recedes.
        NSColor.black.withAlphaComponent(configuration.overlayOpacity).setFill()
        bounds.fill()

        guard let path = selectionPath() else { return }

        // Step 4: clip to the selection and re-draw the snapshot, "punching out"
        // the dim layer so the selection shows the original brightness.
        if let backgroundImage, let context = NSGraphicsContext.current?.cgContext {
            context.saveGState()
            path.addClip()
            context.draw(backgroundImage.cgImage, in: bounds)
            context.restoreGState()
        }

        // Step 5: stroke the selection border.
        NSColor.systemBlue.setStroke()
        path.lineWidth = 2
        path.stroke()
    }

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: desiredCursor)
    }

    override func cursorUpdate(with event: NSEvent) { desiredCursor.set() }

    // MARK: - Private helpers

    private var desiredCursor: NSCursor { mode == .rectangle || mode == .freeform ? .crosshair : .arrow }

    private func globalPoint(for event: NSEvent) -> CGPoint? {
        window?.convertToScreen(CGRect(origin: event.locationInWindow, size: .zero)).origin
    }

    private func rect(from a: CGPoint, to b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    private func selectionBounds(_ selection: VirtualDesktopSelection?) -> CGRect? {
        switch selection {
        case .rectangle(let rect):
            return rect.standardized
        case .freeform(let points):
            return points.reduce(CGRect.null) { $0.union(CGRect(origin: $1, size: .zero)) }
        case nil:
            return nil
        }
    }

    private func resetSelection() {
        isDragging = false
        startPoint = nil
        endPoint = nil
        freeformPoints = []
        pendingWindowHit = nil
        hoverWindowHit = nil
        highlightRect = nil
        onPreview?(nil)
        needsDisplay = true
    }

    private func selectionPath() -> NSBezierPath? {
        if mode == .window, let highlightRect { return NSBezierPath(rect: highlightRect) }
        guard let selection = displaySelection, let window else { return nil }
        func local(_ point: CGPoint) -> CGPoint {
            let inWindow = window.convertFromScreen(CGRect(origin: point, size: .zero)).origin
            return convert(inWindow, from: nil)
        }
        switch selection {
        case .rectangle(let global):
            let rectInWindow = window.convertFromScreen(global)
            return NSBezierPath(rect: convert(rectInWindow, from: nil))
        case .freeform(let points):
            guard let first = points.first else { return nil }
            let path = NSBezierPath()
            path.move(to: local(first))
            points.dropFirst().forEach { path.line(to: local($0)) }
            path.close()
            return path
        }
    }

    private func resolveWindowHit() -> WindowHitTestResult? {
        guard let window = self.window else { return nil }
        do {
            let hit = try WindowCaptureService.shared.hitTestFrontmostWindowAtMouse(
                excludingWindowIDs: Set([CGWindowID(window.windowNumber)]),
                skipSelfWindows: true
            )
            let rectOnScreen = hit.bounds
            let rectInWindow = window.convertFromScreen(rectOnScreen)
            let rectInView = convert(rectInWindow, from: nil)
            highlightRect = rectInView
            return hit
        } catch {
            highlightRect = nil
            return nil
        }
    }
}
