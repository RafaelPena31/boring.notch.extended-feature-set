import AppKit
import Defaults
import Foundation
import SwiftUI

@MainActor
final class SystemNotificationManager: ObservableObject {
    static let shared = SystemNotificationManager()

    enum ReplyOutcome: Equatable {
        case sent
        case draftedInApp
        case copiedAndOpened
        case failed
    }

    @Published private(set) var activeNotification: SystemNotification?
    @Published private(set) var queued: [SystemNotification] = []
    @Published private(set) var isWatching = false
    @Published private(set) var accessibilityAuthorized = false
    @Published private(set) var setupMessage: String?

    var isComposingReply = false {
        didSet {
            if isComposingReply {
                holdActive()
            } else {
                resumeExpiry(after: 4)
            }
        }
    }

    private let queueLimit = 8
    private var expiryTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var replyDrafts: [String: String] = [:]

    private init() {
        observers.append(NotificationCenter.default.addObserver(
            forName: .systemNotificationDidAppear,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let payload = note.userInfo as? [String: String] else { return }
            Task { @MainActor in self?.receive(payload) }
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: .systemNotificationDidDisappear,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let token = note.userInfo?["token"] as? String else { return }
            Task { @MainActor in self?.markExpired(token: token) }
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: .notificationHelperDisconnected,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleHelperDisconnect() }
        })
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        expiryTask?.cancel()
        reconnectTask?.cancel()
    }

    // MARK: - Lifecycle

    /// Starts observing only after the feature has been enabled. The caller
    /// decides whether this explicit action may show the Accessibility prompt.
    @discardableResult
    func start(promptIfNeeded: Bool) async -> Bool {
        guard Defaults[.notificationsEnabled] else {
            setupMessage = nil
            return false
        }

        reconnectTask?.cancel()
        accessibilityAuthorized = await XPCHelperClient.shared
            .ensureAccessibilityAuthorization(promptIfNeeded: promptIfNeeded)

        guard accessibilityAuthorized else {
            isWatching = false
            setupMessage = "Accessibility access is required to read notification banners."
            return false
        }

        for attempt in 0..<3 {
            if await XPCHelperClient.shared.startNotificationWatching() {
                isWatching = true
                setupMessage = nil
                return true
            }
            if attempt < 2 {
                try? await Task.sleep(for: .milliseconds(350 * (attempt + 1)))
            }
        }

        isWatching = false
        setupMessage = "Notification capture could not be started."
        return false
    }

    func refreshAccessibilityStatus() async {
        accessibilityAuthorized = await XPCHelperClient.shared.isAccessibilityAuthorized()
    }

    func stop() {
        reconnectTask?.cancel()
        reconnectTask = nil
        expiryTask?.cancel()
        expiryTask = nil
        XPCHelperClient.shared.stopNotificationWatching()
        isWatching = false
        releaseAllAndClear()
    }

    private func handleHelperDisconnect() {
        isWatching = false
        activeNotification = nil
        queued.removeAll()
        replyDrafts.removeAll()
        NotificationCenter.default.post(name: .notificationPresentationEnded, object: nil)

        guard Defaults[.notificationsEnabled] else { return }
        reconnectTask?.cancel()
        reconnectTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(750))
            guard !Task.isCancelled else { return }
            _ = await self?.start(promptIfNeeded: false)
        }
    }

    // MARK: - Incoming banners and queue

    private func receive(_ payload: [String: String]) {
        guard let token = payload["token"], !token.isEmpty else { return }

        func value(_ key: String) -> String? {
            guard let value = payload[key], !value.isEmpty else { return nil }
            return value
        }

        let actions = (value("actions") ?? "")
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
        let category = NotificationPolicyManager.category(
            bundleID: value("bundleID"),
            appName: value("appName"),
            title: value("title"),
            subtitle: value("subtitle"),
            body: value("body"),
            actions: actions
        )
        var notification = SystemNotification(
            id: token,
            appName: value("appName"),
            bundleID: value("bundleID"),
            title: value("title"),
            subtitle: value("subtitle"),
            body: value("body"),
            actions: actions,
            receivedAt: Date(),
            category: category
        )

        guard !isDuplicate(notification) else { return }
        let decision = NotificationPolicyManager.decision(for: notification)
        guard decision.shouldShow else { return }

        notification.isHeld = true
        XPCHelperClient.shared.holdNotification(token: notification.id)

        guard let current = activeNotification else {
            show(notification, shouldAutoOpen: decision.shouldOpenAutomatically)
            return
        }

        if isComposingReply || notification.category.priority <= current.category.priority {
            enqueue(notification)
            return
        }

        enqueue(current)
        show(notification, shouldAutoOpen: decision.shouldOpenAutomatically)
    }

    private func isDuplicate(_ notification: SystemNotification) -> Bool {
        if activeNotification?.id == notification.id || queued.contains(where: { $0.id == notification.id }) {
            return true
        }

        let candidates = [activeNotification].compactMap { $0 } + queued
        return candidates.contains {
            $0.bundleID == notification.bundleID
                && $0.title == notification.title
                && $0.body == notification.body
                && abs($0.receivedAt.timeIntervalSince(notification.receivedAt)) < 1.5
        }
    }

    private func enqueue(_ notification: SystemNotification) {
        queued.removeAll { $0.id == notification.id }
        queued.append(notification)
        queued.sort {
            if $0.category.priority == $1.category.priority {
                return $0.receivedAt < $1.receivedAt
            }
            return $0.category.priority > $1.category.priority
        }

        while queued.count > queueLimit {
            let dropped = queued.removeLast()
            XPCHelperClient.shared.releaseNotification(token: dropped.id)
            replyDrafts.removeValue(forKey: dropped.id)
        }
    }

    private func show(_ notification: SystemNotification, shouldAutoOpen: Bool) {
        activeNotification = notification
        scheduleExpiry(for: notification)

        if shouldAutoOpen {
            NotificationCenter.default.post(
                name: .notificationShouldAutoOpen,
                object: nil,
                userInfo: ["token": notification.id]
            )
        }
    }

    func cycleToNext() {
        guard !isComposingReply, let next = queued.first, let current = activeNotification else {
            return
        }
        queued.removeFirst()
        enqueue(current)
        let decision = NotificationPolicyManager.decision(for: next)
        show(next, shouldAutoOpen: decision.shouldOpenAutomatically)
    }

    func dismissActive(token: String? = nil) {
        guard let current = activeNotification else { return }
        if let token, current.id != token { return }

        expiryTask?.cancel()
        expiryTask = nil
        XPCHelperClient.shared.releaseNotification(token: current.id)
        replyDrafts.removeValue(forKey: current.id)

        if !queued.isEmpty {
            let next = queued.removeFirst()
            let decision = NotificationPolicyManager.decision(for: next)
            show(next, shouldAutoOpen: decision.shouldOpenAutomatically)
        } else {
            activeNotification = nil
            NotificationCenter.default.post(name: .notificationPresentationEnded, object: nil)
        }
    }

    func clear() {
        releaseAllAndClear()
        NotificationCenter.default.post(name: .notificationPresentationEnded, object: nil)
    }

    private func releaseAllAndClear() {
        expiryTask?.cancel()
        if let activeNotification {
            XPCHelperClient.shared.releaseNotification(token: activeNotification.id)
        }
        for notification in queued {
            XPCHelperClient.shared.releaseNotification(token: notification.id)
        }
        activeNotification = nil
        queued.removeAll()
        replyDrafts.removeAll()
    }

    private func markExpired(token: String) {
        if activeNotification?.id == token {
            activeNotification?.isLive = false
        }
        if let index = queued.firstIndex(where: { $0.id == token }) {
            queued[index].isLive = false
        }
    }

    // MARK: - Expiry and interaction

    func holdActive() {
        expiryTask?.cancel()
        expiryTask = nil
    }

    func resumeExpiry(after delay: TimeInterval? = nil) {
        guard let activeNotification else { return }
        scheduleExpiry(for: activeNotification, after: delay)
    }

    private func scheduleExpiry(
        for notification: SystemNotification,
        after customDelay: TimeInterval? = nil
    ) {
        expiryTask?.cancel()
        let delay = customDelay ?? notification.category.expirationInterval
        expiryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.dismissActive(token: notification.id)
        }
    }

    // MARK: - Reply drafts and actions

    func draft(for notificationID: String) -> String {
        replyDrafts[notificationID] ?? ""
    }

    func setDraft(_ text: String, for notificationID: String) {
        if text.isEmpty {
            replyDrafts.removeValue(forKey: notificationID)
        } else {
            replyDrafts[notificationID] = text
        }
    }

    @discardableResult
    func reply(to notification: SystemNotification, text: String) async -> ReplyOutcome {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failed }

        if await XPCHelperClient.shared.replyToNotification(
            token: notification.id,
            text: trimmed
        ) {
            NSSound(named: "Tink")?.play()
            dismissActive(token: notification.id)
            return .sent
        }

        if notification.bundleID == "com.apple.MobileSMS",
           let sender = notification.sender,
           await XPCHelperClient.shared.sendIMessage(trimmed, toChatNamed: sender) {
            NSSound(named: "Tink")?.play()
            dismissActive(token: notification.id)
            return .sent
        }

        if notification.bundleID == "net.whatsapp.WhatsApp",
           let sender = notification.sender,
           let phone = ContactAvatarManager.shared.phoneNumber(forContactNamed: sender),
           let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "whatsapp://send?phone=\(phone)&text=\(encoded)") {
            NSWorkspace.shared.open(url)
            setStatus("Draft opened in WhatsApp", for: notification.id)
            return .draftedInApp
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(trimmed, forType: .string)
        let opened = await openSourceApplication(for: notification)
        setStatus(opened ? "Reply copied — paste it in the app" : "Reply copied", for: notification.id)
        return .copiedAndOpened
    }

    @discardableResult
    func perform(_ action: String, on notification: SystemNotification) async -> Bool {
        let performed = await XPCHelperClient.shared.performNotificationAction(
            token: notification.id,
            name: action
        )
        if performed { dismissActive(token: notification.id) }
        return performed
    }

    @discardableResult
    func open(_ notification: SystemNotification) async -> Bool {
        let opened = await openSourceApplication(for: notification)
        if opened { dismissActive(token: notification.id) }
        return opened
    }

    private func openSourceApplication(for notification: SystemNotification) async -> Bool {
        if await XPCHelperClient.shared.openNotification(token: notification.id) { return true }
        guard let bundleID = notification.bundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { return false }

        return (try? await NSWorkspace.shared.openApplication(
            at: url,
            configuration: .init()
        )) != nil
    }

    func copyCode(from notification: SystemNotification) {
        guard let code = notification.detectedCode else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        setStatus("Code copied", for: notification.id)
        expiryTask?.cancel()
        expiryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            self?.dismissActive(token: notification.id)
        }
    }

    private func setStatus(_ message: String, for token: String) {
        guard activeNotification?.id == token else { return }
        activeNotification?.statusMessage = message
    }
}

extension Notification.Name {
    static let notificationShouldAutoOpen = Notification.Name("notificationShouldAutoOpen")
    static let notificationPresentationEnded = Notification.Name("notificationPresentationEnded")
}
