//
//  MessageBubbleView.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/26/25.
//

import SwiftUI

struct MessageBubbleView: View {
    let message: Message

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                // Message content
                Text(message.content.isEmpty && message.isStreaming ? "..." : message.content)
                    .font(.system(size: 14, weight: .regular))
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleBackground)
                    .foregroundColor(isUser ? .white : .white.opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)

                // Streaming indicator
                if message.isStreaming {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.white.opacity(0.5))
                            .frame(width: 4, height: 4)
                        Circle()
                            .fill(.white.opacity(0.3))
                            .frame(width: 4, height: 4)
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 4, height: 4)
                    }
                    .padding(.leading, 8)
                }
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if isUser {
            // User bubble - vibrant blue gradient
            LinearGradient(
                colors: [Color(red: 0.3, green: 0.5, blue: 1.0), Color(red: 0.4, green: 0.35, blue: 0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // Assistant bubble - frosted dark glass
            ZStack {
                Color.black.opacity(0.5)
                Color.white.opacity(0.05)
            }
            .background(.ultraThinMaterial)
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
        VStack(spacing: 16) {
            MessageBubbleView(message: Message(role: .user, content: "Hello, how are you?"))
            MessageBubbleView(message: Message(role: .assistant, content: "I'm doing great! How can I help you today?"))
            MessageBubbleView(message: Message(role: .assistant, content: "", isStreaming: true))
        }
        .padding()
    }
    .frame(width: 400, height: 300)
}
