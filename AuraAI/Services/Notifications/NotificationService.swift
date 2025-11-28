//
//  NotificationService.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/28/25.
//

import Foundation
import UserNotifications

enum NotificationError: Error, LocalizedError {
    case permissionDenied
    case schedulingFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Notification permission was denied. Please enable notifications in System Settings."
        case .schedulingFailed(let reason):
            return "Failed to schedule notification: \(reason)"
        }
    }
}

actor NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    /// Request notification permission from the user
    /// Returns true if permission was granted
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            print("🔔 Notification permission: \(granted ? "granted" : "denied")")
            return granted
        } catch {
            print("🔔 Notification permission error: \(error)")
            return false
        }
    }

    /// Check current notification permission status
    func checkPermission() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    /// Schedule a notification to appear after a delay
    /// - Parameters:
    ///   - title: The notification title
    ///   - body: The notification body text
    ///   - delay: Seconds until the notification appears
    /// - Returns: The notification identifier
    @discardableResult
    func scheduleNotification(title: String, body: String, delay: TimeInterval) async throws -> String {
        // Check permission first
        var status = await checkPermission()

        // Try to request permission if not determined
        if status == .notDetermined {
            let granted = await requestPermission()
            if granted {
                status = .authorized
            }
        }

        guard status == .authorized else {
            throw NotificationError.permissionDenied
        }

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // Create trigger with delay
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)

        // Create unique identifier
        let identifier = "aura_notification_\(UUID().uuidString)"

        // Create request
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        // Schedule the notification
        do {
            try await center.add(request)
            print("🔔 Notification scheduled: '\(title)' in \(Int(delay)) seconds")
            return identifier
        } catch {
            throw NotificationError.schedulingFailed(error.localizedDescription)
        }
    }

    /// Cancel all pending notifications
    func cancelAllPending() {
        center.removeAllPendingNotificationRequests()
        print("🔔 All pending notifications cancelled")
    }

    /// Cancel a specific notification by identifier
    func cancel(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        print("🔔 Notification cancelled: \(identifier)")
    }

    /// Get count of pending notifications
    func pendingCount() async -> Int {
        let requests = await center.pendingNotificationRequests()
        return requests.count
    }
}
