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
