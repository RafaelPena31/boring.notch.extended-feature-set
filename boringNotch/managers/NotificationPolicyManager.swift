//
//  NotificationPolicyManager.swift
//  boringNotch
//

import Defaults
import Foundation

struct NotificationPresentationDecision: Equatable {
    let shouldShow: Bool
    let shouldOpenAutomatically: Bool
}

@MainActor
enum NotificationPolicyManager {
    private static let messageBundleIDs: Set<String> = [
        "com.apple.MobileSMS", "net.whatsapp.WhatsApp", "ru.keepcoder.Telegram",
        "org.telegram.desktop", "com.hnc.Discord", "com.anthropic.claudefordesktop"
    ]
    private static let mailBundleIDs: Set<String> = [
        "com.apple.mail", "com.microsoft.Outlook"
    ]

    static func category(
        bundleID: String?,
        appName: String?,
        title: String?,
        subtitle: String?,
        body: String?,
        actions: [String]
    ) -> SystemNotificationCategory {
        let text = [title, subtitle, body].compactMap { $0 }.joined(separator: " ")
        let normalized = text.lowercased()

        // Incoming FaceTime banners can arrive while the app itself is not running,
        // so the helper's running-application lookup may not resolve a bundle ID.
        let isFaceTime = bundleID == "com.apple.FaceTime"
            || appName?.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare("FaceTime") == .orderedSame
        if isFaceTime { return .call }
        if OTPDetector.detect(in: text) != nil { return .otp }
        if actions.contains(where: {
            let kind = SystemNotificationActionClassifier.kind(of: $0)
            return kind == .accept || kind == .decline
        }) || ["incoming call", "incoming video", "chamada recebida", "videochamada recebida"].contains(
            where: normalized.contains
        ) {
            return .call
        }
        if ["permission", "authorization", "allow access", "grant access", "requires access"].contains(
            where: normalized.contains
        ) {
            return .permission
        }
        if ["approve", "approval", "review", "confirm", "decision required", "needs your input"].contains(
            where: normalized.contains
        ) {
            return .decision
        }
        if let bundleID, mailBundleIDs.contains(bundleID) { return .mail }
        if let bundleID, messageBundleIDs.contains(bundleID) { return .message }
        if let appName {
            let name = appName.lowercased()
            if name.contains("mail") || name.contains("outlook") { return .mail }
            if ["messages", "whatsapp", "telegram", "discord", "claude"].contains(
                where: name.contains
            ) { return .message }
        }
        return .other
    }

    static func decision(for notification: SystemNotification) -> NotificationPresentationDecision {
        guard Defaults[.notificationsEnabled], isAllowed(notification) else {
            return .init(shouldShow: false, shouldOpenAutomatically: false)
        }

        let preference = preferencesByCategory()[notification.category]
            ?? NotificationCategoryPreference(
                category: notification.category,
                isShown: true,
                automaticOpening: .never
            )
        guard preference.isShown else {
            return .init(shouldShow: false, shouldOpenAutomatically: false)
        }

        let focus = FocusModeManager.shared
        let autoOpen: Bool
        if focus.hasActiveOverride {
            autoOpen = focus.overrideCategories.contains(notification.category)
        } else {
            let sourceKey = NotificationSourceApp.sourceKey(
                bundleID: notification.bundleID,
                appName: notification.appName
            )
            let appPreference = Defaults[.notificationAppOpeningPreferences].first {
                $0.sourceKey == sourceKey
            }
            let openingPolicy = appPreference.map {
                $0.automaticOpening ?? preference.automaticOpening
            } ?? .never
            switch openingPolicy {
            case .never:
                autoOpen = false
            case .always:
                autoOpen = true
            case .outsideFocus:
                autoOpen = focus.isFocused == false
            }
        }
        return .init(shouldShow: true, shouldOpenAutomatically: autoOpen)
    }

    static func preferencesByCategory() -> [SystemNotificationCategory: NotificationCategoryPreference] {
        var preferences = Dictionary(
            uniqueKeysWithValues: NotificationCategoryPreference.recommended.map {
                ($0.category, $0)
            }
        )
        for preference in Defaults[.notificationCategoryPreferences] {
            preferences[preference.category] = preference
        }
        return preferences
    }

    private static func isAllowed(_ notification: SystemNotification) -> Bool {
        guard let sourceKey = NotificationSourceApp.sourceKey(
            bundleID: notification.bundleID,
            appName: notification.appName
        ) else {
            return true
        }
        return !Set(Defaults[.notificationIgnoredSources]).contains(sourceKey)
    }
}
