//
//  GeminiModels.swift
//  AuraAI
//
//  Created by Claude on 11/27/25.
//

import Foundation

// MARK: - Request Models

struct GeminiRequest: Encodable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig?

    enum CodingKeys: String, CodingKey {
        case contents
        case generationConfig
    }
}

struct GeminiContent: Codable {
    let role: String
    let parts: [GeminiPart]
}

struct GeminiPart: Codable {
    let text: String?
    let inlineData: GeminiInlineData?

    enum CodingKeys: String, CodingKey {
        case text
        case inlineData = "inline_data"
    }

    init(text: String) {
        self.text = text
        self.inlineData = nil
    }

    init(inlineData: GeminiInlineData) {
        self.text = nil
        self.inlineData = inlineData
    }
}

struct GeminiInlineData: Codable {
    let mimeType: String
    let data: String
}

struct GeminiGenerationConfig: Encodable {
    let maxOutputTokens: Int?
    let temperature: Double?

    enum CodingKeys: String, CodingKey {
        case maxOutputTokens
        case temperature
    }
}

// MARK: - Response Models

struct GeminiResponse: Decodable {
    let candidates: [GeminiCandidate]?
    let promptFeedback: GeminiPromptFeedback?
    let error: GeminiErrorDetail?
}

struct GeminiCandidate: Decodable {
    let content: GeminiContent?
    let finishReason: String?
    let safetyRatings: [GeminiSafetyRating]?
}

struct GeminiPromptFeedback: Decodable {
    let safetyRatings: [GeminiSafetyRating]?
    let blockReason: String?
}

struct GeminiSafetyRating: Decodable {
    let category: String
    let probability: String
}

// MARK: - Streaming Response

struct GeminiStreamChunk: Decodable {
    let candidates: [GeminiCandidate]?
    let error: GeminiErrorDetail?
}

// MARK: - Error Models

struct GeminiErrorResponse: Decodable {
    let error: GeminiErrorDetail
}

struct GeminiErrorDetail: Decodable {
    let code: Int?
    let message: String
    let status: String?
}
