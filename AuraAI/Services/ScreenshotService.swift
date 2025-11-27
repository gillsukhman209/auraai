//
//  ScreenshotService.swift
//  AuraAI
//
//  Created by Claude on 11/27/25.
//

import AppKit
import ScreenCaptureKit

final class ScreenshotService {
    static let shared = ScreenshotService()

    private init() {}

    enum ScreenshotError: LocalizedError {
        case captureFailure
        case noDisplay
        case permissionDenied
        case noContent
        case cancelled

        var errorDescription: String? {
            switch self {
            case .captureFailure:
                return "Failed to capture screenshot"
            case .noDisplay:
                return "No display found"
            case .permissionDenied:
                return "Screen recording permission required. Please enable in System Settings > Privacy & Security > Screen Recording"
            case .noContent:
                return "No shareable content available"
            case .cancelled:
                return "Screenshot capture was cancelled"
            }
        }
    }

    /// Check if we have screen recording permission
    func checkPermission() async -> Bool {
        do {
            // This will prompt for permission if not already granted
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return !content.displays.isEmpty
        } catch {
            return false
        }
    }

    /// Capture the full screen using ScreenCaptureKit
    /// - Parameter excludeWindowWithTitle: Optional window title to exclude from capture (e.g., the app's own window)
    func captureFullScreen(excludeWindowWithTitle: String? = nil) async throws -> NSImage {
        // Get shareable content (this requests permission if needed)
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            throw ScreenshotError.permissionDenied
        }

        // Get the main display
        guard let display = content.displays.first else {
            throw ScreenshotError.noDisplay
        }

        // Find windows to exclude (our own app window)
        var excludedWindows: [SCWindow] = []
        if let titleToExclude = excludeWindowWithTitle {
            excludedWindows = content.windows.filter { window in
                window.title?.contains(titleToExclude) == true ||
                window.owningApplication?.applicationName == "AuraAI"
            }
        } else {
            // Always try to exclude AuraAI windows
            excludedWindows = content.windows.filter { window in
                window.owningApplication?.applicationName == "AuraAI"
            }
        }

        // Create a filter for the entire display, excluding our window
        let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)

        // Configure the screenshot
        let configuration = SCStreamConfiguration()
        configuration.width = display.width * 2  // Retina resolution
        configuration.height = display.height * 2
        configuration.showsCursor = false
        configuration.captureResolution = .best

        // Capture the screenshot
        let image: CGImage
        do {
            image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
        } catch {
            throw ScreenshotError.captureFailure
        }

        // Convert to NSImage
        let nsImage = NSImage(cgImage: image, size: NSSize(
            width: image.width,
            height: image.height
        ))

        // Resize if too large (for API efficiency)
        return resizeIfNeeded(nsImage, maxDimension: 2048)
    }

    /// Capture a user-selected area using macOS native screencapture tool
    /// Shows the familiar crosshair selection UI
    func captureSelectedArea() async throws -> NSImage {
        // Create a temporary file for the screenshot
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")

        // Use screencapture command with interactive selection mode
        // -i = interactive (selection or window)
        // -s = selection mode only (drag to select area)
        // -x = no sound
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-x", tempURL.path]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw ScreenshotError.captureFailure
        }

        // Check if user cancelled (file won't exist)
        guard FileManager.default.fileExists(atPath: tempURL.path) else {
            throw ScreenshotError.cancelled
        }

        // Load the screenshot
        guard let image = NSImage(contentsOf: tempURL) else {
            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)
            throw ScreenshotError.captureFailure
        }

        // Clean up temp file
        try? FileManager.default.removeItem(at: tempURL)

        // Resize if too large (for API efficiency)
        return resizeIfNeeded(image, maxDimension: 2048)
    }

    /// Resize image if larger than max dimension while maintaining aspect ratio
    private func resizeIfNeeded(_ image: NSImage, maxDimension: CGFloat) -> NSImage {
        let size = image.size

        // Check if resize is needed
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }

        // Calculate new size maintaining aspect ratio
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = NSSize(
            width: size.width * ratio,
            height: size.height * ratio
        )

        // Create resized image
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1.0
        )
        newImage.unlockFocus()

        return newImage
    }

    /// Convert NSImage to base64 PNG string for API
    func imageToBase64(_ image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return nil
        }

        return pngData.base64EncodedString()
    }
}
