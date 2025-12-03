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

                // Live calculator preview
                if let calcResult = viewModel.liveCalculatorPreview {
                    CalculatorPreviewView(result: calcResult)
                        .padding(.horizontal, 12)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }

                // Transform menu (shown when Cmd+Shift+T captures text)
                if viewModel.showTransformMenu, let text = viewModel.textToTransform {
                    TransformMenuView(
                        text: text,
                        onActionSelected: { action in
                            Task { await viewModel.transformText(text, action: action) }
                        },
                        onDismiss: viewModel.dismissTransformMenu
                    )
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
            // Consume pending hotkey actions FIRST (before clipboard monitoring)
            consumeScreenshotsFromHotkey()
            consumePendingWordToDefine()
            consumePendingTextToTransform()
            consumePendingTextToSummarize()
            // Start clipboard monitoring after consuming pending actions
            viewModel.startClipboardMonitoring()
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
        .onChange(of: appState.pendingTextToTransform) { _, newText in
            if newText != nil {
                consumePendingTextToTransform()
            }
        }
        .onChange(of: appState.pendingTextToSummarize) { _, newText in
            if newText != nil {
                consumePendingTextToSummarize()
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

    /// Transform text from hotkey (Cmd+Shift+T)
    private func consumePendingTextToTransform() {
        guard let text = appState.pendingTextToTransform else { return }

        // Clear the pending text immediately
        appState.pendingTextToTransform = nil

        // Show transform menu
        viewModel.showTransform(for: text)
    }

    /// Quick summarize from hotkey (Cmd+Shift+C)
    private func consumePendingTextToSummarize() {
        guard let text = appState.pendingTextToSummarize else { return }

        // Clear the pending text immediately
        appState.pendingTextToSummarize = nil

        // Dismiss any quick actions that clipboard monitoring may have shown
        viewModel.dismissQuickActions()

        // Directly summarize without showing menu
        Task { await viewModel.transformText(text, action: .summarize) }
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

// MARK: - Calculator Preview View

struct CalculatorPreviewView: View {
    let result: CalculatorResult

    var body: some View {
        HStack(spacing: 8) {
            Text("=")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

            Text(result.answer)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.black.opacity(0.3))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        )
        .animation(.easeOut(duration: 0.15), value: result.answer)
    }
}

// MARK: - Transform Menu View

struct TransformMenuView: View {
    let text: String
    var onActionSelected: (TransformAction) -> Void
    var onDismiss: () -> Void

    @State private var showTranslateOptions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with text preview
            HStack {
                Text("Transform:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))

                Text("\"\(text.prefix(30))\(text.count > 30 ? "..." : "")\"")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }

            // Main action buttons
            FlowLayout(spacing: 6) {
                ForEach(TransformAction.mainActions) { action in
                    TransformButton(action: action) {
                        onActionSelected(action)
                    }
                }

                // Translate dropdown
                TranslateDropdown(
                    isExpanded: $showTranslateOptions,
                    onSelect: { action in
                        onActionSelected(action)
                    }
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.black.opacity(0.5))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        )
    }
}

struct TransformButton: View {
    let action: TransformAction
    var onTap: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: action.icon)
                    .font(.system(size: 10, weight: .medium))
                Text(action.name)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(isHovering ? .white : .white.opacity(0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isHovering ? .white.opacity(0.2) : .white.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

struct TranslateDropdown: View {
    @Binding var isExpanded: Bool
    var onSelect: (TransformAction) -> Void
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { isExpanded.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.system(size: 10, weight: .medium))
                    Text("Translate")
                        .font(.system(size: 11, weight: .medium))
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundColor(isHovering ? .white : .white.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isHovering ? .white.opacity(0.2) : .white.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }

            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(TransformAction.translateActions) { action in
                        Button(action: { onSelect(action) }) {
                            Text(action.name)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 2)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.black.opacity(0.3))
                )
            }
        }
    }
}

/// Simple flow layout for wrapping buttons
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
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

