//
//  CaptureMode.swift
//  Mio
//

import CoreGraphics
import Foundation

enum CaptureMode: String, CaseIterable, Identifiable, Sendable {
  case rectangle = "rectangle"
  case window = "window"
  case fullScreen = "full_screen"
  case freeform = "freeform"

  var id: String { rawValue }
  var title: String {
    switch self {
    case .rectangle: "Rectangle"
    case .window: "Window"
    case .fullScreen: "Full screen"
    case .freeform: "Freeform"
    }
  }
  var systemImage: String {
    switch self {
    case .rectangle: "rectangle.dashed"
    case .window: "macwindow"
    case .fullScreen: "rectangle.inset.filled"
    case .freeform: "lasso"
    }
  }
  static var last: CaptureMode {
    get {
      let stored = UserDefaults.standard.string(forKey: "windowsSnip.lastCaptureMode.v1").flatMap(
        Self.init(rawValue:))
      return stored == .fullScreen ? .rectangle : stored ?? .rectangle
    }
    set { UserDefaults.standard.set(newValue.rawValue, forKey: "windowsSnip.lastCaptureMode.v1") }
  }
}

nonisolated public enum VirtualDesktopSelection: Sendable {
  case rectangle(CGRect)
  case freeform([CGPoint])
}
