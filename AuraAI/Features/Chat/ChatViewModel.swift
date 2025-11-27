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
    private let geminiService: GeminiService
    private let clipboardService: ClipboardService
    private let screenshotService: ScreenshotService
    private weak var panelController: FloatingPanelController?

    var conversation: Conversation
    var inputText: String = ""
    var errorMessage: String?
    var isProcessing: Bool = false

    // Model selection
    var selectedModel: AIModelType = .gpt4o

    // Quick Actions state
    var showQuickActions: Bool = false
    var clipboardText: String?

    // Multiple images state (screenshots + drag & drop)
    var pendingImages: [NSImage] = []

    init(
        openAIService: OpenAIService,
        geminiService: GeminiService,
        clipboardService: ClipboardService,
        screenshotService: ScreenshotService = .shared,
        panelController: FloatingPanelController? = nil,
        conversation: Conversation
    ) {
        self.openAIService = openAIService
        self.geminiService = geminiService
        self.clipboardService = clipboardService
        self.screenshotService = screenshotService
        self.panelController = panelController
        self.conversation = conversation
    }

    /// Get the currently selected AI provider
    private var currentProvider: any AIProvider {
        switch selectedModel {
        case .gpt4o:
            return openAIService
        case .gemini:
            return geminiService
        }
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

    /// Quick action to explain pending images
    @MainActor
    func explainImages() async {
        guard !pendingImages.isEmpty else { return }
        inputText = "Explain what's in this image"
        await sendMessage()
    }

    @MainActor
    func sendMessage() async {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Allow sending with just images (no text required)
        guard !trimmedInput.isEmpty || !pendingImages.isEmpty else { return }

        // Hide quick actions if shown
        showQuickActions = false

        // Add user message with optional images
        let imageCount = pendingImages.count
        let defaultPrompt = imageCount == 1 ? "What's in this image?" : "What's in these \(imageCount) images?"
        let userMessage = Message(
            role: .user,
            content: trimmedInput.isEmpty ? defaultPrompt : trimmedInput,
            images: pendingImages
        )
        conversation.addMessage(userMessage)
        inputText = ""
        pendingImages = []

        // Create placeholder for assistant response
        let assistantMessage = Message(role: .assistant, content: "", isStreaming: true)
        conversation.addMessage(assistantMessage)

        isProcessing = true
        errorMessage = nil

        do {
            let stream = try await currentProvider.sendMessage(
                Array(conversation.messages.dropLast())
            )

            var fullResponse = ""
            for try await chunk in stream {
                fullResponse += chunk

                // Check for generated image marker
                let (processedText, extractedImage) = parseGeneratedImage(from: fullResponse)
                if let image = extractedImage {
                    conversation.addImageToLastMessage(image)
                    fullResponse = processedText
                }

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

    // MARK: - Screenshot/Image Methods

    /// Capture a screenshot and add to pending images
    @MainActor
    func captureScreenshot() async {
        do {
            // Capture screenshot - AuraAI windows are automatically excluded
            let image = try await screenshotService.captureSelectedArea()
            pendingImages.append(image)
        } catch ScreenshotService.ScreenshotError.cancelled {
            // User cancelled - do nothing
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Add an image to pending images
    func addImage(_ image: NSImage) {
        pendingImages.append(image)
    }

    /// Remove a specific image by index
    func removeImage(at index: Int) {
        guard index >= 0 && index < pendingImages.count else { return }
        pendingImages.remove(at: index)
    }

    /// Clear all pending images
    func clearAllImages() {
        pendingImages = []
    }

    // MARK: - Drag & Drop Methods

    /// Supported image types for drag and drop
    static let supportedImageTypes: [String] = [
        "public.png", "public.jpeg", "public.heic", "public.gif",
        "public.tiff", "public.bmp", "com.apple.icns"
    ]

    /// Handle dropped image files - supports multiple images
    func handleDroppedImage(providers: [NSItemProvider]) -> Bool {
        var handled = false

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
                        self?.pendingImages.append(resizedImage)
                    }
                }
                handled = true
                continue
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
                            self?.pendingImages.append(resizedImage)
                        }
                    }
                    handled = true
                    break
                }
            }
        }
        return handled
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

    // MARK: - Generated Image Parsing

    /// Parse generated image marker from response and extract the image
    /// Returns the cleaned text (without the marker) and the extracted image if found
    private func parseGeneratedImage(from text: String) -> (String, NSImage?) {
        let pattern = "\\[GENERATED_IMAGE:([A-Za-z0-9+/=]+)\\]"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
              let base64Range = Range(match.range(at: 1), in: text) else {
            return (text, nil)
        }

        let base64String = String(text[base64Range])

        // Convert base64 to image
        guard let imageData = Data(base64Encoded: base64String),
              let image = NSImage(data: imageData) else {
            return (text, nil)
        }

        // Remove the marker from text
        let cleanedText = text.replacingOccurrences(
            of: "\\[GENERATED_IMAGE:[A-Za-z0-9+/=]+\\]",
            with: "",
            options: .regularExpression
        )

        return (cleanedText, image)
    }
}
