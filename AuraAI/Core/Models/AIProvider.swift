//
//  AIProvider.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/26/25.
//

import Foundation

/// Available AI model types
enum AIModelType: String, CaseIterable, Identifiable {
    case gpt51 = "GPT-5.1"
    case gemini = "Gemini"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var iconName: String {
        switch self {
        case .gpt51: return "brain"
        case .gemini: return "sparkles"
        }
    }
}

/// Protocol for AI providers (Claude, GPT, Gemini, etc.)
/// Allows easy addition of new AI models in the future
protocol AIProvider {
    var name: String { get }

    /// Send messages and receive streaming response
    func sendMessage(_ messages: [Message]) async throws -> AsyncThrowingStream<String, Error>
}
