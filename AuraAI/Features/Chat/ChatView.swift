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
                    .help("Close (Esc)")
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)

                // Quick Actions (shown when clipboard has text and no conversation)
                if viewModel.showQuickActions {
                    QuickActionsView(
                        clipboardText: viewModel.clipboardText,
                        onActionSelected: { action in
                            Task { await viewModel.executeQuickAction(action) }
                        },
                        onDismiss: viewModel.dismissQuickActions
                    )
                    .padding(.horizontal, 12)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                // Messages - floating bubbles (always show ScrollView for proper layout)
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 16) {
                            // Empty state hint
                            if viewModel.conversation.messages.isEmpty && !viewModel.showQuickActions {
                                VStack(spacing: 12) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 36, weight: .light))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )

                                    Text("Ask anything...")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white.opacity(0.5))

                                    Text("Copy text to see quick actions")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.3))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                            }

                            ForEach(viewModel.conversation.messages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    }
                    .scrollContentBackground(.hidden)
                    .onChange(of: viewModel.conversation.messages.count) { _, _ in
                        if let lastMessage = viewModel.conversation.messages.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    // Also scroll when content changes (for streaming)
                    .onChange(of: viewModel.conversation.messages.last?.content) { _, _ in
                        if let lastMessage = viewModel.conversation.messages.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .frame(maxHeight: .infinity)

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
        .onAppear {
            viewModel.checkClipboardForQuickActions()
        }
        .onKeyPress(.escape) {
            panel?.close()
            return .handled
        }
    }
}
