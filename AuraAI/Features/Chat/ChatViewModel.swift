//
//  ChatViewModel.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/26/25.
//

import Foundation
import SwiftUI

@Observable
class ChatViewModel {
    private let openAIService: OpenAIService
    private let clipboardService: ClipboardService

    var conversation: Conversation
    var inputText: String = ""
    var errorMessage: String?
    var isProcessing: Bool = false

    // Quick Actions state
    var showQuickActions: Bool = false
    var clipboardText: String?

    init(
        openAIService: OpenAIService,
        clipboardService: ClipboardService,
        conversation: Conversation
    ) {
        self.openAIService = openAIService
        self.clipboardService = clipboardService
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
        guard !trimmedInput.isEmpty else { return }

        // Hide quick actions if shown
        showQuickActions = false

        // Add user message
        let userMessage = Message(role: .user, content: trimmedInput)
        conversation.addMessage(userMessage)
        inputText = ""

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
