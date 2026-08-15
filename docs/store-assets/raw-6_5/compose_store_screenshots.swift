#!/usr/bin/env swift

import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Slide {
    let number: String
    let headline: String
    let supporting: String
    let rawName: String
    let finalName: String
}

let slides = [
    Slide(number: "01", headline: "1日1回、霧の迷路へ", supporting: "小さな灯りをたよりに、今日の道を歩く", rawName: "01-daily-fog-maze-raw.png", finalName: "01-daily-fog-maze.png"),
    Slide(number: "02", headline: "進んだ道が、今日の結果になる", supporting: "歩いた軌跡を、静かに振り返る", rawName: "02-path-becomes-result-raw.png", finalName: "02-path-becomes-result.png"),
    Slide(number: "03", headline: "迷い方が、あなたをそっと映す", supporting: "上手さではなく、選んだ道の傾向から", rawName: "03-reflection-in-choices-raw.png", finalName: "03-reflection-in-choices.png"),
    Slide(number: "04", headline: "毎日の一歩が、旅の記録になる", supporting: "歩いた日々が、少しずつ積み重なる", rawName: "04-daily-journey-record-raw.png", finalName: "04-daily-journey-record.png"),
    Slide(number: "05", headline: "小さな発見を、少しずつ集める", supporting: "迷路から持ち帰る、八つの小さなもの", rawName: "05-small-discoveries-raw.png", finalName: "05-small-discoveries.png"),
    Slide(number: "06", headline: "今日の結果を、やさしく共有", supporting: "迷路の答えは見せず、旅の余韻だけを", rawName: "06-gentle-sharing-raw.png", finalName: "06-gentle-sharing.png")
]

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let rawDirectory = root.appendingPathComponent("raw-6_5", isDirectory: true)
let finalDirectory = root.appendingPathComponent("final-6_5", isDirectory: true)
try FileManager.default.createDirectory(at: finalDirectory, withIntermediateDirectories: true)

let canvasWidth = 1284
let canvasHeight = 2778
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [red, green, blue, alpha])!
}

func bitmapContext(width: Int, height: Int) -> CGContext {
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue
    ) else {
        fatalError("Could not create bitmap context")
    }
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.interpolationQuality = .high
    return context
}

func loadImage(_ url: URL) -> CGImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        fatalError("Could not decode \(url.path)")
    }
    return image
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Could not create PNG destination at \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, [kCGImagePropertyDPIWidth: 72, kCGImagePropertyDPIHeight: 72] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("Could not write PNG at \(url.path)")
    }
}

func rectFromTop(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, canvasHeight: CGFloat) -> CGRect {
    CGRect(x: x, y: canvasHeight - y - height, width: width, height: height)
}

func drawImageTop(_ image: CGImage, in topRect: CGRect, context: CGContext, canvasHeight: CGFloat) {
    let rect = rectFromTop(x: topRect.minX, y: topRect.minY, width: topRect.width, height: topRect.height, canvasHeight: canvasHeight)
    context.draw(image, in: rect)
}

func aspectFit(source: CGSize, inside rect: CGRect) -> CGRect {
    let scale = min(rect.width / source.width, rect.height / source.height)
    let size = CGSize(width: source.width * scale, height: source.height * scale)
    return CGRect(
        x: rect.midX - size.width / 2,
        y: rect.midY - size.height / 2,
        width: size.width,
        height: size.height
    )
}

func makeLine(text: String, fontSize: CGFloat, weight: NSFont.Weight, textColor: NSColor, kern: CGFloat = 0) -> (CTLine, CGFloat, CGFloat) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
        .foregroundColor: textColor,
        .kern: kern
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    var ascent: CGFloat = 0
    var descent: CGFloat = 0
    var leading: CGFloat = 0
    let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
    return (line, width, ascent)
}

func drawCenteredText(
    _ text: String,
    top: CGFloat,
    preferredSize: CGFloat,
    minimumSize: CGFloat,
    weight: NSFont.Weight,
    textColor: NSColor,
    maxWidth: CGFloat,
    context: CGContext,
    canvasWidth: CGFloat,
    canvasHeight: CGFloat,
    kern: CGFloat = 0
) {
    var size = preferredSize
    var prepared = makeLine(text: text, fontSize: size, weight: weight, textColor: textColor, kern: kern)
    while prepared.1 > maxWidth && size > minimumSize {
        size -= 1
        prepared = makeLine(text: text, fontSize: size, weight: weight, textColor: textColor, kern: kern)
    }
    context.saveGState()
    context.textMatrix = .identity
    context.textPosition = CGPoint(x: (canvasWidth - prepared.1) / 2, y: canvasHeight - top - prepared.2)
    CTLineDraw(prepared.0, context)
    context.restoreGState()
}

func drawBackground(in context: CGContext) {
    let bounds = CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)
    let vertical = CGGradient(
        colorsSpace: colorSpace,
        colors: [color(0.025, 0.043, 0.085), color(0.055, 0.082, 0.145)] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(vertical, start: CGPoint(x: 0, y: canvasHeight), end: .zero, options: [])

    let glow = CGGradient(
        colorsSpace: colorSpace,
        colors: [color(0.72, 0.48, 0.22, 0.13), color(0.72, 0.48, 0.22, 0)] as CFArray,
        locations: [0, 1]
    )!
    context.drawRadialGradient(
        glow,
        startCenter: CGPoint(x: canvasWidth / 2, y: 1180),
        startRadius: 0,
        endCenter: CGPoint(x: canvasWidth / 2, y: 1180),
        endRadius: 820,
        options: [.drawsAfterEndLocation]
    )

    context.setStrokeColor(color(0.84, 0.66, 0.39, 0.25))
    context.setLineWidth(1)
    context.move(to: CGPoint(x: 180, y: canvasHeight - 392))
    context.addLine(to: CGPoint(x: canvasWidth - 180, y: canvasHeight - 392))
    context.strokePath()
    _ = bounds
}

func drawPhone(with screenshot: CGImage, in context: CGContext) {
    let outerTop = CGRect(x: 122, y: 458, width: 1040, height: 2200)
    let screenTop = CGRect(x: 148, y: 484, width: 988, height: 2148)
    let outer = rectFromTop(x: outerTop.minX, y: outerTop.minY, width: outerTop.width, height: outerTop.height, canvasHeight: CGFloat(canvasHeight))
    let screen = rectFromTop(x: screenTop.minX, y: screenTop.minY, width: screenTop.width, height: screenTop.height, canvasHeight: CGFloat(canvasHeight))

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 34, color: color(0, 0, 0, 0.62))
    context.addPath(CGPath(roundedRect: outer, cornerWidth: 112, cornerHeight: 112, transform: nil))
    context.setFillColor(color(0.012, 0.015, 0.024))
    context.fillPath()
    context.restoreGState()

    context.addPath(CGPath(roundedRect: outer, cornerWidth: 112, cornerHeight: 112, transform: nil))
    context.setStrokeColor(color(0.49, 0.43, 0.35, 0.8))
    context.setLineWidth(4)
    context.strokePath()

    let screenPath = CGPath(roundedRect: screen, cornerWidth: 88, cornerHeight: 88, transform: nil)
    context.saveGState()
    context.addPath(screenPath)
    context.clip()
    context.setFillColor(color(0.015, 0.022, 0.042))
    context.fill(screen)

    let fit = aspectFit(
        source: CGSize(width: screenshot.width, height: screenshot.height),
        inside: screenTop
    )
    drawImageTop(screenshot, in: fit, context: context, canvasHeight: CGFloat(canvasHeight))
    context.restoreGState()

    context.addPath(screenPath)
    context.setStrokeColor(color(0.16, 0.17, 0.20))
    context.setLineWidth(3)
    context.strokePath()

    let leftButton1 = rectFromTop(x: 114, y: 790, width: 8, height: 150, canvasHeight: CGFloat(canvasHeight))
    let leftButton2 = rectFromTop(x: 114, y: 990, width: 8, height: 235, canvasHeight: CGFloat(canvasHeight))
    let rightButton = rectFromTop(x: 1162, y: 905, width: 8, height: 300, canvasHeight: CGFloat(canvasHeight))
    context.setFillColor(color(0.20, 0.21, 0.23))
    context.fill(leftButton1)
    context.fill(leftButton2)
    context.fill(rightButton)
}

func render(slide: Slide) {
    let context = bitmapContext(width: canvasWidth, height: canvasHeight)
    drawBackground(in: context)

    drawCenteredText(
        "まいにちの分かれ道",
        top: 68,
        preferredSize: 29,
        minimumSize: 29,
        weight: .semibold,
        textColor: NSColor(calibratedRed: 0.83, green: 0.66, blue: 0.42, alpha: 1),
        maxWidth: 900,
        context: context,
        canvasWidth: CGFloat(canvasWidth),
        canvasHeight: CGFloat(canvasHeight),
        kern: 1.7
    )

    drawCenteredText(
        slide.headline,
        top: 154,
        preferredSize: 70,
        minimumSize: 54,
        weight: .bold,
        textColor: NSColor(calibratedWhite: 0.97, alpha: 1),
        maxWidth: 1120,
        context: context,
        canvasWidth: CGFloat(canvasWidth),
        canvasHeight: CGFloat(canvasHeight),
        kern: -0.5
    )

    drawCenteredText(
        slide.supporting,
        top: 286,
        preferredSize: 31,
        minimumSize: 27,
        weight: .regular,
        textColor: NSColor(calibratedRed: 0.77, green: 0.78, blue: 0.82, alpha: 1),
        maxWidth: 1080,
        context: context,
        canvasWidth: CGFloat(canvasWidth),
        canvasHeight: CGFloat(canvasHeight),
        kern: 0.3
    )

    let screenshot = loadImage(rawDirectory.appendingPathComponent(slide.rawName))
    drawPhone(with: screenshot, in: context)

    guard let image = context.makeImage() else { fatalError("Could not finalize slide \(slide.number)") }
    writePNG(image, to: finalDirectory.appendingPathComponent(slide.finalName))
}

for slide in slides {
    render(slide: slide)
}

func renderContactSheet() {
    let width = 1920
    let height = 2600
    let context = bitmapContext(width: width, height: height)
    context.setFillColor(color(0.02, 0.03, 0.055))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    let cellWidth: CGFloat = 560
    let cellHeight: CGFloat = 1212
    let xPositions: [CGFloat] = [60, 680, 1300]
    let yPositions: [CGFloat] = [60, 1328]
    for (index, slide) in slides.enumerated() {
        let image = loadImage(finalDirectory.appendingPathComponent(slide.finalName))
        let row = index / 3
        let column = index % 3
        drawImageTop(
            image,
            in: CGRect(x: xPositions[column], y: yPositions[row], width: cellWidth, height: cellHeight),
            context: context,
            canvasHeight: CGFloat(height)
        )
    }

    guard let image = context.makeImage() else { fatalError("Could not finalize contact sheet") }
    writePNG(image, to: root.appendingPathComponent("contact-sheet-6_5.png"))
}

renderContactSheet()
print("Rendered 6 screenshots and contact sheet in \(root.path)")
