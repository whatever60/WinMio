import AppKit

func solid(_ color: NSColor, pixels: Int, scale: CGFloat) -> CaptureImage {
    let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(color.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: pixels, height: pixels))
    return CaptureImage(cgImage: context.makeImage()!, scale: scale,
                        size: CGSize(width: CGFloat(pixels) / scale, height: CGFloat(pixels) / scale))
}

func verticalPattern() -> CaptureImage {
    let context = CGContext(data: nil, width: 10, height: 10, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(NSColor.green.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: 10, height: 5))
    context.setFillColor(NSColor.magenta.cgColor)
    context.fill(CGRect(x: 0, y: 5, width: 10, height: 5))
    return CaptureImage(cgImage: context.makeImage()!, scale: 1, size: CGSize(width: 10, height: 10))
}

@main @MainActor struct GeometryTest {
    static func main() async throws {
        let remembered = CaptureMode.last
        CaptureMode.last = .freeform
        precondition(CaptureMode.last == .freeform)
        CaptureMode.last = .fullScreen
        precondition(CaptureMode.last == .rectangle)
        CaptureMode.last = remembered
        let pipeline = CapturePipeline(displayCapture: DisplayCaptureService(), fileOutput: FileOutputService(),
                                       clipboardOutput: ClipboardOutputService(), eventBus: CaptureEventBus())
        let frozen: [CGDirectDisplayID: CaptureImage] = [1: solid(.red, pixels: 20, scale: 2), 2: solid(.blue, pixels: 10, scale: 1)]
        let frames: [CGDirectDisplayID: CGRect] = [1: CGRect(x: 0, y: 0, width: 10, height: 10),
                                                   2: CGRect(x: 10, y: 0, width: 10, height: 10)]
        let rectangle = try await pipeline.cropFrozenImage(from: frozen, screenFrames: frames,
                                                           selection: .rectangle(CGRect(x: 5, y: 0, width: 10, height: 10)))
        precondition(rectangle.cgImage.width == 20 && rectangle.cgImage.height == 20 && rectangle.scale == 2)
        let rep = NSBitmapImageRep(cgImage: rectangle.cgImage)
        precondition(rep.colorAt(x: 2, y: 10)!.redComponent > 0.9)
        precondition(rep.colorAt(x: 18, y: 10)!.blueComponent > 0.9)
        let oriented = try await pipeline.cropFrozenImage(from: [3: verticalPattern()],
                                                          screenFrames: [3: CGRect(x: 0, y: 0, width: 10, height: 10)],
                                                          selection: .rectangle(CGRect(x: 0, y: 0, width: 10, height: 10)))
        let orientedRep = NSBitmapImageRep(cgImage: oriented.cgImage)
        precondition(orientedRep.colorAt(x: 5, y: 2)!.redComponent > 0.9)
        precondition(orientedRep.colorAt(x: 5, y: 8)!.greenComponent > 0.9)
        let freeform = try await pipeline.cropFrozenImage(from: frozen, screenFrames: frames,
                                                          selection: .freeform([.zero, CGPoint(x: 20, y: 0), CGPoint(x: 0, y: 10)]))
        let masked = NSBitmapImageRep(cgImage: freeform.cgImage)
        let alphas = (0..<masked.pixelsHigh).flatMap { y in (0..<masked.pixelsWide).map { masked.colorAt(x: $0, y: y)!.alphaComponent } }
        precondition(alphas.contains { $0 == 0 } && alphas.contains { $0 > 0.9 })
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let config = CaptureConfiguration(saveFolderPath: folder.path, hasValidSaveFolder: true,
                                          playSoundOnCapture: false, saveToFile: true, organizeByMonth: false)
        let path = try await FileOutputService().write(image: rectangle, config: config)
        precondition(path.map(FileManager.default.fileExists(atPath:)) == true)
        try? FileManager.default.removeItem(at: folder)
        print("WindowsSnip geometry tests passed")
    }
}
