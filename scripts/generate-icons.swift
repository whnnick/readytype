#!/usr/bin/env swift

import AppKit
import Foundation

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcesURL = rootURL
    .appendingPathComponent("ReadyType")
    .appendingPathComponent("ReadyType")
    .appendingPathComponent("Resources")
let iconsetURL = resourcesURL.appendingPathComponent("ReadyTypeAppIcon.iconset")
let appIconURL = resourcesURL.appendingPathComponent("ReadyTypeAppIcon.icns")
let menuIconURL = resourcesURL.appendingPathComponent("ReadyTypeMenuBarTemplate.png")

try FileManager.default.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

func savePNG(_ image: NSImage, to url: URL) throws {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "ReadyTypeIconGeneration", code: 1)
    }

    try pngData.write(to: url)
}

func makeImage(size: CGFloat, draw: (CGRect) -> Void) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    draw(CGRect(x: 0, y: 0, width: size, height: size))
    image.unlockFocus()
    return image
}

func drawRoundedRect(_ rect: CGRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func drawRoundedStroke(_ rect: CGRect, radius: CGFloat, width: CGFloat, color: NSColor) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    path.lineWidth = width
    color.setStroke()
    path.stroke()
}

func drawStroke(points: [CGPoint], width: CGFloat, color: NSColor) {
    let path = NSBezierPath()
    guard let first = points.first else { return }
    path.move(to: first)

    if points.count == 4 {
        path.curve(to: points[3], controlPoint1: points[1], controlPoint2: points[2])
    } else {
        for point in points.dropFirst() {
            path.line(to: point)
        }
    }

    path.lineWidth = width
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    color.setStroke()
    path.stroke()
}

func drawAppIcon(in rect: CGRect) {
    let scale = rect.width / 512
    let background = NSColor(calibratedRed: 246 / 255, green: 247 / 255, blue: 242 / 255, alpha: 1)
    let border = NSColor(calibratedRed: 217 / 255, green: 222 / 255, blue: 210 / 255, alpha: 1)
    let ink = NSColor(calibratedRed: 24 / 255, green: 33 / 255, blue: 29 / 255, alpha: 1)
    let moss = NSColor(calibratedRed: 94 / 255, green: 127 / 255, blue: 100 / 255, alpha: 1)
    let success = NSColor(calibratedRed: 47 / 255, green: 143 / 255, blue: 91 / 255, alpha: 1)
    let white = NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: 1)

    let appRect = CGRect(x: rect.minX + 40 * scale, y: rect.minY + 40 * scale, width: 432 * scale, height: 432 * scale)
    drawRoundedRect(appRect, radius: 108 * scale, color: background)
    drawRoundedStroke(appRect, radius: 108 * scale, width: 8 * scale, color: border)

    let fieldRect = CGRect(x: 100 * scale, y: 142 * scale, width: 312 * scale, height: 228 * scale)
    drawRoundedRect(fieldRect, radius: 48 * scale, color: white)
    drawRoundedStroke(fieldRect, radius: 48 * scale, width: 8 * scale, color: border)

    drawStroke(
        points: [CGPoint(x: 168 * scale, y: 192 * scale), CGPoint(x: 168 * scale, y: 320 * scale)],
        width: 24 * scale,
        color: ink
    )
    drawStroke(
        points: [CGPoint(x: 220 * scale, y: 276 * scale), CGPoint(x: 220 * scale, y: 236 * scale)],
        width: 22 * scale,
        color: moss
    )
    drawStroke(
        points: [CGPoint(x: 264 * scale, y: 300 * scale), CGPoint(x: 264 * scale, y: 212 * scale)],
        width: 22 * scale,
        color: moss
    )
    drawStroke(
        points: [CGPoint(x: 308 * scale, y: 272 * scale), CGPoint(x: 308 * scale, y: 240 * scale)],
        width: 22 * scale,
        color: moss
    )
    drawStroke(
        points: [
            CGPoint(x: 348 * scale, y: 220 * scale),
            CGPoint(x: 374 * scale, y: 194 * scale),
            CGPoint(x: 424 * scale, y: 266 * scale)
        ],
        width: 24 * scale,
        color: success
    )
}

func drawMenuIcon(in rect: CGRect) {
    let scale = rect.width / 44
    let black = NSColor.black

    drawStroke(
        points: [CGPoint(x: 8 * scale, y: 12 * scale), CGPoint(x: 8 * scale, y: 32 * scale)],
        width: 4 * scale,
        color: black
    )
    drawStroke(
        points: [CGPoint(x: 16 * scale, y: 26 * scale), CGPoint(x: 16 * scale, y: 18 * scale)],
        width: 3.4 * scale,
        color: black
    )
    drawStroke(
        points: [CGPoint(x: 23 * scale, y: 30 * scale), CGPoint(x: 23 * scale, y: 14 * scale)],
        width: 3.4 * scale,
        color: black
    )
    drawStroke(
        points: [CGPoint(x: 30 * scale, y: 25 * scale), CGPoint(x: 30 * scale, y: 19 * scale)],
        width: 3.4 * scale,
        color: black
    )
    drawStroke(
        points: [
            CGPoint(x: 34 * scale, y: 16 * scale),
            CGPoint(x: 38 * scale, y: 12 * scale),
            CGPoint(x: 43 * scale, y: 24 * scale)
        ],
        width: 3.4 * scale,
        color: black
    )
}

let iconFiles: [(name: String, pixels: CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

var generatedIcons: [(type: String, data: Data)] = []
let icnsTypesByFileName: [String: String] = [
    "icon_16x16.png": "icp4",
    "icon_16x16@2x.png": "icp5",
    "icon_32x32@2x.png": "icp6",
    "icon_128x128.png": "ic07",
    "icon_128x128@2x.png": "ic08",
    "icon_256x256@2x.png": "ic09",
    "icon_512x512@2x.png": "ic10"
]

for iconFile in iconFiles {
    let image = makeImage(size: iconFile.pixels, draw: drawAppIcon)
    let url = iconsetURL.appendingPathComponent(iconFile.name)
    try savePNG(image, to: url)

    if let type = icnsTypesByFileName[iconFile.name] {
        generatedIcons.append((type: type, data: try Data(contentsOf: url)))
    }
}

let menuIcon = makeImage(size: 44, draw: drawMenuIcon)
try savePNG(menuIcon, to: menuIconURL)

func appendASCII(_ string: String, to data: inout Data) {
    data.append(string.data(using: .ascii)!)
}

func appendUInt32(_ value: UInt32, to data: inout Data) {
    var bigEndianValue = value.bigEndian
    withUnsafeBytes(of: &bigEndianValue) { data.append(contentsOf: $0) }
}

var icnsData = Data()
let totalLength = generatedIcons.reduce(8) { partial, icon in
    partial + 8 + icon.data.count
}

appendASCII("icns", to: &icnsData)
appendUInt32(UInt32(totalLength), to: &icnsData)

for icon in generatedIcons {
    appendASCII(icon.type, to: &icnsData)
    appendUInt32(UInt32(icon.data.count + 8), to: &icnsData)
    icnsData.append(icon.data)
}

try icnsData.write(to: appIconURL)

print("Generated ReadyType app and menu bar icons.")
