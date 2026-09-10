//
//  NotificationHistoryStore.swift
//  boringNotch
//

import Combine
import Defaults
import Foundation

@MainActor
final class NotificationHistoryStore: ObservableObject {
    static let shared = NotificationHistoryStore()
    static let capacity = 200

    @Published private(set) var items: [NotificationHistoryItem] = []
    @Published private(set) var undoItems: [NotificationHistoryItem] = []

    private var subscriptions = Set<AnyCancellable>()

    private init() {
        Publishers.Merge3(
            Defaults.publisher(.notificationsEnabled).map { _ in () },
            Defaults.publisher(.notificationIgnoredSources).map { _ in () },
            Defaults.publisher(.notificationCategoryPreferences).map { _ in () }
        )
        .sink { [weak self] in
            Task { @MainActor in self?.applyVisibility() }
        }
        .store(in: &subscriptions)
    }

    func item(id: String) -> NotificationHistoryItem? {
        items.first { $0.id == id }
    }

    func record(_ notification: SystemNotification, updateOnly: Bool) {
        guard Defaults[.notificationsEnabled] else {
            reset()
            return
        }
        guard NotificationPolicyManager.decision(for: notification).shouldShow else {
            discard(id: notification.id)
            return
        }

        if let index = items.firstIndex(where: { $0.id == notification.id }) {
            var updated = items[index]
            updated.update(from: notification)
            // Partial updates may omit source metadata retained by the snapshot.
            guard NotificationPolicyManager.decision(for: updated.displayNotification).shouldShow else {
                discard(id: notification.id)
                return
            }
            items[index] = updated
        } else if !updateOnly {
            items.insert(NotificationHistoryItem(notification), at: 0)
            items = Array(items.prefix(Self.capacity))
        }
    }

    func toggleSaved(id: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isSaved.toggle()
    }

    func remove(id: String) {
        guard let item = item(id: id) else { return }
        undoItems = [item]
        items.removeAll { $0.id == id }
    }

    func clear() {
        guard !items.isEmpty else { return }
        undoItems = items
        items.removeAll()
    }

    func undo() {
        guard Defaults[.notificationsEnabled] else {
            reset()
            return
        }
        let existing = Set(items.map(\.id))
        let restored = undoItems.filter {
            !existing.contains($0.id)
                && NotificationPolicyManager.decision(for: $0.displayNotification).shouldShow
        }
        items = Array(
            (items + restored)
                .sorted { $0.receivedAt > $1.receivedAt }
                .prefix(Self.capacity)
        )
        undoItems.removeAll()
    }

    func reset() {
        items.removeAll()
        undoItems.removeAll()
    }

    func applyVisibility() {
        guard Defaults[.notificationsEnabled] else {
            reset()
            return
        }
        items.removeAll {
            !NotificationPolicyManager.decision(for: $0.displayNotification).shouldShow
        }
        undoItems.removeAll {
            !NotificationPolicyManager.decision(for: $0.displayNotification).shouldShow
        }
    }

    func groups(savedOnly: Bool = false, source: String? = nil) -> [NotificationHistoryGroup] {
        let visible = items.filter {
            (!savedOnly || $0.isSaved) && (source == nil || source == $0.sourceKey)
        }
        .sorted { $0.receivedAt > $1.receivedAt }

        var seen = Set<String>()
        return visible.compactMap { item in
            guard seen.insert(item.sourceKey).inserted else { return nil }
            return NotificationHistoryGroup(
                id: item.sourceKey,
                name: item.sourceName,
                items: visible.filter { $0.sourceKey == item.sourceKey }
            )
        }
    }

    private func discard(id: String) {
        items.removeAll { $0.id == id }
        undoItems.removeAll { $0.id == id }
    }
}
