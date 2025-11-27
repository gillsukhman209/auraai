//
//  Conversation.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/26/25.
//

import Foundation

@Observable
class Conversation {
    var messages: [Message] = []
    var isLoading: Bool = false

    func addMessage(_ message: Message) {
        messages.append(message)
    }

    func updateLastMessage(content: String) {
        guard !messages.isEmpty else { return }
        messages[messages.count - 1].content = content
    }

    func setLastMessageStreaming(_ isStreaming: Bool) {
        guard !messages.isEmpty else { return }
        messages[messages.count - 1].isStreaming = isStreaming
    }

    func clear() {
        messages.removeAll()
    }
}
