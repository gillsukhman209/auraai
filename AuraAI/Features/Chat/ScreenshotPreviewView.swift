//
//  ScreenshotPreviewView.swift
//  AuraAI
//
//  Created by Claude on 11/27/25.
//

import AppKit
import SwiftUI

struct ScreenshotPreviewView: View {
    let image: NSImage
    var onRemove: () -> Void

    @State private var isHoveringRemove = false
    @State private var isHoveringImage = false
    @State private var showFullPreview = false

    var body: some View {
        HStack(spacing: 8) {
            // Screenshot thumbnail - clickable to expand
            Button(action: { showFullPreview = true }) {
                ZStack {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    // Hover overlay with expand icon
                    if isHoveringImage {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.black.opacity(0.4))
                            .frame(width: 80, height: 50)

                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .onHover { isHoveringImage = $0 }
            .help("Click to preview")
            .popover(isPresented: $showFullPreview, arrowEdge: .top) {
                ScreenshotFullPreview(image: image)
            }

            // Label
            VStack(alignment: .leading, spacing: 2) {
                Text("Image attached")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))

                Text("Click to preview")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(isHoveringRemove ? .white : .white.opacity(0.5))
            }
            .buttonStyle(.plain)
            .onHover { isHoveringRemove = $0 }
            .help("Remove screenshot")
        }
        .padding(10)
        .background(
            ZStack {
                Color.black.opacity(0.4)
                Color.white.opacity(0.05)
            }
            .background(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Full Screenshot Preview

struct ScreenshotFullPreview: View {
    let image: NSImage

    // Get the actual image pixel dimensions
    private var imagePixelSize: CGSize {
        guard let rep = image.representations.first else {
            return image.size
        }
        return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
    }

    // Calculate preview size to fill screen nicely
    private var previewSize: CGSize {
        let pixelSize = imagePixelSize
        let aspectRatio = pixelSize.width / pixelSize.height

        // Target preview dimensions
        let targetWidth: CGFloat = 900
        let targetHeight: CGFloat = 600

        if aspectRatio > (targetWidth / targetHeight) {
            // Wide image - constrain by width
            let width = targetWidth
            let height = width / aspectRatio
            return CGSize(width: width, height: max(200, height))
        } else {
            // Tall image - constrain by height
            let height = targetHeight
            let width = height * aspectRatio
            return CGSize(width: max(400, width), height: height)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Image Preview")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Text("\(Int(imagePixelSize.width)) × \(Int(imagePixelSize.height))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Image - fills the space properly
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: previewSize.width, height: previewSize.height)
                .padding(16)
        }
        .frame(width: previewSize.width + 32, height: previewSize.height + 70)
        .background(.regularMaterial)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
        ScreenshotPreviewView(
            image: NSImage(systemSymbolName: "photo", accessibilityDescription: nil)!,
            onRemove: {}
        )
        .padding()
    }
    .frame(width: 400, height: 150)
}
