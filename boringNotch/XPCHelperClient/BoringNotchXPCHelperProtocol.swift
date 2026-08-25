//
//  BoringNotchXPCHelperProtocol.swift
//  BoringNotchXPCHelper
//
//  Created by Alexander on 2025-11-16.
//

import Foundation

@objc protocol BoringNotchXPCHelperDelegate {
    func notificationDidAppear(_ payload: [String: String])
    func notificationDidDisappear(_ token: String)
}

/// The protocol that this service will vend as its API. This protocol will also need to be visible to the process hosting the service.
@objc protocol BoringNotchXPCHelperProtocol {
    func isAccessibilityAuthorized(with reply: @escaping (Bool) -> Void)
    func requestAccessibilityAuthorization()
    func ensureAccessibilityAuthorization(_ promptIfNeeded: Bool, with reply: @escaping (Bool) -> Void)
    // Keyboard backlight / CoreBrightness access (performed by the helper)
    func isKeyboardBrightnessAvailable(with reply: @escaping (Bool) -> Void)
    func currentKeyboardBrightness(with reply: @escaping (NSNumber?) -> Void)
    func setKeyboardBrightness(_ value: Float, with reply: @escaping (Bool) -> Void)
    // Screen brightness access (performed by the helper)
    func isScreenBrightnessAvailable(with reply: @escaping (Bool) -> Void)
    func currentScreenBrightness(with reply: @escaping (NSNumber?) -> Void)
    func setScreenBrightness(_ value: Float, with reply: @escaping (Bool) -> Void)
    // Notification Center banner observation (performed by the helper)
    func startNotificationWatching(with reply: @escaping (Bool) -> Void)
    func stopNotificationWatching()
    func replyToNotification(_ token: String, text: String, with reply: @escaping (Bool) -> Void)
    func sendIMessage(_ text: String, toChatNamed name: String, with reply: @escaping (Bool) -> Void)
    func performNotificationAction(_ token: String, name: String, with reply: @escaping (Bool) -> Void)
    func openNotification(_ token: String, with reply: @escaping (Bool) -> Void)
    func dismissNotification(_ token: String, with reply: @escaping (Bool) -> Void)
    func holdNotification(_ token: String)
    func releaseNotification(_ token: String)
}
