//
//  OpenAIModels.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/26/25.
//

import Foundation

// MARK: - Request Models

struct OpenAIChatRequest: Encodable {
    let model: String
    let messages: [OpenAIChatMessage]
    let maxTokens: Int?
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case stream
    }
}

struct OpenAIChatMessage: Codable {
    let role: String
    let content: String
}

// MARK: - Response Models (for non-streaming)

struct OpenAIChatResponse: Decodable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: OpenAIUsage?

    struct Choice: Decodable {
        let index: Int
        let message: OpenAIChatMessage?
        let delta: DeltaMessage?
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index
            case message
            case delta
            case finishReason = "finish_reason"
        }
    }
}

struct DeltaMessage: Decodable {
    let role: String?
    let content: String?
}

struct OpenAIUsage: Decodable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

// MARK: - Streaming Models

struct OpenAIStreamChunk: Decodable {
    let id: String?
    let object: String?
    let created: Int?
    let model: String?
    let choices: [StreamChoice]?

    struct StreamChoice: Decodable {
        let index: Int?
        let delta: DeltaMessage?
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index
            case delta
            case finishReason = "finish_reason"
        }
    }
}

// MARK: - Error Models

struct OpenAIErrorResponse: Decodable {
    let error: OpenAIError

    struct OpenAIError: Decodable {
        let message: String
        let type: String
        let code: String?
    }
}
