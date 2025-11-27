//
//  AIProvider.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/26/25.
//

import Foundation

/// Protocol for AI providers (Claude, GPT, Gemini, etc.)
/// Allows easy addition of new AI models in the future
protocol AIProvider {
    var name: String { get }

    /// Send messages and receive streaming response
    func sendMessage(_ messages: [Message]) async throws -> AsyncThrowingStream<String, Error>
}
