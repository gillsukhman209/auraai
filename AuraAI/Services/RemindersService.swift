//
//  RemindersService.swift
//  AuraAI
//
//  Created by Claude on 11/27/25.
//

import EventKit
import Foundation

enum RemindersError: Error, LocalizedError {
    case accessDenied
    case accessRestricted
    case noRemindersCalendar
    case saveFailed(Error)
    case invalidDate

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access to Reminders was denied. Please enable in System Settings > Privacy & Security > Reminders."
        case .accessRestricted:
            return "Access to Reminders is restricted on this device."
        case .noRemindersCalendar:
            return "No reminders list found. Please open the Reminders app and create a list first."
        case .saveFailed(let error):
            return "Failed to save reminder: \(error.localizedDescription)"
        case .invalidDate:
            return "Could not parse the reminder date."
        }
    }
}

actor RemindersService {
    static let shared = RemindersService()

    private let eventStore = EKEventStore()
    private var isAuthorized = false

    private init() {}

    // MARK: - Authorization

    /// Request access to Reminders
    func requestAccess() async throws -> Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        print("🔔 Reminders authorization status: \(status.rawValue)")

        switch status {
        case .authorized, .fullAccess:
            isAuthorized = true
            // Refresh event store sources to ensure calendars are loaded
            eventStore.refreshSourcesIfNecessary()
            print("🔔 Already authorized, sources count: \(eventStore.sources.count)")
            return true

        case .notDetermined:
            print("🔔 Requesting Reminders access...")
            // Request access
            if #available(macOS 14.0, *) {
                let granted = try await eventStore.requestFullAccessToReminders()
                print("🔔 Access granted: \(granted)")
                isAuthorized = granted
                if granted {
                    eventStore.refreshSourcesIfNecessary()
                    print("🔔 Sources after grant: \(eventStore.sources.count)")
                }
                return granted
            } else {
                let granted = try await eventStore.requestAccess(to: .reminder)
                print("🔔 Access granted (legacy): \(granted)")
                isAuthorized = granted
                if granted {
                    eventStore.refreshSourcesIfNecessary()
                }
                return granted
            }

        case .denied:
            print("🔔 Access DENIED - user needs to enable in System Settings")
            throw RemindersError.accessDenied

        case .restricted, .writeOnly:
            print("🔔 Access RESTRICTED")
            throw RemindersError.accessRestricted

        @unknown default:
            print("🔔 Unknown status: \(status.rawValue)")
            throw RemindersError.accessDenied
        }
    }

    // MARK: - Create Reminder

    /// Create a reminder with the given title and optional due date
    /// - Parameters:
    ///   - title: The reminder title
    ///   - dueDate: Optional due date
    ///   - notes: Optional notes
    /// - Returns: Success message
    func createReminder(title: String, dueDate: Date?, notes: String?) async throws -> String {
        // Always ensure we have access (this also refreshes the eventStore)
        _ = try await requestAccess()

        // Try default calendar first, then fall back to any available reminder calendar
        let calendar: EKCalendar
        if let defaultCalendar = eventStore.defaultCalendarForNewReminders() {
            calendar = defaultCalendar
        } else {
            // Get all reminder calendars and use the first one
            let reminderCalendars = eventStore.calendars(for: .reminder)
            if let firstCalendar = reminderCalendars.first {
                calendar = firstCalendar
            } else {
                // No calendars exist - create one
                let newCalendar = EKCalendar(for: .reminder, eventStore: eventStore)
                newCalendar.title = "Reminders"

                // Find a source for the calendar (local or iCloud)
                if let localSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
                    newCalendar.source = localSource
                } else if let defaultSource = eventStore.sources.first {
                    newCalendar.source = defaultSource
                } else {
                    throw RemindersError.noRemindersCalendar
                }

                try eventStore.saveCalendar(newCalendar, commit: true)
                calendar = newCalendar
            }
        }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.calendar = calendar
        reminder.notes = notes

        // Set due date with alarm if provided
        if let dueDate = dueDate {
            let dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
            reminder.dueDateComponents = dueDateComponents

            // Add an alarm at the due time
            let alarm = EKAlarm(absoluteDate: dueDate)
            reminder.addAlarm(alarm)
        }

        do {
            try eventStore.save(reminder, commit: true)

            // Build confirmation message
            var confirmationMessage = "Created reminder: \"\(title)\""
            if let dueDate = dueDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                confirmationMessage += " for \(formatter.string(from: dueDate))"
            }

            return confirmationMessage
        } catch {
            throw RemindersError.saveFailed(error)
        }
    }

    // MARK: - Date Parsing

    /// Parse a date string from AI response into a Date
    /// Handles formats like "2025-11-27T17:00:00", "17:00", "5pm", etc.
    static func parseDate(_ dateString: String) -> Date? {
        let now = Date()
        let calendar = Calendar.current

        // Try ISO 8601 format first
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateString) {
            return date
        }

        // Try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) {
            return date
        }

        // Try simple date-time format
        let dateTimeFormatter = DateFormatter()
        dateTimeFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = dateTimeFormatter.date(from: dateString) {
            return date
        }

        // Try date only
        dateTimeFormatter.dateFormat = "yyyy-MM-dd"
        if let date = dateTimeFormatter.date(from: dateString) {
            return date
        }

        // Try time only (assume today or tomorrow)
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        if let time = timeFormatter.date(from: dateString) {
            var components = calendar.dateComponents([.hour, .minute], from: time)
            components.year = calendar.component(.year, from: now)
            components.month = calendar.component(.month, from: now)
            components.day = calendar.component(.day, from: now)

            if let date = calendar.date(from: components) {
                // If time has passed today, use tomorrow
                if date < now {
                    return calendar.date(byAdding: .day, value: 1, to: date)
                }
                return date
            }
        }

        // Try 12-hour format (5pm, 5:30pm)
        let time12Formatter = DateFormatter()
        time12Formatter.dateFormat = "h:mma"
        let cleanedString = dateString.lowercased().replacingOccurrences(of: " ", with: "")
        if let time = time12Formatter.date(from: cleanedString) {
            var components = calendar.dateComponents([.hour, .minute], from: time)
            components.year = calendar.component(.year, from: now)
            components.month = calendar.component(.month, from: now)
            components.day = calendar.component(.day, from: now)

            if let date = calendar.date(from: components) {
                if date < now {
                    return calendar.date(byAdding: .day, value: 1, to: date)
                }
                return date
            }
        }

        // Try without minutes (5pm)
        time12Formatter.dateFormat = "ha"
        if let time = time12Formatter.date(from: cleanedString) {
            var components = calendar.dateComponents([.hour, .minute], from: time)
            components.year = calendar.component(.year, from: now)
            components.month = calendar.component(.month, from: now)
            components.day = calendar.component(.day, from: now)

            if let date = calendar.date(from: components) {
                if date < now {
                    return calendar.date(byAdding: .day, value: 1, to: date)
                }
                return date
            }
        }

        return nil
    }
}
