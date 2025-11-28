//
//  TimerService.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/28/25.
//

import AppKit
import Combine

enum TimerMode: String {
    case work = "Focus"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"
    case regular = "Timer"

    var color: String {
        switch self {
        case .work: return "red"
        case .shortBreak: return "green"
        case .longBreak: return "blue"
        case .regular: return "orange"
        }
    }
}

@MainActor
class TimerService: ObservableObject {
    static let shared = TimerService()

    // Timer state
    @Published var remainingSeconds: Int = 0
    @Published var totalSeconds: Int = 0
    @Published var isPaused: Bool = false
    @Published var isRunning: Bool = false
    @Published var timerTitle: String = ""

    // Pomodoro state
    @Published var isPomodoro: Bool = false
    @Published var currentSession: Int = 1
    @Published var totalSessions: Int = 4
    @Published var timerMode: TimerMode = .regular

    // Pomodoro settings (in seconds)
    var workDuration = 25 * 60       // 25 minutes (customizable)
    let shortBreakDuration = 5 * 60  // 5 minutes
    let longBreakDuration = 15 * 60  // 15 minutes

    private var timer: Timer?
    private var windowController: TimerWindowController?

    private init() {}

    // MARK: - Regular Timer

    func startTimer(seconds: Int, title: String) {
        stopTimer()

        totalSeconds = seconds
        remainingSeconds = seconds
        timerTitle = title
        isPaused = false
        isRunning = true
        isPomodoro = false
        timerMode = .regular

        showWindow()
        startCountdown()
    }

    // MARK: - Pomodoro

    /// Start a pomodoro session
    /// - Parameter focusDuration: Custom focus duration in seconds (default 25 minutes)
    func startPomodoro(focusDuration: Int? = nil) {
        stopTimer()

        // Set custom focus duration if provided
        if let duration = focusDuration, duration > 0 {
            workDuration = duration
        } else {
            workDuration = 25 * 60  // Default 25 minutes
        }

        isPomodoro = true
        currentSession = 1
        timerMode = .work

        let focusMinutes = workDuration / 60
        timerTitle = "Session 1 of \(totalSessions) (\(focusMinutes)m)"

        totalSeconds = workDuration
        remainingSeconds = workDuration
        isPaused = false
        isRunning = true

        showWindow()
        startCountdown()
    }

    func skipToNext() {
        guard isPomodoro else { return }

        timer?.invalidate()
        timer = nil

        transitionToNextPhase()
    }

    private func transitionToNextPhase() {
        switch timerMode {
        case .work:
            // After work, check if we need long break
            if currentSession >= totalSessions {
                // Start long break
                timerMode = .longBreak
                totalSeconds = longBreakDuration
                remainingSeconds = longBreakDuration
                timerTitle = "Long Break"

                playSound()
                sendNotification(title: "Great work!", body: "Time for a long break. You've completed \(totalSessions) sessions!")
            } else {
                // Start short break
                timerMode = .shortBreak
                totalSeconds = shortBreakDuration
                remainingSeconds = shortBreakDuration
                timerTitle = "Short Break"

                playSound()
                sendNotification(title: "Session \(currentSession) complete!", body: "Take a short break.")
            }

        case .shortBreak:
            // After short break, start next work session
            currentSession += 1
            timerMode = .work
            totalSeconds = workDuration
            remainingSeconds = workDuration
            let focusMinutes = workDuration / 60
            timerTitle = "Session \(currentSession) of \(totalSessions) (\(focusMinutes)m)"

            playSound()
            sendNotification(title: "Break's over!", body: "Starting session \(currentSession) of \(totalSessions).")

        case .longBreak:
            // After long break, reset and start new cycle
            currentSession = 1
            timerMode = .work
            totalSeconds = workDuration
            remainingSeconds = workDuration
            let focusMinutes = workDuration / 60
            timerTitle = "Session 1 of \(totalSessions) (\(focusMinutes)m)"

            playSound()
            sendNotification(title: "Ready for more?", body: "Starting a new pomodoro cycle.")

        case .regular:
            break
        }

        isPaused = false
        isRunning = true
        startCountdown()
    }

    // MARK: - Controls

    func pauseResume() {
        isPaused.toggle()
        if isPaused {
            timer?.invalidate()
            timer = nil
        } else {
            startCountdown()
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        isPaused = false
        remainingSeconds = 0
        totalSeconds = 0
        timerTitle = ""
        isPomodoro = false
        currentSession = 1
        timerMode = .regular

        windowController?.close()
        windowController = nil
    }

    func addTime(seconds: Int) {
        remainingSeconds += seconds
        totalSeconds += seconds
    }

    // MARK: - Private

    private func showWindow() {
        windowController = TimerWindowController()
        windowController?.showWindow(nil)
    }

    private func startCountdown() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard remainingSeconds > 0 else {
            timerComplete()
            return
        }
        remainingSeconds -= 1
    }

    private func timerComplete() {
        timer?.invalidate()
        timer = nil

        if isPomodoro {
            // Auto-transition to next phase
            transitionToNextPhase()
        } else {
            // Regular timer - just complete
            isRunning = false
            playSound()
            sendNotification(title: "Timer Complete!", body: timerTitle.isEmpty ? "Your timer has finished." : timerTitle)

            // Close window after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.windowController?.close()
                self?.windowController = nil
            }
        }
    }

    private func playSound() {
        NSSound.beep()
    }

    private func sendNotification(title: String, body: String) {
        Task {
            try? await NotificationService.shared.scheduleNotification(
                title: title,
                body: body,
                delay: 1
            )
        }
    }

    // MARK: - Formatting

    var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }
}
