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
    nonisolated let name = "GPT-5.1"

    private let baseURL = URL(string: AppConstants.API.openAIBaseURL)!

    private var apiKey: String {
        AppConstants.API.openAIAPIKey
    }

    private let screenshotService = ScreenshotService.shared
    private let remindersService = RemindersService.shared
    private let notificationService = NotificationService.shared

    // MARK: - Tool Definitions

    private var availableTools: [OpenAITool] {
        [
            OpenAITool(function: OpenAIFunctionDefinition(
                name: "create_reminder",
                description: "Create a reminder in the user's Reminders app. Use this when the user asks to be reminded about something.",
                parameters: OpenAIFunctionParameters(
                    properties: [
                        "title": OpenAIParameterProperty(
                            type: "string",
                            description: "The title/content of the reminder (e.g., 'Go to gym', 'Call mom')"
                        ),
                        "due_date": OpenAIParameterProperty(
                            type: "string",
                            description: "The due date/time in ISO 8601 format (e.g., '2025-11-27T17:00:00') or natural time like '17:00' or '5pm'"
                        ),
                        "notes": OpenAIParameterProperty(
                            type: "string",
                            description: "Optional additional notes for the reminder"
                        )
                    ],
                    required: ["title"]
                )
            )),
            OpenAITool(function: OpenAIFunctionDefinition(
                name: "send_notification",
                description: "Schedule a macOS notification to appear after a delay. Use this when the user asks to be notified or alerted about something in the future.",
                parameters: OpenAIFunctionParameters(
                    properties: [
                        "title": OpenAIParameterProperty(
                            type: "string",
                            description: "Brief notification title (e.g., 'Time to stretch!', 'Meeting reminder')"
                        ),
                        "body": OpenAIParameterProperty(
                            type: "string",
                            description: "The notification message body with more details"
                        ),
                        "delay_seconds": OpenAIParameterProperty(
                            type: "number",
                            description: "Number of seconds until the notification appears (e.g., 600 for 10 minutes)"
                        )
                    ],
                    required: ["title", "body", "delay_seconds"]
                )
            ))
        ]
    }

    func sendMessage(_ messages: [Message]) async throws -> AsyncThrowingStream<String, Error> {
        guard !apiKey.isEmpty && !apiKey.contains("YOUR_") else {
            throw OpenAIError.noAPIKey
        }

        // Check if any message has images - use Vision API if so
        let hasImages = messages.contains { !$0.images.isEmpty }

        var urlRequest = URLRequest(url: baseURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // Create system message with current date/time for accurate reminder scheduling
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone.current
        let currentDateTime = dateFormatter.string(from: Date())
        let timeZone = TimeZone.current.identifier
        let systemPrompt = "Current date and time: \(currentDateTime) (timezone: \(timeZone)). When the user asks for reminders with relative times like 'in 2 minutes' or 'tomorrow at 5pm', calculate the exact date/time based on the current time provided."

        if hasImages {
            // Build Vision API request with support for multiple images
            var visionMessages: [OpenAIVisionMessage] = []

            // Add system message first
            visionMessages.append(OpenAIVisionMessage(role: "system", content: [.text(systemPrompt)]))

            // Add user/assistant messages
            visionMessages += messages
                .filter { $0.role != .system }
                .map { message -> OpenAIVisionMessage in
                    var content: [OpenAIVisionContent] = []

                    // Add all images from this message
                    for image in message.images {
                        if let base64 = screenshotService.imageToBase64(image) {
                            content.append(.imageURL(base64))
                        }
                    }

                    // Add text content
                    if !message.content.isEmpty {
                        content.append(.text(message.content))
                    } else if !message.images.isEmpty {
                        // Default prompt if only images
                        let imageText = message.images.count == 1 ? "this image" : "these \(message.images.count) images"
                        content.append(.text("What's in \(imageText)?"))
                    }

                    return OpenAIVisionMessage(role: message.role.rawValue, content: content)
                }

            let request = OpenAIVisionRequest(
                model: AppConstants.API.openAIModel,
                messages: visionMessages,
                maxCompletionTokens: AppConstants.API.maxTokens,
                stream: true,
                tools: availableTools
            )
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } else {
            // Standard text-only request with tools
            var openAIMessages: [OpenAIChatMessage] = []

            // Add system message first
            openAIMessages.append(OpenAIChatMessage(role: "system", content: systemPrompt))

            // Add user/assistant messages
            openAIMessages += messages
                .filter { $0.role != .system }
                .map { OpenAIChatMessage(role: $0.role.rawValue, content: $0.content) }

            let request = OpenAIChatRequest(
                model: AppConstants.API.openAIModel,
                messages: openAIMessages,
                maxCompletionTokens: AppConstants.API.maxTokens,
                stream: true,
                tools: availableTools
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
            // Try to get error details from response body
            var errorMessage = "HTTP \(httpResponse.statusCode)"
            var errorBody = ""
            for try await line in bytes.lines {
                errorBody += line
            }
            if !errorBody.isEmpty {
                // Parse error JSON if possible
                if let data = errorBody.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    errorMessage = message
                } else {
                    errorMessage = errorBody
                }
            }
            print("❌ OpenAI API Error: \(errorMessage)")
            throw OpenAIError.apiError(errorMessage)
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    var toolCalls: [Int: ToolCall] = [:]
                    var finishReason: String?

                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))

                            // Check for stream end
                            if jsonString == "[DONE]" {
                                break
                            }

                            // Parse the chunk
                            if let data = jsonString.data(using: .utf8) {
                                do {
                                    let chunk = try JSONDecoder().decode(OpenAIStreamChunk.self, from: data)

                                    // Handle regular content
                                    if let content = chunk.choices?.first?.delta?.content {
                                        continuation.yield(content)
                                    }

                                    // Handle tool calls
                                    if let deltaToolCalls = chunk.choices?.first?.delta?.toolCalls {
                                        print("🔧 Received tool call delta: \(deltaToolCalls.count) calls")
                                        for toolCallDelta in deltaToolCalls {
                                            let index = toolCallDelta.index
                                            if toolCalls[index] == nil {
                                                toolCalls[index] = ToolCall()
                                            }
                                            if let id = toolCallDelta.id {
                                                toolCalls[index]?.id = id
                                                print("🔧 Tool ID: \(id)")
                                            }
                                            if let name = toolCallDelta.function?.name {
                                                toolCalls[index]?.functionName = name
                                                print("🔧 Tool name: \(name)")
                                            }
                                            if let args = toolCallDelta.function?.arguments {
                                                toolCalls[index]?.arguments += args
                                            }
                                        }
                                    }

                                    if let reason = chunk.choices?.first?.finishReason {
                                        finishReason = reason
                                        print("🔧 Finish reason: \(reason)")
                                    }
                                } catch {
                                    // Skip malformed chunks
                                    continue
                                }
                            }
                        }
                    }

                    // If we have tool calls to execute
                    print("🔧 Stream ended. Finish reason: \(finishReason ?? "nil"), tool calls: \(toolCalls.count)")
                    if finishReason == "tool_calls" && !toolCalls.isEmpty {
                        print("🔧 Executing \(toolCalls.count) tool calls...")
                        for (_, toolCall) in toolCalls.sorted(by: { $0.key < $1.key }) {
                            print("🔧 Executing: \(toolCall.functionName) with args: \(toolCall.arguments)")
                            let result = await self.executeToolCall(toolCall)
                            continuation.yield(result)
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Tool Execution

    private func executeToolCall(_ toolCall: ToolCall) async -> String {
        switch toolCall.functionName {
        case "create_reminder":
            return await executeCreateReminder(arguments: toolCall.arguments)
        case "send_notification":
            return await executeNotification(arguments: toolCall.arguments)
        default:
            return "\n\n⚠️ Unknown tool: \(toolCall.functionName)"
        }
    }

    private func executeCreateReminder(arguments: String) async -> String {
        // Parse the JSON arguments
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let title = json["title"] as? String else {
            return "\n\n❌ Failed to parse reminder details."
        }

        let dueDateString = json["due_date"] as? String
        let notes = json["notes"] as? String

        // Parse the due date if provided
        var dueDate: Date?
        if let dueDateString = dueDateString {
            dueDate = RemindersService.parseDate(dueDateString)
        }

        // Create the reminder
        do {
            let result = try await remindersService.createReminder(
                title: title,
                dueDate: dueDate,
                notes: notes
            )
            return "\n\n✅ \(result)"
        } catch {
            return "\n\n❌ \(error.localizedDescription)"
        }
    }

    private func executeNotification(arguments: String) async -> String {
        // Parse the JSON arguments
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let title = json["title"] as? String,
              let body = json["body"] as? String,
              let delaySeconds = json["delay_seconds"] as? Double else {
            return "\n\n❌ Failed to parse notification details."
        }

        // Schedule the notification
        do {
            try await notificationService.scheduleNotification(
                title: title,
                body: body,
                delay: delaySeconds
            )

            // Format a friendly time description
            let timeDescription = formatTimeDelay(seconds: Int(delaySeconds))
            return "\n\n⏰ I'll notify you \(timeDescription)!"
        } catch {
            return "\n\n❌ \(error.localizedDescription)"
        }
    }

    private func formatTimeDelay(seconds: Int) -> String {
        if seconds < 60 {
            return "in \(seconds) second\(seconds == 1 ? "" : "s")"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "in \(minutes) minute\(minutes == 1 ? "" : "s")"
        } else {
            let hours = seconds / 3600
            let remainingMinutes = (seconds % 3600) / 60
            if remainingMinutes > 0 {
                return "in \(hours) hour\(hours == 1 ? "" : "s") and \(remainingMinutes) minute\(remainingMinutes == 1 ? "" : "s")"
            }
            return "in \(hours) hour\(hours == 1 ? "" : "s")"
        }
    }
}
