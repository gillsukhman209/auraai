//
//  ChatView.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/26/25.
//

import SwiftUI

struct ChatView: View {
    @Environment(\.floatingPanel) private var panel
    @State private var viewModel: ChatViewModel
    @State private var isHoveringClose = false
    @State private var isHoveringClear = false

    init(appState: AppState) {
        _viewModel = State(initialValue: ChatViewModel(
            openAIService: appState.openAIService,
            clipboardService: appState.clipboardService,
            conversation: appState.conversation
        ))
    }

    var body: some View {
        ZStack {
            // Fully transparent background
            Color.clear

            VStack(spacing: 16) {
                // Minimal floating controls at top right
                HStack {
                    Spacer()

                    // Clear button
                    Button(action: viewModel.clearConversation) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isHoveringClear ? .white : .white.opacity(0.6))
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(.black.opacity(isHoveringClear ? 0.5 : 0.3))
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringClear = $0 }
                    .help("Clear conversation")

                    // Close button
                    Button(action: { panel?.close() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isHoveringClose ? .white : .white.opacity(0.6))
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(.black.opacity(isHoveringClose ? 0.5 : 0.3))
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringClose = $0 }
                    .help("Close (Cmd+Shift+Space)")
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)

                // Messages - floating bubbles
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.conversation.messages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    }
                    .onChange(of: viewModel.conversation.messages.count) { _, _ in
                        if let lastMessage = viewModel.conversation.messages.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.red.opacity(0.15))
                        )
                }

                // Floating input bar
                ChatInputView(
                    text: $viewModel.inputText,
                    onSend: {
                        Task { await viewModel.sendMessage() }
                    },
                    onPaste: viewModel.pasteFromClipboard,
                    isDisabled: viewModel.isProcessing
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .frame(minWidth: 320, minHeight: 200)
    }
}
