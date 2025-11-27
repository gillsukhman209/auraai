//
//  ChatInputView.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/26/25.
//

import SwiftUI

struct ChatInputView: View {
    @Binding var text: String
    @Binding var selectedModel: AIModelType
    var onSend: () -> Void
    var onPaste: () -> Void
    var onScreenshot: () -> Void
    var isDisabled: Bool
    var imageCount: Int
    var isFocused: FocusState<Bool>.Binding

    @State private var isHoveringPaste = false
    @State private var isHoveringScreenshot = false
    @State private var isHoveringSend = false
    @State private var isHoveringModel = false
    @State private var showModelPicker = false

    var body: some View {
        HStack(spacing: 10) {
            // Model selector button
            Button(action: { showModelPicker.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: selectedModel.iconName)
                        .font(.system(size: 12, weight: .medium))
                    Text(selectedModel.displayName)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(isHoveringModel ? .white : .white.opacity(0.7))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.white.opacity(isHoveringModel ? 0.15 : 0.1))
                )
            }
            .buttonStyle(.plain)
            .onHover { isHoveringModel = $0 }
            .help("Select AI model")
            .popover(isPresented: $showModelPicker, arrowEdge: .top) {
                ModelPickerView(selectedModel: $selectedModel, isPresented: $showModelPicker)
            }

            // Screenshot button
            Button(action: onScreenshot) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isHoveringScreenshot ? .white : .white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .onHover { isHoveringScreenshot = $0 }
            .help("Capture screenshot (⌘⇧S)")
            .disabled(isDisabled)

            // Paste button
            Button(action: onPaste) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isHoveringPaste ? .white : .white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .onHover { isHoveringPaste = $0 }
            .help("Paste from clipboard")

            // Text field
            TextField("Ask anything...", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .lineLimit(1...4)
                .foregroundColor(.white)
                .tint(.white)
                .focused(isFocused)
                .onSubmit {
                    if !text.isEmpty && !isDisabled {
                        onSend()
                    }
                }

            // Send button
            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(canSend ? .white : .white.opacity(0.3))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(canSend ? Color(red: 0.3, green: 0.5, blue: 1.0) : .white.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .onHover { isHoveringSend = $0 }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            ZStack {
                Color.black.opacity(0.5)
                Color.white.opacity(0.05)
            }
            .background(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
    }

    private var canSend: Bool {
        (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || imageCount > 0) && !isDisabled
    }
}

// MARK: - Model Picker View

struct ModelPickerView: View {
    @Binding var selectedModel: AIModelType
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Select Model")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            ForEach(AIModelType.allCases) { model in
                Button(action: {
                    selectedModel = model
                    isPresented = false
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: model.iconName)
                            .font(.system(size: 14))
                            .foregroundColor(selectedModel == model ? .blue : .primary)
                            .frame(width: 20)

                        Text(model.displayName)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)

                        Spacer()

                        if selectedModel == model {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(selectedModel == model ? Color.blue.opacity(0.1) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .frame(width: 160)
    }
}

// Preview wrapper to handle FocusState
struct ChatInputViewPreview: View {
    @FocusState private var isFocused: Bool
    @State private var selectedModel: AIModelType = .gpt4o

    var body: some View {
        ZStack {
            Color.gray.opacity(0.3)
            VStack {
                Spacer()
                ChatInputView(
                    text: .constant(""),
                    selectedModel: $selectedModel,
                    onSend: {},
                    onPaste: {},
                    onScreenshot: {},
                    isDisabled: false,
                    imageCount: 0,
                    isFocused: $isFocused
                )
                .padding()
            }
        }
        .frame(width: 400, height: 200)
    }
}

#Preview {
    ChatInputViewPreview()
}
