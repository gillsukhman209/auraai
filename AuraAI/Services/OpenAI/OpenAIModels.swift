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
    let maxCompletionTokens: Int?
    let stream: Bool
    let tools: [OpenAITool]?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxCompletionTokens = "max_completion_tokens"
        case stream
        case tools
    }
}

// MARK: - Tool Definitions

struct OpenAITool: Encodable {
    let type: String = "function"
    let function: OpenAIFunctionDefinition
}

struct OpenAIFunctionDefinition: Encodable {
    let name: String
    let description: String
    let parameters: OpenAIFunctionParameters
}

struct OpenAIFunctionParameters: Encodable {
    let type: String = "object"
    let properties: [String: OpenAIParameterProperty]
    let required: [String]
}

struct OpenAIParameterProperty: Encodable {
    let type: String
    let description: String
}

// Simple text-only message
struct OpenAIChatMessage: Codable {
    let role: String
    let content: String
}

// Vision API request with image support
struct OpenAIVisionRequest: Encodable {
    let model: String
    let messages: [OpenAIVisionMessage]
    let maxCompletionTokens: Int?
    let stream: Bool
    let tools: [OpenAITool]?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxCompletionTokens = "max_completion_tokens"
        case stream
        case tools
    }
}

struct OpenAIVisionMessage: Encodable {
    let role: String
    let content: [OpenAIVisionContent]
}

enum OpenAIVisionContent: Encodable {
    case text(String)
    case imageURL(String)

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageUrl = "image_url"
    }

    struct ImageURL: Encodable {
        let url: String
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .imageURL(let base64):
            try container.encode("image_url", forKey: .type)
            try container.encode(ImageURL(url: "data:image/png;base64,\(base64)"), forKey: .imageUrl)
        }
    }
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
    let toolCalls: [ToolCallDelta]?

    enum CodingKeys: String, CodingKey {
        case role
        case content
        case toolCalls = "tool_calls"
    }
}

// MARK: - Tool Call Response Models

struct ToolCallDelta: Decodable {
    let index: Int
    let id: String?
    let type: String?
    let function: FunctionCallDelta?
}

struct FunctionCallDelta: Decodable {
    let name: String?
    let arguments: String?
}

/// Assembled tool call from streaming deltas
struct ToolCall {
    var id: String
    var functionName: String
    var arguments: String

    init() {
        self.id = ""
        self.functionName = ""
        self.arguments = ""
    }
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
