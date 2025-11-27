//
//  GeminiService.swift
//  AuraAI
//
//  Created by Claude on 11/27/25.
//

import AppKit
import Foundation

enum GeminiError: Error, LocalizedError {
    case noAPIKey
    case invalidAPIKey
    case networkError(Error)
    case decodingError(Error)
    case apiError(String)
    case streamingError(String)
    case rateLimitExceeded
    case contentBlocked(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No Gemini API key configured."
        case .invalidAPIKey:
            return "Invalid Gemini API key."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .apiError(let message):
            return "API error: \(message)"
        case .streamingError(let message):
            return "Streaming error: \(message)"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .contentBlocked(let reason):
            return "Content blocked: \(reason)"
        }
    }
}

actor GeminiService: AIProvider {
    nonisolated let name = "Gemini"

    private var apiKey: String {
        AppConstants.API.geminiAPIKey
    }

    private var streamURL: URL {
        URL(string: "\(AppConstants.API.geminiBaseURL)/\(AppConstants.API.geminiModel):streamGenerateContent?alt=sse&key=\(apiKey)")!
    }

    private let screenshotService = ScreenshotService.shared

    func sendMessage(_ messages: [Message]) async throws -> AsyncThrowingStream<String, Error> {
        guard !apiKey.isEmpty && !apiKey.contains("YOUR_") else {
            throw GeminiError.noAPIKey
        }

        // Convert messages to Gemini format
        let geminiContents = convertToGeminiContents(messages)

        var urlRequest = URLRequest(url: streamURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let request = GeminiRequest(
            contents: geminiContents,
            generationConfig: GeminiGenerationConfig(
                maxOutputTokens: AppConstants.API.maxTokens,
                temperature: 0.7
            )
        )

        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.networkError(URLError(.badServerResponse))
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw GeminiError.invalidAPIKey
            }
            if httpResponse.statusCode == 429 {
                throw GeminiError.rateLimitExceeded
            }
            throw GeminiError.apiError("HTTP \(httpResponse.statusCode)")
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in bytes.lines {
                        // Gemini SSE format: "data: {json}"
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))

                            // Skip empty data
                            if jsonString.isEmpty { continue }

                            if let data = jsonString.data(using: .utf8) {
                                do {
                                    let chunk = try JSONDecoder().decode(GeminiStreamChunk.self, from: data)

                                    // Check for errors
                                    if let error = chunk.error {
                                        continuation.finish(throwing: GeminiError.apiError(error.message))
                                        return
                                    }

                                    // Extract text from candidates
                                    if let candidate = chunk.candidates?.first,
                                       let content = candidate.content,
                                       let part = content.parts.first,
                                       let text = part.text {
                                        continuation.yield(text)
                                    }

                                    // Check for finish
                                    if let finishReason = chunk.candidates?.first?.finishReason,
                                       finishReason == "STOP" {
                                        continuation.finish()
                                        return
                                    }
                                } catch {
                                    // Skip malformed chunks
                                    continue
                                }
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Convert app messages to Gemini format
    private func convertToGeminiContents(_ messages: [Message]) -> [GeminiContent] {
        var contents: [GeminiContent] = []

        for message in messages {
            // Skip system messages (Gemini doesn't have system role, we could prepend to first user message)
            if message.role == .system { continue }

            var parts: [GeminiPart] = []

            // Add images first (Gemini prefers images before text)
            for image in message.images {
                if let base64 = screenshotService.imageToBase64(image) {
                    parts.append(GeminiPart(inlineData: GeminiInlineData(
                        mimeType: "image/png",
                        data: base64
                    )))
                }
            }

            // Add text content
            if !message.content.isEmpty {
                parts.append(GeminiPart(text: message.content))
            } else if !message.images.isEmpty {
                // Default prompt for images
                let imageText = message.images.count == 1 ? "this image" : "these \(message.images.count) images"
                parts.append(GeminiPart(text: "What's in \(imageText)?"))
            }

            // Map roles: user -> user, assistant -> model
            let role = message.role == .user ? "user" : "model"
            contents.append(GeminiContent(role: role, parts: parts))
        }

        return contents
    }
}
