//
//  CaptureToolbar.swift
//  Mio
//

import AppKit
import SwiftUI

@MainActor final class CaptureToolbarPanel: NSPanel {
  init(mode: CaptureMode, onMode: @escaping (CaptureMode) -> Void, onCancel: @escaping () -> Void) {
    let size = NSSize(width: 260, height: 52)
    super.init(
      contentRect: NSRect(origin: .zero, size: size),
      styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    isFloatingPanel = true
    hidesOnDeactivate = false
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true
    animationBehavior = .none
    level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    let host = CaptureToolbarHostingView(
      rootView: CaptureToolbarView(mode: mode, onMode: onMode, onCancel: onCancel))
    host.frame = NSRect(origin: .zero, size: size)
    host.autoresizingMask = [.width, .height]
    contentView = host
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  func show(on requestedScreen: NSScreen? = nil) {
    guard let screen = requestedScreen ?? NSScreen.main ?? NSScreen.screens.first else { return }
    let frame = screen.visibleFrame
    setFrameOrigin(
      NSPoint(x: frame.midX - self.frame.width / 2, y: frame.maxY - self.frame.height - 12))
    orderFrontRegardless()
  }

  func hide() { orderOut(nil) }
}

@MainActor private final class CaptureToolbarHostingView: NSHostingView<CaptureToolbarView> {
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

struct CaptureToolbarView: View {
  @State var mode: CaptureMode
  @State private var hoveredMode: CaptureMode?
  let onMode: (CaptureMode) -> Void
  let onCancel: () -> Void

  var body: some View {
    HStack(spacing: 0) {
      ForEach(CaptureMode.allCases) { mode in
        Button {
          self.mode = mode
          if mode != .fullScreen { CaptureMode.last = mode }
          onMode(mode)
        } label: {
          Image(systemName: mode.systemImage)
            .frame(width: 44, height: 40)
            .foregroundStyle(self.mode == mode ? Color.white : Color.primary)
            .background(
              self.mode == mode
                ? Color.accentColor
                : hoveredMode == mode ? Color.primary.opacity(0.12) : Color.clear,
              in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).help(mode.title).accessibilityLabel(mode.title)
        .accessibilityAddTraits(self.mode == mode ? .isSelected : [])
        .onHover { inside in
          if inside { hoveredMode = mode }
          else if hoveredMode == mode { hoveredMode = nil }
        }
      }
      Divider().frame(height: 28).padding(.horizontal, 2)
      Button(action: onCancel) { Image(systemName: "xmark").frame(width: 34, height: 34) }
        .buttonStyle(.plain).help("Close").accessibilityLabel("Close")
    }
    .padding(6).frame(height: 52)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay { RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.18)) }
  }
}
