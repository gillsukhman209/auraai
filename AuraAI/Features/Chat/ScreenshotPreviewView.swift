//
//  ScreenshotPreviewView.swift
//  AuraAI
//
//  Created by Claude on 11/27/25.
//

import AppKit
import SwiftUI

// MARK: - Multiple Images Preview

struct ImagesPreviewView: View {
    let images: [NSImage]
    var onRemove: (Int) -> Void
    var onClearAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with count and clear all
            HStack {
                Text("\(images.count) image\(images.count == 1 ? "" : "s") attached")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                if images.count > 1 {
                    Button(action: onClearAll) {
                        Text("Clear all")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }
            }

            // Horizontal scrolling thumbnails
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        ImageThumbnailView(
                            image: image,
                            index: index,
                            onRemove: { onRemove(index) }
                        )
                    }
                }
            }
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

// MARK: - Single Image Thumbnail

struct ImageThumbnailView: View {
    let image: NSImage
    let index: Int
    var onRemove: () -> Void

    @State private var isHovering = false
    @State private var showFullPreview = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Thumbnail - clickable to expand
            Button(action: { showFullPreview = true }) {
                ZStack {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 70, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    // Hover overlay with expand icon
                    if isHovering {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(.black.opacity(0.4))
                            .frame(width: 70, height: 50)

                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }
            .popover(isPresented: $showFullPreview, arrowEdge: .top) {
                ScreenshotFullPreview(image: image)
            }

            // Remove button (always visible)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .background(
                        Circle()
                            .fill(.black.opacity(0.6))
                            .frame(width: 14, height: 14)
                    )
            }
            .buttonStyle(.plain)
            .offset(x: 6, y: -6)
        }
    }
}

// MARK: - Legacy Single Image Preview (for backwards compatibility)

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
        VStack {
            ImagesPreviewView(
                images: [
                    NSImage(systemSymbolName: "photo", accessibilityDescription: nil)!,
                    NSImage(systemSymbolName: "photo.fill", accessibilityDescription: nil)!
                ],
                onRemove: { _ in },
                onClearAll: {}
            )
            .padding()
        }
    }
    .frame(width: 400, height: 200)
}
