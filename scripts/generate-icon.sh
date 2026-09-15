#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RESOURCES_DIR="${ROOT_DIR}/Sources/SoundLabApp/Resources"
OUTPUT_ICNS="${RESOURCES_DIR}/AppIcon.icns"

mkdir -p "${RESOURCES_DIR}"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "${TMP_DIR}"' EXIT

BASE_PNG="${TMP_DIR}/icon_1024.png"
ICONSET_DIR="${TMP_DIR}/AppIcon.iconset"
mkdir -p "${ICONSET_DIR}"

echo "Rendering 1024x1024 base icon..."
swift - "${BASE_PNG}" << 'EOF'
import Cocoa

let size = NSSize(width: 1024, height: 1024)
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size.width),
    pixelsHigh: Int(size.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Failed to create NSBitmapImageRep")
}
rep.size = size

NSGraphicsContext.saveGraphicsState()
guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
    fatalError("Failed to create NSGraphicsContext")
}
NSGraphicsContext.current = context
let cg = context.cgContext

// macOS Squircle standard: 824x824 squircle centered at (512, 512).
let squircleRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let squirclePath = NSBezierPath(roundedRect: squircleRect, xRadius: 185, yRadius: 185)

// Drop shadow for squircle
cg.saveGState()
let shadowColor = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.35)
cg.setShadow(offset: CGSize(width: 0, height: -12), blur: 24, color: shadowColor)
NSColor.black.setFill()
squirclePath.fill()
cg.restoreGState()

// Clip to squircle for background
cg.saveGState()
squirclePath.addClip()

let colorSpace = CGColorSpaceCreateDeviceRGB()
let bgColors = [
    CGColor(srgbRed: 0.12, green: 0.14, blue: 0.19, alpha: 1.0),
    CGColor(srgbRed: 0.05, green: 0.06, blue: 0.09, alpha: 1.0)
] as CFArray
let bgLocations: [CGFloat] = [0.0, 1.0]
if let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: bgLocations) {
    cg.drawLinearGradient(bgGradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
}

// Radial ambient glow
let glowColors = [
    CGColor(srgbRed: 0.0, green: 0.5, blue: 1.0, alpha: 0.18),
    CGColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
] as CFArray
if let radialGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
    cg.drawRadialGradient(radialGrad, startCenter: CGPoint(x: 512, y: 512), startRadius: 0, endCenter: CGPoint(x: 512, y: 512), endRadius: 380, options: [])
}

cg.restoreGState()

// Squircle border highlight
cg.saveGState()
let borderPath = NSBezierPath(roundedRect: squircleRect.insetBy(dx: 1, dy: 1), xRadius: 184, yRadius: 184)
borderPath.lineWidth = 2.0
NSColor(calibratedWhite: 1.0, alpha: 0.12).setStroke()
borderPath.stroke()
cg.restoreGState()

// Equalizer bars in center
let barWidth: CGFloat = 48
let barSpacing: CGFloat = 32
let heights: [CGFloat] = [180, 320, 480, 320, 180]
let startX: CGFloat = 512 - (CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * barSpacing) / 2
let centerY: CGFloat = 512

let barColors = [
    CGColor(srgbRed: 0.0, green: 0.85, blue: 1.0, alpha: 1.0),
    CGColor(srgbRed: 0.38, green: 0.32, blue: 0.98, alpha: 1.0)
] as CFArray
let barGradient = CGGradient(colorsSpace: colorSpace, colors: barColors, locations: [0.0, 1.0])!

for (i, h) in heights.enumerated() {
    let x = startX + CGFloat(i) * (barWidth + barSpacing)
    let y = centerY - h / 2
    let barRect = CGRect(x: x, y: y, width: barWidth, height: h)
    let barPath = NSBezierPath(roundedRect: barRect, xRadius: barWidth / 2, yRadius: barWidth / 2)

    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -4), blur: 16, color: CGColor(srgbRed: 0.0, green: 0.7, blue: 1.0, alpha: 0.45))
    barPath.addClip()
    cg.drawLinearGradient(barGradient, start: CGPoint(x: x, y: y + h), end: CGPoint(x: x, y: y), options: [])
    cg.restoreGState()
}

// Sound wave arcs
let waveColor1 = NSColor(calibratedRed: 0.0, green: 0.85, blue: 1.0, alpha: 0.7)
let waveColor2 = NSColor(calibratedRed: 0.35, green: 0.45, blue: 1.0, alpha: 0.4)

// Left arc 1
let leftArc1 = NSBezierPath()
leftArc1.appendArc(withCenter: NSPoint(x: 512, y: 512), radius: 250, startAngle: 145, endAngle: 215)
waveColor1.setStroke()
leftArc1.lineWidth = 8.0
leftArc1.lineCapStyle = .round
leftArc1.stroke()

// Left arc 2
let leftArc2 = NSBezierPath()
leftArc2.appendArc(withCenter: NSPoint(x: 512, y: 512), radius: 310, startAngle: 155, endAngle: 205)
waveColor2.setStroke()
leftArc2.lineWidth = 6.0
leftArc2.lineCapStyle = .round
leftArc2.stroke()

// Right arc 1
let rightArc1 = NSBezierPath()
rightArc1.appendArc(withCenter: NSPoint(x: 512, y: 512), radius: 250, startAngle: -35, endAngle: 35)
waveColor1.setStroke()
rightArc1.lineWidth = 8.0
rightArc1.lineCapStyle = .round
rightArc1.stroke()

// Right arc 2
let rightArc2 = NSBezierPath()
rightArc2.appendArc(withCenter: NSPoint(x: 512, y: 512), radius: 310, startAngle: -25, endAngle: 25)
waveColor2.setStroke()
rightArc2.lineWidth = 6.0
rightArc2.lineCapStyle = .round
rightArc2.stroke()

NSGraphicsContext.restoreGraphicsState()

guard let pngData = rep.representation(using: .png, properties: [:]) else {
    fatalError("Failed to convert image to PNG")
}
let outUrl = URL(fileURLWithPath: CommandLine.arguments[1])
try pngData.write(to: outUrl)
EOF

echo "Generating iconset resolutions..."
sips -z 16 16     "${BASE_PNG}" --out "${ICONSET_DIR}/icon_16x16.png" > /dev/null
sips -z 32 32     "${BASE_PNG}" --out "${ICONSET_DIR}/icon_16x16@2x.png" > /dev/null
sips -z 32 32     "${BASE_PNG}" --out "${ICONSET_DIR}/icon_32x32.png" > /dev/null
sips -z 64 64     "${BASE_PNG}" --out "${ICONSET_DIR}/icon_32x32@2x.png" > /dev/null
sips -z 128 128   "${BASE_PNG}" --out "${ICONSET_DIR}/icon_128x128.png" > /dev/null
sips -z 256 256   "${BASE_PNG}" --out "${ICONSET_DIR}/icon_128x128@2x.png" > /dev/null
sips -z 256 256   "${BASE_PNG}" --out "${ICONSET_DIR}/icon_256x256.png" > /dev/null
sips -z 512 512   "${BASE_PNG}" --out "${ICONSET_DIR}/icon_256x256@2x.png" > /dev/null
sips -z 512 512   "${BASE_PNG}" --out "${ICONSET_DIR}/icon_512x512.png" > /dev/null
cp "${BASE_PNG}" "${ICONSET_DIR}/icon_512x512@2x.png"

echo "Building icns using iconutil..."
iconutil -c icns "${ICONSET_DIR}" -o "${OUTPUT_ICNS}"

echo "Successfully generated ${OUTPUT_ICNS}"
