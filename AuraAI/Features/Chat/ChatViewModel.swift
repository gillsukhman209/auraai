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
    private let imageManipulationService = ImageManipulationService.shared
    private let dictionaryService = DictionaryService.shared
    private let calculatorService = CalculatorService.shared
    private weak var panelController: FloatingPanelController?

    var conversation: Conversation
    var inputText: String = ""
    var errorMessage: String?
    var isProcessing: Bool = false

    // Model selection
    var selectedModel: AIModelType = .gpt51

    // Quick Actions state
    var showQuickActions: Bool = false
    var clipboardText: String?

    // Dictionary quick action - shown when clipboard contains a single word
    var showDefineAction: Bool = false
    var clipboardWord: String?

    // Live calculator preview - shows result as user types
    var liveCalculatorPreview: CalculatorResult? {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return calculatorService.detect(trimmed)
    }

    // Transform text state (shown when Cmd+Shift+T captures text)
    var showTransformMenu: Bool = false
    var textToTransform: String?

    // Multiple images state (screenshots + drag & drop)
    var pendingImages: [NSImage] = []

    // Clipboard monitoring
    private var lastPasteboardChangeCount: Int = 0
    private var clipboardTimer: Timer?

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
        case .gpt51:
            return openAIService
        case .gemini:
            return geminiService
        }
    }

    /// Start monitoring clipboard for changes
    func startClipboardMonitoring() {
        lastPasteboardChangeCount = NSPasteboard.general.changeCount
        checkClipboardForQuickActions()

        // Check clipboard every 0.5 seconds for changes
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboardIfChanged()
        }
    }

    /// Stop monitoring clipboard
    func stopClipboardMonitoring() {
        clipboardTimer?.invalidate()
        clipboardTimer = nil
    }

    /// Check clipboard only if it has changed
    private func checkClipboardIfChanged() {
        let currentCount = NSPasteboard.general.changeCount
        if currentCount != lastPasteboardChangeCount {
            lastPasteboardChangeCount = currentCount
            checkClipboardForQuickActions()
        }
    }

    /// Check clipboard and show quick actions if text is available
    func checkClipboardForQuickActions() {
        // Don't show quick actions if already processing
        guard !isProcessing else {
            showQuickActions = false
            showDefineAction = false
            return
        }

        guard let text = clipboardService.readText(),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showQuickActions = false
            showDefineAction = false
            return
        }

        // Check if it's a single word - show Define action
        if dictionaryService.isSingleWord(text) {
            clipboardWord = text.trimmingCharacters(in: .whitespacesAndNewlines)
            showDefineAction = true
            showQuickActions = false
        } else if conversation.messages.isEmpty {
            // Multi-word text - show regular quick actions only if conversation is empty
            clipboardText = text
            showQuickActions = true
            showDefineAction = false
        } else {
            // Conversation has messages and not a single word
            showQuickActions = false
            showDefineAction = false
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
        showDefineAction = false
    }

    /// Execute dictionary lookup for clipboard word
    @MainActor
    func executeDefineAction() async {
        guard let word = clipboardWord else { return }
        showDefineAction = false
        await defineWord(word)
    }

    /// Define a word using AI (gpt-5-nano) for clean, understandable definitions
    @MainActor
    func defineWord(_ word: String) async {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedWord.isEmpty else { return }

        // Add user message
        let userMessage = Message(role: .user, content: "define \(trimmedWord)")
        conversation.addMessage(userMessage)

        // Create streaming assistant message
        let assistantMessage = Message(role: .assistant, content: "", isStreaming: true)
        conversation.addMessage(assistantMessage)

        isProcessing = true
        errorMessage = nil

        do {
            let stream = try await openAIService.getDefinition(for: trimmedWord)

            var fullResponse = ""
            for try await chunk in stream {
                fullResponse += chunk
                conversation.updateLastMessage(content: fullResponse)
            }

            conversation.setLastMessageStreaming(false)
        } catch {
            errorMessage = error.localizedDescription
            // Remove the empty assistant message on error, try local dictionary as fallback
            if conversation.messages.last?.content.isEmpty == true {
                conversation.messages.removeLast()
            }
            // Fallback to local macOS dictionary
            if let result = dictionaryService.define(trimmedWord) {
                let fallbackMessage = Message(role: .assistant, content: result.formattedResponse)
                conversation.addMessage(fallbackMessage)
            } else {
                let fallbackMessage = Message(role: .assistant, content: "Could not find a definition for \"\(trimmedWord)\".")
                conversation.addMessage(fallbackMessage)
            }
        }

        isProcessing = false
    }

    // MARK: - Text Transform Methods

    /// Show transform menu with the given text
    func showTransform(for text: String) {
        textToTransform = text
        showTransformMenu = true
    }

    /// Dismiss transform menu
    func dismissTransformMenu() {
        showTransformMenu = false
        textToTransform = nil
    }

    /// Transform text using selected action
    @MainActor
    func transformText(_ text: String, action: TransformAction) async {
        showTransformMenu = false
        textToTransform = nil

        // Show full text in UI so user can verify everything is captured
        let userMessage = Message(role: .user, content: "\(action.name): \"\(text)\"")
        conversation.addMessage(userMessage)

        // Create streaming assistant message
        let assistantMessage = Message(role: .assistant, content: "", isStreaming: true)
        conversation.addMessage(assistantMessage)

        isProcessing = true
        errorMessage = nil

        do {
            // Build the full prompt
            let fullPrompt = action.prompt + text

            // Create a temporary message for the API call
            let apiMessages = [Message(role: .user, content: fullPrompt)]

            let stream = try await currentProvider.sendMessage(apiMessages)

            var fullResponse = ""
            for try await chunk in stream {
                fullResponse += chunk
                conversation.updateLastMessage(content: fullResponse)
            }

            conversation.setLastMessageStreaming(false)
        } catch {
            errorMessage = error.localizedDescription
            if conversation.messages.last?.content.isEmpty == true {
                conversation.messages.removeLast()
            }
        }

        isProcessing = false
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
        showDefineAction = false

        // Check for calculator/conversion (instant, no API call) - only if no images
        if pendingImages.isEmpty,
           let calcResult = calculatorService.detect(trimmedInput) {
            handleCalculatorResult(calcResult, originalInput: trimmedInput)
            inputText = ""
            return
        }

        // Check for dictionary request FIRST (before API call) - only if no images
        if pendingImages.isEmpty,
           let wordToDefine = dictionaryService.extractWordToDefine(from: trimmedInput) {
            inputText = ""
            await defineWord(wordToDefine)
            return
        }

        // Check for local image manipulation intent
        if !pendingImages.isEmpty,
           await imageManipulationService.containsManipulationKeywords(trimmedInput),
           let manipulation = await imageManipulationService.detectIntent(from: trimmedInput) {
            await handleLocalImageManipulation(message: trimmedInput, manipulation: manipulation)
            return
        }

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

    // MARK: - Calculator Result Handler

    /// Handle instant calculator/conversion result (no API call)
    @MainActor
    private func handleCalculatorResult(_ result: CalculatorResult, originalInput: String) {
        // Add user message
        let userMessage = Message(role: .user, content: originalInput)
        conversation.addMessage(userMessage)

        // Add instant response
        let assistantMessage = Message(role: .assistant, content: result.formattedResponse)
        conversation.addMessage(assistantMessage)
    }

    // MARK: - Local Image Manipulation

    @MainActor
    private func handleLocalImageManipulation(message: String, manipulation: ManipulationType) async {
        guard !pendingImages.isEmpty else { return }

        // Add user message with the image
        let userMessage = Message(
            role: .user,
            content: message,
            images: pendingImages
        )
        conversation.addMessage(userMessage)

        let imagesToProcess = pendingImages
        inputText = ""
        pendingImages = []

        isProcessing = true
        errorMessage = nil

        // Process the image locally
        let result = await imageManipulationService.process(imagesToProcess.first!, manipulation: manipulation)

        // Create assistant response with the manipulation result
        let operationSummary = result.operations.joined(separator: ", ")
        let assistantMessage = Message(
            role: .assistant,
            content: "Done! \(operationSummary)",
            images: [result.processedImage],
            manipulationResult: result
        )
        conversation.addMessage(assistantMessage)

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
        showDefineAction = false
        clipboardWord = nil
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
