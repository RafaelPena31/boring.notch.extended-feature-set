//
//  NotificationHistoryItem.swift
//  boringNotch
//

import Foundation

/// Captured values only; history never keeps a native banner or its actions alive.
struct NotificationHistoryItem: Identifiable, Equatable {
    let id: String
    let receivedAt: Date
    var appName: String?
    var bundleID: String?
    var title: String?
    var subtitle: String?
    var body: String?
    var category: SystemNotificationCategory
    var isSaved = false

    init(_ notification: SystemNotification) {
        id = notification.id
        receivedAt = notification.receivedAt
        appName = notification.appName
        bundleID = notification.bundleID
        title = notification.title
        subtitle = notification.subtitle
        body = notification.body
        category = notification.category
    }

    var sourceKey: String {
        NotificationSourceApp.sourceKey(bundleID: bundleID, appName: appName)
            ?? "unknown-source"
    }

    var sourceName: String {
        NotificationSourceApp.make(bundleID: bundleID, appName: appName)?.name
            ?? "Unknown app"
    }

    var displayNotification: SystemNotification {
        SystemNotification(
            id: id,
            appName: appName,
            bundleID: bundleID,
            title: title,
            subtitle: subtitle,
            body: body,
            actions: [],
            receivedAt: receivedAt,
            category: category,
            isLive: false
        )
    }

    mutating func update(from notification: SystemNotification) {
        appName = notification.appName ?? appName
        bundleID = notification.bundleID ?? bundleID
        title = notification.title ?? title
        subtitle = notification.subtitle ?? subtitle
        body = notification.body ?? body
        category = notification.category
    }
}

struct NotificationHistoryGroup: Identifiable {
    let id: String
    let name: String
    let items: [NotificationHistoryItem]
}
