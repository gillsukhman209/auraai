//
//  Message.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/26/25.
//

import AppKit
import Foundation

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

struct Message: Identifiable, Equatable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date
    var isStreaming: Bool
    var image: NSImage?

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        isStreaming: Bool = false,
        image: NSImage? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.image = image
    }

    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id &&
        lhs.role == rhs.role &&
        lhs.content == rhs.content &&
        lhs.timestamp == rhs.timestamp &&
        lhs.isStreaming == rhs.isStreaming &&
        lhs.image === rhs.image
    }
}
