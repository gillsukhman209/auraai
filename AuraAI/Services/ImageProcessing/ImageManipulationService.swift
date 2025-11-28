//
//  ImageManipulationService.swift
//  AuraAI
//
//  Created by Claude on 11/27/25.
//

import AppKit
import Foundation

// MARK: - Manipulation Types

enum ManipulationType: Equatable {
    case resize(NSSize)
    case scale(CGFloat)  // percentage e.g., 0.5 for 50%
    case rotate(CGFloat) // degrees
    case flipHorizontal
    case flipVertical
    case convertFormat(ImageFormat)
    case crop(NSRect)
}

enum ImageFormat: String, CaseIterable {
    case png = "PNG"
    case jpeg = "JPEG"
    case heic = "HEIC"
    case tiff = "TIFF"

    var fileExtension: String {
        rawValue.lowercased()
    }

    var mimeType: String {
        switch self {
        case .png: return "image/png"
        case .jpeg: return "image/jpeg"
        case .heic: return "image/heic"
        case .tiff: return "image/tiff"
        }
    }

    var bitmapType: NSBitmapImageRep.FileType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .heic: return .jpeg // Fallback - HEIC needs special handling
        case .tiff: return .tiff
        }
    }
}

// MARK: - Manipulation Result

struct ManipulationResult {
    let originalImage: NSImage
    let processedImage: NSImage
    let originalSize: NSSize
    let newSize: NSSize
    let format: ImageFormat
    let operations: [String]

    var sizeDescription: String {
        let origW = Int(originalSize.width)
        let origH = Int(originalSize.height)
        let newW = Int(newSize.width)
        let newH = Int(newSize.height)

        if origW == newW && origH == newH {
            return "\(newW) x \(newH)"
        }
        return "\(origW) x \(origH) → \(newW) x \(newH)"
    }
}

// MARK: - Service

actor ImageManipulationService {
    static let shared = ImageManipulationService()

    private init() {}

    // MARK: - Intent Detection

    /// Detect manipulation intent from user message
    func detectIntent(from message: String) -> ManipulationType? {
        let lowercased = message.lowercased()

        // Check for resize with dimensions
        if let size = parseDimensions(from: message) {
            return .resize(size)
        }

        // Check for scale percentage
        if let scale = parseScalePercentage(from: message) {
            return .scale(scale)
        }

        // Check for rotation
        if let degrees = parseRotation(from: message) {
            return .rotate(degrees)
        }

        // Check for flip
        if lowercased.contains("flip horizontal") || lowercased.contains("mirror horizontal") {
            return .flipHorizontal
        }
        if lowercased.contains("flip vertical") || lowercased.contains("mirror vertical") {
            return .flipVertical
        }
        if lowercased.contains("flip") || lowercased.contains("mirror") {
            return .flipHorizontal // Default to horizontal
        }

        // Check for format conversion
        if let format = parseFormat(from: message) {
            return .convertFormat(format)
        }

        return nil
    }

    /// Check if message contains manipulation keywords (quick check before full parse)
    func containsManipulationKeywords(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        let keywords = [
            "resize", "scale", "crop", "rotate", "flip", "mirror",
            "convert to", "save as", "export as", "make it",
            "change size", "dimensions", "format", "compress",
            "smaller", "bigger", "larger", "half", "double",
            "turn", "90", "180", "270"
        ]
        return keywords.contains { lowercased.contains($0) }
    }

    // MARK: - Parsing Helpers

    /// Parse dimensions from text: "1024x1024", "1024 x 1024", "1024 by 1024", "1024x768"
    private func parseDimensions(from text: String) -> NSSize? {
        let patterns = [
            #"(\d+)\s*[xX×]\s*(\d+)"#,           // 1024x1024, 1024 x 1024
            #"(\d+)\s*by\s*(\d+)"#,               // 1024 by 768
            #"(\d+)\s*px?\s*[xX×]\s*(\d+)\s*px?"# // 1024px x 768px
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let widthRange = Range(match.range(at: 1), in: text),
               let heightRange = Range(match.range(at: 2), in: text),
               let width = Double(text[widthRange]),
               let height = Double(text[heightRange]) {
                return NSSize(width: width, height: height)
            }
        }

        return nil
    }

    /// Parse scale percentage: "50%", "half size", "double"
    private func parseScalePercentage(from text: String) -> CGFloat? {
        let lowercased = text.lowercased()

        // Named scales
        if lowercased.contains("half") || lowercased.contains("50%") {
            return 0.5
        }
        if lowercased.contains("quarter") || lowercased.contains("25%") {
            return 0.25
        }
        if lowercased.contains("double") || lowercased.contains("200%") {
            return 2.0
        }

        // Percentage pattern
        let pattern = #"(\d+)\s*%"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
           let percentRange = Range(match.range(at: 1), in: text),
           let percent = Double(text[percentRange]) {
            return CGFloat(percent / 100.0)
        }

        return nil
    }

    /// Parse rotation degrees: "90 degrees", "rotate right", "turn left"
    private func parseRotation(from text: String) -> CGFloat? {
        let lowercased = text.lowercased()

        // Specific degrees
        if lowercased.contains("90") {
            if lowercased.contains("left") || lowercased.contains("counter") {
                return -90
            }
            return 90
        }
        if lowercased.contains("180") {
            return 180
        }
        if lowercased.contains("270") || (lowercased.contains("90") && lowercased.contains("left")) {
            return 270
        }

        // Direction-based
        if lowercased.contains("rotate right") || lowercased.contains("turn right") {
            return 90
        }
        if lowercased.contains("rotate left") || lowercased.contains("turn left") {
            return -90
        }

        return nil
    }

    /// Parse format from text: "convert to png", "save as jpeg"
    private func parseFormat(from text: String) -> ImageFormat? {
        let lowercased = text.lowercased()

        if lowercased.contains("png") {
            return .png
        }
        if lowercased.contains("jpg") || lowercased.contains("jpeg") {
            return .jpeg
        }
        if lowercased.contains("heic") || lowercased.contains("heif") {
            return .heic
        }
        if lowercased.contains("tiff") || lowercased.contains("tif") {
            return .tiff
        }

        return nil
    }

    // MARK: - Image Operations

    /// Process image with the detected manipulation type
    func process(_ image: NSImage, manipulation: ManipulationType) -> ManipulationResult {
        let originalSize = image.size
        var processedImage: NSImage
        var operations: [String] = []
        var format: ImageFormat = .png

        switch manipulation {
        case .resize(let targetSize):
            processedImage = resize(image, to: targetSize)
            operations.append("Resized to \(Int(targetSize.width)) x \(Int(targetSize.height))")

        case .scale(let factor):
            let newSize = NSSize(
                width: originalSize.width * factor,
                height: originalSize.height * factor
            )
            processedImage = resize(image, to: newSize)
            let percentage = Int(factor * 100)
            operations.append("Scaled to \(percentage)%")

        case .rotate(let degrees):
            processedImage = rotate(image, degrees: degrees)
            operations.append("Rotated \(Int(degrees))°")

        case .flipHorizontal:
            processedImage = flip(image, horizontal: true)
            operations.append("Flipped horizontally")

        case .flipVertical:
            processedImage = flip(image, horizontal: false)
            operations.append("Flipped vertically")

        case .convertFormat(let targetFormat):
            processedImage = image
            format = targetFormat
            operations.append("Converted to \(targetFormat.rawValue)")

        case .crop(let rect):
            processedImage = crop(image, to: rect)
            operations.append("Cropped to \(Int(rect.width)) x \(Int(rect.height))")
        }

        return ManipulationResult(
            originalImage: image,
            processedImage: processedImage,
            originalSize: originalSize,
            newSize: processedImage.size,
            format: format,
            operations: operations
        )
    }

    /// Resize image to exact dimensions
    private func resize(_ image: NSImage, to targetSize: NSSize) -> NSImage {
        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()

        NSGraphicsContext.current?.imageInterpolation = .high

        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )

        newImage.unlockFocus()
        return newImage
    }

    /// Rotate image by degrees
    private func rotate(_ image: NSImage, degrees: CGFloat) -> NSImage {
        let radians = degrees * .pi / 180
        let size = image.size

        // Calculate new bounds after rotation
        let sinVal = abs(sin(radians))
        let cosVal = abs(cos(radians))
        let newWidth = size.width * cosVal + size.height * sinVal
        let newHeight = size.width * sinVal + size.height * cosVal
        let newSize = NSSize(width: newWidth, height: newHeight)

        let newImage = NSImage(size: newSize)
        newImage.lockFocus()

        let transform = NSAffineTransform()
        transform.translateX(by: newSize.width / 2, yBy: newSize.height / 2)
        transform.rotate(byDegrees: degrees)
        transform.translateX(by: -size.width / 2, yBy: -size.height / 2)
        transform.concat()

        image.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1.0
        )

        newImage.unlockFocus()
        return newImage
    }

    /// Flip image horizontally or vertically
    private func flip(_ image: NSImage, horizontal: Bool) -> NSImage {
        let size = image.size
        let newImage = NSImage(size: size)
        newImage.lockFocus()

        let transform = NSAffineTransform()
        if horizontal {
            transform.translateX(by: size.width, yBy: 0)
            transform.scaleX(by: -1, yBy: 1)
        } else {
            transform.translateX(by: 0, yBy: size.height)
            transform.scaleX(by: 1, yBy: -1)
        }
        transform.concat()

        image.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1.0
        )

        newImage.unlockFocus()
        return newImage
    }

    /// Crop image to specified rect
    private func crop(_ image: NSImage, to rect: NSRect) -> NSImage {
        let newImage = NSImage(size: rect.size)
        newImage.lockFocus()

        image.draw(
            in: NSRect(origin: .zero, size: rect.size),
            from: rect,
            operation: .copy,
            fraction: 1.0
        )

        newImage.unlockFocus()
        return newImage
    }

    // MARK: - Export

    /// Convert image to data in specified format
    func export(_ image: NSImage, as format: ImageFormat, quality: CGFloat = 0.9) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        var properties: [NSBitmapImageRep.PropertyKey: Any] = [:]
        if format == .jpeg {
            properties[.compressionFactor] = quality
        }

        return bitmap.representation(using: format.bitmapType, properties: properties)
    }
}
