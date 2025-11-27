//
//  ChatInputView.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/26/25.
//

import SwiftUI

struct ChatInputView: View {
    @Binding var text: String
    var onSend: () -> Void
    var onPaste: () -> Void
    var isDisabled: Bool

    @State private var isHoveringPaste = false
    @State private var isHoveringSend = false

    var body: some View {
        HStack(spacing: 10) {
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
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isDisabled
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
        VStack {
            Spacer()
            ChatInputView(
                text: .constant(""),
                onSend: {},
                onPaste: {},
                isDisabled: false
            )
            .padding()
        }
    }
    .frame(width: 400, height: 200)
}
