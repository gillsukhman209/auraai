//
//  GlobalHotKeyManager.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/26/25.
//

import AppKit
import Carbon
import Foundation

@Observable
class GlobalHotKeyManager {
    private var eventHandler: EventHandlerRef?
    private var toggleHotKeyRef: EventHotKeyRef?
    private var screenshotHotKeyRef: EventHotKeyRef?
    private var defineHotKeyRef: EventHotKeyRef?
    private var transformHotKeyRef: EventHotKeyRef?
    private var summarizeHotKeyRef: EventHotKeyRef?

    // Hotkey IDs
    private static let toggleHotKeyID: UInt32 = 1
    private static let screenshotHotKeyID: UInt32 = 2
    private static let defineHotKeyID: UInt32 = 3
    private static let transformHotKeyID: UInt32 = 4
    private static let summarizeHotKeyID: UInt32 = 5

    // Debouncing - prevent rapid successive hotkey presses
    private var lastHotKeyTime: [UInt32: Date] = [:]
    private let debounceInterval: TimeInterval = 0.3

    // Callbacks
    var onHotKeyPressed: (() -> Void)?              // Cmd+Shift+Space - toggle panel
    var onScreenshotHotKeyPressed: (() -> Void)?    // Cmd+Shift+S - screenshot
    var onDefineHotKeyPressed: (() -> Void)?        // Cmd+Shift+D - define word
    var onTransformHotKeyPressed: (() -> Void)?     // Cmd+Shift+T - transform text
    var onSummarizeHotKeyPressed: (() -> Void)?     // Cmd+Shift+C - quick summarize

    init() {
        setupHotKeys()
    }

    private func setupHotKeys() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Install single event handler for all hotkeys
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData, let event = event else { return noErr }

                // Extract the hotkey ID from the event
                var hotKeyID = EventHotKeyID()
                let getParamStatus = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard getParamStatus == noErr else { return noErr }

                let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()

                // Debounce check
                let now = Date()
                if let lastTime = manager.lastHotKeyTime[hotKeyID.id],
                   now.timeIntervalSince(lastTime) < manager.debounceInterval {
                    return noErr
                }
                manager.lastHotKeyTime[hotKeyID.id] = now

                DispatchQueue.main.async {
                    switch hotKeyID.id {
                    case GlobalHotKeyManager.toggleHotKeyID:
                        manager.onHotKeyPressed?()
                    case GlobalHotKeyManager.screenshotHotKeyID:
                        manager.onScreenshotHotKeyPressed?()
                    case GlobalHotKeyManager.defineHotKeyID:
                        manager.onDefineHotKeyPressed?()
                    case GlobalHotKeyManager.transformHotKeyID:
                        manager.onTransformHotKeyPressed?()
                    case GlobalHotKeyManager.summarizeHotKeyID:
                        manager.onSummarizeHotKeyPressed?()
                    default:
                        break
                    }
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        guard status == noErr else {
            print("Failed to install event handler: \(status)")
            return
        }

        // Register toggle hotkey: Cmd + Shift + Space
        var toggleID = EventHotKeyID(
            signature: OSType(0x41555241), // "AURA"
            id: Self.toggleHotKeyID
        )
        let toggleStatus = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(cmdKey | shiftKey),
            toggleID,
            GetApplicationEventTarget(),
            0,
            &toggleHotKeyRef
        )
        if toggleStatus != noErr {
            print("Failed to register toggle hotkey: \(toggleStatus)")
        }

        // Register screenshot hotkey: Cmd + Shift + S
        var screenshotID = EventHotKeyID(
            signature: OSType(0x41555241), // "AURA"
            id: Self.screenshotHotKeyID
        )
        let screenshotStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_S),
            UInt32(cmdKey | shiftKey),
            screenshotID,
            GetApplicationEventTarget(),
            0,
            &screenshotHotKeyRef
        )
        if screenshotStatus != noErr {
            print("Failed to register screenshot hotkey: \(screenshotStatus)")
        }

        // Register define hotkey: Cmd + Shift + D
        var defineID = EventHotKeyID(
            signature: OSType(0x41555241), // "AURA"
            id: Self.defineHotKeyID
        )
        let defineStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_D),
            UInt32(cmdKey | shiftKey),
            defineID,
            GetApplicationEventTarget(),
            0,
            &defineHotKeyRef
        )
        if defineStatus != noErr {
            print("Failed to register define hotkey: \(defineStatus)")
        }

        // Register transform hotkey: Cmd + Shift + T
        var transformID = EventHotKeyID(
            signature: OSType(0x41555241), // "AURA"
            id: Self.transformHotKeyID
        )
        let transformStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_T),
            UInt32(cmdKey | shiftKey),
            transformID,
            GetApplicationEventTarget(),
            0,
            &transformHotKeyRef
        )
        if transformStatus != noErr {
            print("Failed to register transform hotkey: \(transformStatus)")
        }

        // Register summarize hotkey: Cmd + Shift + C
        var summarizeID = EventHotKeyID(
            signature: OSType(0x41555241), // "AURA"
            id: Self.summarizeHotKeyID
        )
        let summarizeStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_C),
            UInt32(cmdKey | shiftKey),
            summarizeID,
            GetApplicationEventTarget(),
            0,
            &summarizeHotKeyRef
        )
        if summarizeStatus != noErr {
            print("Failed to register summarize hotkey: \(summarizeStatus)")
        }
    }

    deinit {
        if let ref = toggleHotKeyRef {
            UnregisterEventHotKey(ref)
        }
        if let ref = screenshotHotKeyRef {
            UnregisterEventHotKey(ref)
        }
        if let ref = defineHotKeyRef {
            UnregisterEventHotKey(ref)
        }
        if let ref = transformHotKeyRef {
            UnregisterEventHotKey(ref)
        }
        if let ref = summarizeHotKeyRef {
            UnregisterEventHotKey(ref)
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }
}
