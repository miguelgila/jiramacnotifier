#!/usr/bin/env swift

import Foundation
import AppKit

// Simple script to generate app icon
func generateIcon(size: CGSize, filename: String) {
    let image = NSImage(size: size)
    image.lockFocus()

    // Background gradient (blue to purple)
    let gradient = NSGradient(
        colors: [
            NSColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1.0),
            NSColor(red: 0.5, green: 0.2, blue: 0.8, alpha: 1.0)
        ]
    )!
    gradient.draw(in: NSRect(origin: .zero, size: size), angle: 135)

    // Draw "J" letter
    let fontSize = size.width * 0.6
    let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white
    ]

    let text = "J" as NSString
    let textSize = text.size(withAttributes: attributes)
    let textRect = NSRect(
        x: (size.width - textSize.width) / 2,
        y: (size.height - textSize.height) / 2,
        origin: .zero,
        size: size
    )
    text.draw(in: textRect, withAttributes: attributes)

    // Add a subtle notification bell icon in corner
    let bellSize = size.width * 0.25
    let bellRect = NSRect(
        x: size.width - bellSize - (size.width * 0.1),
        y: size.width * 0.1,
        width: bellSize,
        height: bellSize
    )

    if let bellImage = NSImage(systemSymbolName: "bell.fill", accessibilityDescription: nil) {
        bellImage.draw(
            in: bellRect,
            from: NSRect(origin: .zero, size: bellImage.size),
            operation: .sourceOver,
            fraction: 0.3
        )
    }

    image.unlockFocus()

    // Save as PNG
    if let tiffData = image.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiffData),
       let pngData = bitmap.representation(using: .png, properties: [:]) {
        try? pngData.write(to: URL(fileURLWithPath: filename))
    }
}

// Create icons directory
let iconsDir = "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconsDir, withIntermediateDirectories: true)

// Generate all required icon sizes
let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for (size, filename) in sizes {
    let cgSize = CGSize(width: size, height: size)
    generateIcon(size: cgSize, filename: "\(iconsDir)/\(filename)")
    print("Generated \(filename)")
}

print("Icon generation complete. Run: iconutil -c icns AppIcon.iconset")
