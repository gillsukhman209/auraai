//
//  TimerView.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/28/25.
//

import SwiftUI

struct TimerView: View {
    @ObservedObject var timerService = TimerService.shared
    @State private var isHovering = false

    private var modeColor: Color {
        switch timerService.timerMode {
        case .work: return .red
        case .shortBreak: return .green
        case .longBreak: return .blue
        case .regular: return .orange
        }
    }

    private var gradientColors: [Color] {
        switch timerService.timerMode {
        case .work: return [.red, .orange]
        case .shortBreak: return [.green, .mint]
        case .longBreak: return [.blue, .cyan]
        case .regular: return [.orange, .yellow]
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let ringSize = size * 0.65
            let fontSize = size * 0.18

            VStack(spacing: 0) {
                // Mode indicator pill
                if timerService.isPomodoro {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(modeColor)
                            .frame(width: 6, height: 6)

                        Text(timerService.timerMode.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                            )
                    )
                    .padding(.top, 16)
                }

                Spacer()

                // Timer display
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [modeColor.opacity(0.15), .clear],
                                center: .center,
                                startRadius: ringSize * 0.3,
                                endRadius: ringSize * 0.7
                            )
                        )
                        .frame(width: ringSize * 1.3, height: ringSize * 1.3)
                        .blur(radius: 10)

                    // Background track
                    Circle()
                        .stroke(.white.opacity(0.08), lineWidth: 4)
                        .frame(width: ringSize, height: ringSize)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: 1 - timerService.progress)
                        .stroke(
                            AngularGradient(
                                colors: gradientColors + [gradientColors[0].opacity(0.5)],
                                center: .center,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(270)
                            ),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .frame(width: ringSize, height: ringSize)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.5), value: timerService.progress)

                    // Time and status
                    VStack(spacing: 2) {
                        Text(timerService.formattedTime)
                            .font(.system(size: fontSize, weight: .light, design: .rounded))
                            .foregroundColor(.white)
                            .monospacedDigit()

                        if timerService.isPaused {
                            Text("PAUSED")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(.orange)
                                .tracking(2)
                        } else if timerService.remainingSeconds == 0 && !timerService.isPomodoro {
                            Text("DONE")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(.green)
                                .tracking(2)
                        }
                    }
                }

                // Session dots for pomodoro
                if timerService.isPomodoro {
                    HStack(spacing: 8) {
                        ForEach(1...timerService.totalSessions, id: \.self) { session in
                            Circle()
                                .fill(session <= timerService.currentSession ? modeColor : .white.opacity(0.2))
                                .frame(width: 8, height: 8)
                                .overlay(
                                    Circle()
                                        .strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                                )
                        }
                    }
                    .padding(.top, 16)
                }

                Spacer()

                // Controls
                HStack(spacing: 20) {
                    // Skip (pomodoro only)
                    if timerService.isPomodoro {
                        ControlButton(
                            icon: "forward.fill",
                            size: 14,
                            action: { timerService.skipToNext() }
                        )
                    }

                    // Play/Pause
                    ControlButton(
                        icon: timerService.isPaused ? "play.fill" : "pause.fill",
                        size: 18,
                        isPrimary: true,
                        color: modeColor,
                        action: { timerService.pauseResume() }
                    )
                    .disabled(timerService.remainingSeconds == 0 && !timerService.isPomodoro)

                    // Stop
                    ControlButton(
                        icon: "xmark",
                        size: 14,
                        action: { timerService.stopTimer() }
                    )
                }
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 180, minHeight: 240)
        .background(
            ZStack {
                // Dark translucent background
                RoundedRectangle(cornerRadius: 20)
                    .fill(.black.opacity(0.6))

                // Frosted glass effect
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .opacity(0.3)

                // Subtle border
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)

                // Accent glow at top
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [modeColor.opacity(0.15), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            }
        )
        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Control Button

struct ControlButton: View {
    let icon: String
    var size: CGFloat = 14
    var isPrimary: Bool = false
    var color: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(isPrimary ? .white : .white.opacity(0.7))
                .frame(width: isPrimary ? 48 : 36, height: isPrimary ? 48 : 36)
                .background(
                    Circle()
                        .fill(isPrimary ? color.opacity(0.8) : .white.opacity(0.1))
                )
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Visual Effect

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

#Preview {
    ZStack {
        Color.gray
        TimerView()
            .frame(width: 250, height: 320)
    }
}
