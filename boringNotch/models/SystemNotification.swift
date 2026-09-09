//
//  SystemNotification.swift
//  boringNotch
//

import AppKit
import Defaults
import Foundation

enum SystemNotificationCategory: String, CaseIterable, Codable, Identifiable, Defaults.Serializable {
    case otp
    case call
    case permission
    case decision
    case message
    case mail
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .otp: "OTP / security code"
        case .call: "Calls"
        case .permission: "Permissions"
        case .decision: "Decisions / reviews"
        case .message: "Messages"
        case .mail: "Mail"
        case .other: "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .otp: "number.square.fill"
        case .call: "phone.fill"
        case .permission: "hand.raised.fill"
        case .decision: "checkmark.bubble.fill"
        case .message: "message.fill"
        case .mail: "envelope.fill"
        case .other: "bell.fill"
        }
    }

    var priority: Int {
        switch self {
        case .call: 60
        case .otp: 50
        case .permission, .decision: 40
        case .message: 30
        case .mail: 20
        case .other: 10
        }
    }

    var expirationInterval: TimeInterval {
        switch self {
        case .call: 60
        case .otp: 18
        case .permission, .decision: 30
        case .message, .mail, .other: 9
        }
    }
}

enum NotificationAutomaticOpeningPolicy: String, CaseIterable, Codable, Identifiable, Defaults.Serializable {
    case never
    case outsideFocus
    case always

    var id: String { rawValue }

    var label: String {
        switch self {
        case .never: "Never"
        case .outsideFocus: "Only outside Focus"
        case .always: "Always"
        }
    }
}

struct NotificationCategoryPreference: Codable, Equatable, Defaults.Serializable {
    let category: SystemNotificationCategory
    var isShown: Bool
    var automaticOpening: NotificationAutomaticOpeningPolicy

    static let recommended: [NotificationCategoryPreference] = [
        .init(category: .otp, isShown: true, automaticOpening: .never),
        .init(category: .call, isShown: true, automaticOpening: .never),
        .init(category: .permission, isShown: true, automaticOpening: .never),
        .init(category: .decision, isShown: true, automaticOpening: .never),
        .init(category: .message, isShown: true, automaticOpening: .never),
        .init(category: .mail, isShown: true, automaticOpening: .never),
        .init(category: .other, isShown: true, automaticOpening: .never)
    ]
}

struct NotificationAppOpeningPreference: Codable, Equatable, Defaults.Serializable {
    let sourceKey: String
    // A stored nil explicitly opts into category rules. No stored preference means Never.
    var automaticOpening: NotificationAutomaticOpeningPolicy?
}

enum SystemNotificationActionKind: Hashable {
    case reply
    case details
    case send
    case close
    case accept
    case decline
}

enum SystemNotificationActionClassifier {
    private static let labels: [SystemNotificationActionKind: Set<String>] = [
        .reply: ["__boring_reply", "reply", "responder", "repondre", "antworten", "rispondi"],
        .details: [
            "__boring_details", "details", "show details", "detalhes", "mostrar detalhes",
            "detalles", "mostrar detalles", "afficher les details", "details anzeigen",
            "dettagli", "mostra dettagli",
        ],
        .send: ["__boring_send", "send", "enviar", "envoyer", "senden", "invia"],
        .close: [
            "__boring_close", "close", "dismiss", "fechar", "dispensar", "cerrar",
            "fermer", "schliessen", "schließen", "chiudi",
        ],
        .accept: [
            "accept", "answer", "join", "aceitar", "atender", "entrar",
            "aceptar", "contestar", "rejoindre", "accepter", "annehmen", "accetta",
        ],
        .decline: [
            "decline", "reject", "recusar", "rejeitar", "rechazar", "refuser",
            "ablehnen", "rifiuta",
        ],
    ]

    static func kind(of action: String) -> SystemNotificationActionKind? {
        let normalized = action.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale.current
        )
        .lowercased()
        .trimmingCharacters(in: .whitespacesAndNewlines)

        return labels.first { $0.value.contains(normalized) }?.key
    }
}

struct SystemNotification: Identifiable, Equatable {
    let id: String
    let appName: String?
    let bundleID: String?
    var title: String?
    var subtitle: String?
    var body: String?
    var actions: [String]
    let receivedAt: Date
    var category: SystemNotificationCategory
    var isLive: Bool = true
    var isHeld: Bool = false
    var statusMessage: String?

    var combinedText: String {
        [title, subtitle, body].compactMap { $0 }.joined(separator: " ")
    }

    var detectedCode: String? { OTPDetector.detect(in: combinedText) }

    var canReply: Bool {
        isLive && category != .call && actions.contains { action in
            SystemNotificationActionClassifier.kind(of: action) == .reply
        }
    }

    var sender: String? { title }

    /// Prefer actual content over category labels and repeated source metadata.
    var previewText: String {
        meaningfulText(body) ?? meaningfulText(subtitle) ?? meaningfulText(title)
            ?? "Open the app to view this notification"
    }

    var secondaryText: String? {
        guard let subtitle = meaningfulText(subtitle),
              subtitle != previewText, subtitle != title else { return nil }
        return subtitle
    }

    private func meaningfulText(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty, value != appName else { return nil }
        return value
    }

    mutating func updateContent(from notification: SystemNotification) {
        // A banner can expose more text/actions after Notification Center expands it.
        // Keep queue age, hold state and any draft/status belonging to the same token.
        title = notification.title ?? title
        subtitle = notification.subtitle ?? subtitle
        body = notification.body ?? body
        actions = notification.actions
        category = notification.category
        isLive = notification.isLive
    }

    var appIcon: NSImage? {
        guard let bundleID,
              let applicationURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: bundleID
              )
        else { return nil }
        return NSWorkspace.shared.icon(forFile: applicationURL.path)
    }
}

struct NotificationSourceApp: Identifiable, Hashable, Codable, Defaults.Serializable {
    let name: String
    let bundleID: String?

    var id: String { sourceKey }

    var sourceKey: String {
        if let bundleID {
            return "bundle:\(bundleID)"
        }
        return "name:\(Self.normalizedName(name))"
    }

    static func make(bundleID: String?, appName: String?) -> NotificationSourceApp? {
        let cleanBundleID = cleaned(bundleID)
        let cleanName = cleaned(appName)

        if let cleanBundleID {
            return .init(name: cleanName ?? cleanBundleID, bundleID: cleanBundleID)
        }
        guard let cleanName else { return nil }
        return .init(name: cleanName, bundleID: nil)
    }

    static func sourceKey(bundleID: String?, appName: String?) -> String? {
        make(bundleID: bundleID, appName: appName)?.sourceKey
    }

    private static func normalizedName(_ value: String) -> String {
        value
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .lowercased()
    }

    private static func cleaned(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else { return nil }
        return value
    }

    static let suggested: [NotificationSourceApp] = [
        .init(name: "Messages", bundleID: "com.apple.MobileSMS"),
        .init(name: "FaceTime", bundleID: "com.apple.FaceTime"),
        .init(name: "Mail", bundleID: "com.apple.mail"),
        .init(name: "Outlook", bundleID: "com.microsoft.Outlook"),
        .init(name: "WhatsApp", bundleID: "net.whatsapp.WhatsApp"),
        .init(name: "Telegram", bundleID: "ru.keepcoder.Telegram"),
        .init(name: "Telegram Desktop", bundleID: "org.telegram.desktop"),
        .init(name: "Discord", bundleID: "com.hnc.Discord"),
        .init(name: "Claude", bundleID: "com.anthropic.claudefordesktop")
    ]
}
