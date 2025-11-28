//
//  ChatView.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/26/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ChatView: View {
    @Environment(\.floatingPanel) private var panel
    @State private var viewModel: ChatViewModel
    @State private var isHoveringClose = false
    @State private var isHoveringClear = false
    @State private var isDraggingOver = false
    @FocusState private var isInputFocused: Bool

    // Keep reference to appState for screenshot hotkey
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        _viewModel = State(initialValue: ChatViewModel(
            openAIService: appState.openAIService,
            geminiService: appState.geminiService,
            clipboardService: appState.clipboardService,
            panelController: appState.panelController,
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

                // Define Quick Action (shown when clipboard has a single word)
                if viewModel.showDefineAction, let word = viewModel.clipboardWord {
                    DefineQuickActionView(
                        word: word,
                        onDefine: { Task { await viewModel.executeDefineAction() } },
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

                                    Text("Drop images or copy text")
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

                // Images preview (shown when there are pending images)
                if !viewModel.pendingImages.isEmpty {
                    ImagesPreviewView(
                        images: viewModel.pendingImages,
                        onRemove: { index in viewModel.removeImage(at: index) },
                        onClearAll: viewModel.clearAllImages
                    )
                    .padding(.horizontal, 12)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                    // Quick "Explain" action for images
                    ImageQuickActionView {
                        Task { await viewModel.explainImages() }
                    }
                    .padding(.horizontal, 12)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                // Floating input bar
                ChatInputView(
                    text: $viewModel.inputText,
                    selectedModel: $viewModel.selectedModel,
                    onSend: {
                        Task { await viewModel.sendMessage() }
                    },
                    onPaste: viewModel.pasteFromClipboard,
                    onScreenshot: {
                        Task { await viewModel.captureScreenshot() }
                    },
                    isDisabled: viewModel.isProcessing,
                    imageCount: viewModel.pendingImages.count,
                    isFocused: $isInputFocused
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }

            // Drop zone overlay
            if isDraggingOver {
                DropZoneOverlay()
            }
        }
        .frame(minWidth: 320, minHeight: 200)
        .onDrop(of: [.image, .fileURL], isTargeted: $isDraggingOver) { providers in
            viewModel.handleDroppedImage(providers: providers)
        }
        .onAppear {
            viewModel.startClipboardMonitoring()
            consumeScreenshotsFromHotkey()
            consumePendingWordToDefine()
        }
        .onDisappear {
            viewModel.stopClipboardMonitoring()
        }
        .onChange(of: appState.pendingScreenshotsFromHotkey.count) { _, newCount in
            if newCount > 0 {
                consumeScreenshotsFromHotkey()
            }
        }
        .onChange(of: appState.pendingWordToDefine) { _, newWord in
            if newWord != nil {
                consumePendingWordToDefine()
            }
        }
        .onKeyPress(.escape) {
            panel?.close()
            return .handled
        }
    }

    /// Transfer screenshots from hotkey to viewModel and focus input
    private func consumeScreenshotsFromHotkey() {
        guard !appState.pendingScreenshotsFromHotkey.isEmpty else { return }

        // Append all pending screenshots to viewModel
        viewModel.pendingImages.append(contentsOf: appState.pendingScreenshotsFromHotkey)
        appState.pendingScreenshotsFromHotkey = []

        // Focus input after a brief delay to ensure view is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isInputFocused = true
        }
    }

    /// Define word from hotkey (Cmd+Shift+D)
    private func consumePendingWordToDefine() {
        guard let word = appState.pendingWordToDefine else { return }

        // Clear the pending word immediately
        appState.pendingWordToDefine = nil

        // Define the word using AI
        Task { await viewModel.defineWord(word) }
    }
}

// MARK: - Image Quick Action View

struct ImageQuickActionView: View {
    var onExplain: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack {
            Button(action: onExplain) {
                HStack(spacing: 6) {
                    Image(systemName: "eye")
                        .font(.system(size: 12, weight: .medium))
                    Text("Explain")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(isHovering ? .white : .white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(isHovering ? 0.8 : 0.6), .purple.opacity(isHovering ? 0.8 : 0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }

            Spacer()
        }
    }
}

// MARK: - Define Quick Action View

struct DefineQuickActionView: View {
    let word: String
    var onDefine: () -> Void
    var onDismiss: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // Word preview
            Text("\"\(word)\"")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)

            // Define button
            Button(action: onDefine) {
                HStack(spacing: 6) {
                    Image(systemName: "book")
                        .font(.system(size: 12, weight: .medium))
                    Text("Define")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(isHovering ? .white : .white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.green.opacity(isHovering ? 0.8 : 0.6), .teal.opacity(isHovering ? 0.8 : 0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }

            Spacer()

            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.black.opacity(0.4))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        )
    }
}

// MARK: - Drop Zone Overlay

struct DropZoneOverlay: View {
    var body: some View {
        ZStack {
            // Semi-transparent background
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.black.opacity(0.6))

            // Dashed border
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 3, dash: [10, 5])
                )
                .foregroundColor(.white.opacity(0.6))
                .padding(8)

            // Drop icon and text
            VStack(spacing: 12) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Drop image here")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Text("PNG, JPG, GIF, HEIC supported")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: true)
    }
}

