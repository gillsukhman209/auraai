//
//  ChatViewModel.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/26/25.
//

import AppKit
import Foundation
import SwiftUI

@Observable
class ChatViewModel {
    private let openAIService: OpenAIService
    private let clipboardService: ClipboardService
    private let screenshotService: ScreenshotService
    private weak var panelController: FloatingPanelController?

    var conversation: Conversation
    var inputText: String = ""
    var errorMessage: String?
    var isProcessing: Bool = false

    // Quick Actions state
    var showQuickActions: Bool = false
    var clipboardText: String?

    // Screenshot state
    var pendingScreenshot: NSImage?

    init(
        openAIService: OpenAIService,
        clipboardService: ClipboardService,
        screenshotService: ScreenshotService = .shared,
        panelController: FloatingPanelController? = nil,
        conversation: Conversation
    ) {
        self.openAIService = openAIService
        self.clipboardService = clipboardService
        self.screenshotService = screenshotService
        self.panelController = panelController
        self.conversation = conversation
    }

    /// Check clipboard and show quick actions if text is available
    func checkClipboardForQuickActions() {
        if let text = clipboardService.readText(),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           conversation.messages.isEmpty {
            clipboardText = text
            showQuickActions = true
        }
    }

    /// Execute a quick action with clipboard text
    @MainActor
    func executeQuickAction(_ action: QuickAction) async {
        guard let text = clipboardText else { return }

        showQuickActions = false
        inputText = action.prompt + text
        await sendMessage()
    }

    /// Dismiss quick actions
    func dismissQuickActions() {
        showQuickActions = false
    }

    @MainActor
    func sendMessage() async {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Allow sending with just a screenshot (no text required)
        guard !trimmedInput.isEmpty || pendingScreenshot != nil else { return }

        // Hide quick actions if shown
        showQuickActions = false

        // Add user message with optional screenshot
        let userMessage = Message(
            role: .user,
            content: trimmedInput.isEmpty ? "What's in this screenshot?" : trimmedInput,
            image: pendingScreenshot
        )
        conversation.addMessage(userMessage)
        inputText = ""
        pendingScreenshot = nil

        // Create placeholder for assistant response
        let assistantMessage = Message(role: .assistant, content: "", isStreaming: true)
        conversation.addMessage(assistantMessage)

        isProcessing = true
        errorMessage = nil

        do {
            let stream = try await openAIService.sendMessage(
                Array(conversation.messages.dropLast())
            )

            var fullResponse = ""
            for try await chunk in stream {
                fullResponse += chunk
                conversation.updateLastMessage(content: fullResponse)
            }

            // Mark as complete
            conversation.setLastMessageStreaming(false)
        } catch {
            errorMessage = error.localizedDescription
            // Remove the empty assistant message on error
            if conversation.messages.last?.content.isEmpty == true {
                conversation.messages.removeLast()
            }
        }

        isProcessing = false
    }

    // MARK: - Screenshot Methods

    /// Capture a screenshot of the full screen (excludes the AuraAI panel automatically)
    @MainActor
    func captureScreenshot() async {
        do {
            // Capture screenshot - AuraAI windows are automatically excluded
            let image = try await screenshotService.captureFullScreen()
            pendingScreenshot = image
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Clear the pending screenshot
    func clearScreenshot() {
        pendingScreenshot = nil
    }

    // MARK: - Drag & Drop Methods

    /// Supported image types for drag and drop
    static let supportedImageTypes: [String] = [
        "public.png", "public.jpeg", "public.heic", "public.gif",
        "public.tiff", "public.bmp", "com.apple.icns"
    ]

    /// Handle dropped image files
    func handleDroppedImage(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            // Check for file URL first
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { [weak self] item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil),
                          let image = NSImage(contentsOf: url) else { return }

                    // Resize if needed
                    let resizedImage = self?.resizeImageIfNeeded(image, maxDimension: 2048) ?? image

                    DispatchQueue.main.async {
                        self?.pendingScreenshot = resizedImage
                    }
                }
                return true
            }

            // Check for image data directly
            for imageType in Self.supportedImageTypes {
                if provider.hasItemConformingToTypeIdentifier(imageType) {
                    provider.loadItem(forTypeIdentifier: imageType, options: nil) { [weak self] item, _ in
                        var image: NSImage?

                        if let data = item as? Data {
                            image = NSImage(data: data)
                        } else if let url = item as? URL {
                            image = NSImage(contentsOf: url)
                        }

                        guard let loadedImage = image else { return }

                        let resizedImage = self?.resizeImageIfNeeded(loadedImage, maxDimension: 2048) ?? loadedImage

                        DispatchQueue.main.async {
                            self?.pendingScreenshot = resizedImage
                        }
                    }
                    return true
                }
            }
        }
        return false
    }

    /// Resize image if larger than max dimension
    private func resizeImageIfNeeded(_ image: NSImage, maxDimension: CGFloat) -> NSImage {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else { return image }

        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = NSSize(width: size.width * ratio, height: size.height * ratio)

        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }

    func pasteFromClipboard() {
        if let text = clipboardService.readText(),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            clipboardText = text
            showQuickActions = true
        }
    }

    func processClipboard() async {
        if let text = clipboardService.readText() {
            inputText = "Please help me with this:\n\n\(text)"
            await sendMessage()
        }
    }

    func clearConversation() {
        conversation.clear()
        errorMessage = nil
        // Check clipboard again for quick actions
        checkClipboardForQuickActions()
    }
}
