//
//  OpenAIService.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/26/25.
//

import AppKit
import Foundation

enum OpenAIError: Error, LocalizedError {
    case noAPIKey
    case invalidAPIKey
    case networkError(Error)
    case decodingError(Error)
    case apiError(String)
    case streamingError(String)
    case rateLimitExceeded

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured."
        case .invalidAPIKey:
            return "Invalid API key."
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
        }
    }
}

actor OpenAIService: AIProvider {
    nonisolated let name = "GPT-4o"

    private let baseURL = URL(string: AppConstants.API.openAIBaseURL)!

    private var apiKey: String {
        AppConstants.API.openAIAPIKey
    }

    private let screenshotService = ScreenshotService.shared

    func sendMessage(_ messages: [Message]) async throws -> AsyncThrowingStream<String, Error> {
        guard !apiKey.isEmpty && !apiKey.contains("YOUR_") else {
            throw OpenAIError.noAPIKey
        }

        // Check if any message has an image - use Vision API if so
        let hasImages = messages.contains { $0.image != nil }

        var urlRequest = URLRequest(url: baseURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        if hasImages {
            // Build Vision API request
            let visionMessages = messages
                .filter { $0.role != .system }
                .map { message -> OpenAIVisionMessage in
                    var content: [OpenAIVisionContent] = []

                    // Add image if present
                    if let image = message.image,
                       let base64 = screenshotService.imageToBase64(image) {
                        content.append(.imageURL(base64))
                    }

                    // Add text content
                    if !message.content.isEmpty {
                        content.append(.text(message.content))
                    } else if message.image != nil {
                        // Default prompt if only image
                        content.append(.text("What's in this image?"))
                    }

                    return OpenAIVisionMessage(role: message.role.rawValue, content: content)
                }

            let request = OpenAIVisionRequest(
                model: AppConstants.API.openAIModel,
                messages: visionMessages,
                maxTokens: AppConstants.API.maxTokens,
                stream: true
            )
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } else {
            // Standard text-only request
            let openAIMessages = messages
                .filter { $0.role != .system }
                .map { OpenAIChatMessage(role: $0.role.rawValue, content: $0.content) }

            let request = OpenAIChatRequest(
                model: AppConstants.API.openAIModel,
                messages: openAIMessages,
                maxTokens: AppConstants.API.maxTokens,
                stream: true
            )
            urlRequest.httpBody = try JSONEncoder().encode(request)
        }

        let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.networkError(URLError(.badServerResponse))
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw OpenAIError.invalidAPIKey
            }
            if httpResponse.statusCode == 429 {
                throw OpenAIError.rateLimitExceeded
            }
            throw OpenAIError.apiError("HTTP \(httpResponse.statusCode)")
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))

                            // Check for stream end
                            if jsonString == "[DONE]" {
                                continuation.finish()
                                return
                            }

                            // Parse the chunk
                            if let data = jsonString.data(using: .utf8) {
                                do {
                                    let chunk = try JSONDecoder().decode(OpenAIStreamChunk.self, from: data)
                                    if let content = chunk.choices?.first?.delta?.content {
                                        continuation.yield(content)
                                    }
                                    if chunk.choices?.first?.finishReason != nil {
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
}
