//
//  NotificationFocusFilterIntent.swift
//  boringNotch
//

import AppIntents
import Defaults
import Foundation

enum FocusNotificationCategory: String, AppEnum {
    case otp
    case call
    case permission
    case decision
    case message
    case mail
    case other

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Notification category"
    )
    static let caseDisplayRepresentations: [FocusNotificationCategory: DisplayRepresentation] = [
        .otp: "OTP and security codes",
        .call: "Calls",
        .permission: "Permissions",
        .decision: "Decisions and reviews",
        .message: "Messages",
        .mail: "Mail",
        .other: "Other"
    ]
}

struct NotificationFocusFilterIntent: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "Boring Notch notification opening"
    static let description = IntentDescription(
        "Choose which notification categories may open the notch automatically in this Focus."
    )
    static let openAppWhenRun = false

    @Parameter(title: "Categories allowed to open the notch")
    var allowedCategories: [FocusNotificationCategory]?

    var displayRepresentation: DisplayRepresentation {
        let count = allowedCategories?.count ?? 0
        return DisplayRepresentation(
            title: "Boring Notch notifications",
            subtitle: count == 0 ? "No automatic opening" : "\(count) categories allowed"
        )
    }

    func perform() async throws -> some IntentResult {
        let categories = allowedCategories?.map(\.rawValue) ?? []
        Defaults[.notificationFocusOverrideActive] = true
        Defaults[.notificationFocusAllowedCategories] = categories
        await MainActor.run { FocusModeManager.shared.refresh() }
        return .result()
    }
}
