import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerSystemColorsChannel(flutterViewController)

    super.awakeFromNib()
  }

  private func registerSystemColorsChannel(_ flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "anycast_scout_gui/system_colors",
      binaryMessenger: flutterViewController.engine.binaryMessenger)

    channel.setMethodCallHandler { call, result in
      guard call.method == "resolvedDarkColors" else {
        result(FlutterMethodNotImplemented)
        return
      }

      let appearance = NSAppearance(named: .darkAqua)
      result([
        "windowBackground": self.argb(NSColor.windowBackgroundColor, appearance),
        "controlBackground": self.argb(NSColor.controlBackgroundColor, appearance),
        "separator": self.argb(NSColor.separatorColor, appearance),
        "grid": self.argb(NSColor.gridColor, appearance),
        "label": self.argb(NSColor.labelColor, appearance),
        "secondaryLabel": self.argb(NSColor.secondaryLabelColor, appearance),
        "tertiaryLabel": self.argb(NSColor.tertiaryLabelColor, appearance),
        "controlAccent": self.argb(NSColor.controlAccentColor, appearance),
        "selectedContentBackground": self.argb(NSColor.selectedContentBackgroundColor, appearance),
        "systemRed": self.argb(NSColor.systemRed, appearance),
      ])
    }
  }

  private func argb(_ color: NSColor, _ appearance: NSAppearance?) -> Int {
    var resolved = color
    if let appearance = appearance {
      appearance.performAsCurrentDrawingAppearance {
        resolved = color.usingColorSpace(NSColorSpace.sRGB) ?? color
      }
    }

    let converted = resolved.usingColorSpace(NSColorSpace.sRGB) ?? resolved
    let alpha = Int((converted.alphaComponent * 255.0).rounded())
    let red = Int((converted.redComponent * 255.0).rounded())
    let green = Int((converted.greenComponent * 255.0).rounded())
    let blue = Int((converted.blueComponent * 255.0).rounded())

    return (alpha << 24) | (red << 16) | (green << 8) | blue
  }
}
