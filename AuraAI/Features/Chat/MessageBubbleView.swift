//
//  MessageBubbleView.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/26/25.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MessageBubbleView: View {
    let message: Message

    @State private var isHovered = false
    @State private var showCopied = false

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                // Image thumbnails (for user messages with images)
                if !message.images.isEmpty && isUser {
                    HStack(spacing: 6) {
                        ForEach(Array(message.images.enumerated()), id: \.offset) { _, image in
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: message.images.count == 1 ? 200 : 100, height: message.images.count == 1 ? 120 : 70)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                }

                // Generated images (for assistant messages)
                if !message.images.isEmpty && !isUser {
                    VStack(spacing: 8) {
                        ForEach(Array(message.images.enumerated()), id: \.offset) { _, image in
                            GeneratedImageView(image: image)
                        }
                    }
                }

                // Message bubble with hover actions
                ZStack(alignment: isUser ? .topLeading : .topTrailing) {
                    // Message content
                    Group {
                        if message.isStreaming && message.content.isEmpty {
                            TypingIndicator()
                        } else {
                            Text(message.content)
                                .font(.system(size: 14, weight: .regular))
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleBackground)
                    .foregroundColor(isUser ? .white : .white.opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)

                    // Copy button (assistant messages only)
                    if !isUser && isHovered && !message.content.isEmpty && !message.isStreaming {
                        Button(action: copyToClipboard) {
                            Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(.black.opacity(0.4))
                                )
                        }
                        .buttonStyle(.plain)
                        .offset(x: 8, y: -8)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isHovered = hovering
                    }
                }

                // Streaming indicator (shown below bubble when streaming with content)
                if message.isStreaming && !message.content.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(.white.opacity(0.4))
                                .frame(width: 4, height: 4)
                        }
                    }
                    .padding(.leading, 8)
                }
            }

            if !isUser { Spacer(minLength: 60) }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: message.content)
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if isUser {
            // User bubble - vibrant blue gradient
            LinearGradient(
                colors: [Color(red: 0.3, green: 0.5, blue: 1.0), Color(red: 0.4, green: 0.35, blue: 0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // Assistant bubble - frosted dark glass
            ZStack {
                Color.black.opacity(0.5)
                Color.white.opacity(0.05)
            }
            .background(.ultraThinMaterial)
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)

        withAnimation {
            showCopied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopied = false
            }
        }
    }
}

// MARK: - Generated Image View

struct GeneratedImageView: View {
    let image: NSImage
    @State private var isHovered = false
    @State private var showSaved = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 280, maxHeight: 280)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.purple.opacity(0.6), .blue.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: .purple.opacity(0.3), radius: 12, x: 0, y: 4)

            // Save button
            if isHovered {
                Button(action: saveImage) {
                    Image(systemName: showSaved ? "checkmark" : "square.and.arrow.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(.black.opacity(0.6))
                        )
                }
                .buttonStyle(.plain)
                .padding(8)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private func saveImage() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "generated_image.png"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                if let tiffData = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: url)

                    withAnimation {
                        showSaved = true
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            showSaved = false
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Animated Typing Indicator

struct TypingIndicator: View {
    @State private var dot1Active = false
    @State private var dot2Active = false
    @State private var dot3Active = false

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.white.opacity(0.6))
                .frame(width: 6, height: 6)
                .offset(y: dot1Active ? -4 : 0)

            Circle()
                .fill(.white.opacity(0.6))
                .frame(width: 6, height: 6)
                .offset(y: dot2Active ? -4 : 0)

            Circle()
                .fill(.white.opacity(0.6))
                .frame(width: 6, height: 6)
                .offset(y: dot3Active ? -4 : 0)
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
            dot1Active = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                dot2Active = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                dot3Active = true
            }
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
        VStack(spacing: 16) {
            MessageBubbleView(message: Message(role: .user, content: "Hello, how are you?"))
            MessageBubbleView(message: Message(role: .assistant, content: "I'm doing great! How can I help you today?"))
            MessageBubbleView(message: Message(role: .assistant, content: "", isStreaming: true))
        }
        .padding()
    }
    .frame(width: 400, height: 300)
}
