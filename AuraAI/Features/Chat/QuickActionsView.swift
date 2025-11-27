//
//  QuickActionsView.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/26/25.
//

import SwiftUI

struct QuickActionsView: View {
    let clipboardText: String?
    let onActionSelected: (QuickAction) -> Void
    let onDismiss: () -> Void

    @State private var hoveredAction: UUID?

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Actions")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    if let text = clipboardText {
                        Text("\"\(text.prefix(50))\(text.count > 50 ? "..." : "")\"")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }

            // Action Grid
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(QuickAction.actions) { action in
                    QuickActionButton(
                        action: action,
                        isHovered: hoveredAction == action.id,
                        onTap: { onActionSelected(action) }
                    )
                    .onHover { isHovered in
                        hoveredAction = isHovered ? action.id : nil
                    }
                }
            }
        }
        .padding(16)
        .background(
            ZStack {
                Color.black.opacity(0.6)
                Color.white.opacity(0.05)
            }
            .background(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

struct QuickActionButton: View {
    let action: QuickAction
    let isHovered: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: action.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isHovered ? .white : action.color)
                    .frame(width: 20)

                Text(action.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isHovered ? .white : .white.opacity(0.8))

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovered ? action.color.opacity(0.8) : .white.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.5)
        QuickActionsView(
            clipboardText: "This is some sample clipboard text that was copied",
            onActionSelected: { _ in },
            onDismiss: {}
        )
        .frame(width: 320)
    }
    .frame(width: 400, height: 400)
}
