import AppKit
import ApplicationServices
import Foundation

private let notificationCenterBundleID = "com.apple.notificationcenterui"
private let notificationBannerSubroles: Set<String> = [
    "AXNotificationCenterBanner",
    "AXNotificationCenterAlert",
]

private enum NotificationAXSemanticAction: String, CaseIterable {
    case reply = "__boring_reply"
    case details = "__boring_details"
    case send = "__boring_send"
    case close = "__boring_close"

    var localizedLabels: Set<String> {
        switch self {
        case .reply:
            return ["reply", "responder", "repondre", "antworten", "rispondi"]
        case .details:
            return [
                "details", "show details", "detalhes", "mostrar detalhes",
                "detalles", "mostrar detalles", "afficher les details",
                "details anzeigen", "dettagli", "mostra dettagli",
            ]
        case .send:
            return ["send", "enviar", "envoyer", "senden", "invia"]
        case .close:
            return [
                "close", "dismiss", "fechar", "dispensar", "cerrar",
                "fermer", "schliessen", "schließen", "chiudi",
            ]
        }
    }
}

struct CapturedNotification {
    let token: String
    let appName: String?
    let bundleID: String?
    let title: String?
    let subtitle: String?
    let body: String?
    let actions: [String]
}

/// Observes ephemeral Notification Center banners through Accessibility.
/// All state is confined to the main dispatch queue by the XPC service.
final class NotificationWatcher {
    var onBanner: ((CapturedNotification) -> Void)?
    var onBannerGone: ((String) -> Void)?

    private var notificationCenterElement: AXUIElement?
    private var notificationCenterPID: pid_t?
    private var pollTimer: DispatchSourceTimer?
    private var liveElements: [String: AXUIElement] = [:]
    private var heldTokens: Set<String> = []
    private var offscreenTokens: Set<String> = []
    private var originalWindowPositions: [String: CGPoint] = [:]
    private var lastRefresh = Date.distantPast

    private let pollInterval: TimeInterval = 0.35
    private let refreshInterval: TimeInterval = 2.5

    var isRunning: Bool { pollTimer != nil }

    @discardableResult
    func start() -> Bool {
        guard AXIsProcessTrusted() else { return false }
        guard !isRunning else { return true }

        // XPC services are driven by dispatch_main(), not a CFRunLoop. A
        // dispatch timer therefore remains reliable when Timer/AXObserver do not.
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + pollInterval, repeating: pollInterval)
        timer.setEventHandler { [weak self] in self?.scan() }
        timer.resume()
        pollTimer = timer
        _ = reconnectNotificationCenterIfNeeded()
        scan()
        return true
    }

    func stop() {
        for token in Array(heldTokens) {
            release(token: token)
        }
        pollTimer?.cancel()
        pollTimer = nil
        notificationCenterElement = nil
        notificationCenterPID = nil
        liveElements.removeAll()
        heldTokens.removeAll()
        offscreenTokens.removeAll()
        originalWindowPositions.removeAll()
    }

    private func scan() {
        guard reconnectNotificationCenterIfNeeded(), let notificationCenterElement else { return }
        guard let windows = notificationCenterElement[kAXWindowsAttribute] as? [AXUIElement] else {
            invalidateNotificationCenterConnection()
            return
        }
        var visibleTokens: Set<String> = []

        for window in windows {
            guard window[kAXSubroleAttribute] as? String == "AXSystemDialog" else { continue }
            for banner in banners(in: window) {
                guard let token = banner[kAXIdentifierAttribute] as? String else { continue }
                visibleTokens.insert(token)
                guard liveElements[token] == nil else { continue }
                liveElements[token] = banner
                onBanner?(capture(banner, token: token))
            }
        }

        for token in Array(liveElements.keys) where !visibleTokens.contains(token) {
            liveElements[token] = nil
            heldTokens.remove(token)
            offscreenTokens.remove(token)
            originalWindowPositions.removeValue(forKey: token)
            onBannerGone?(token)
        }

        refreshHeldBanners()
    }

    private func reconnectNotificationCenterIfNeeded() -> Bool {
        guard let application = NSRunningApplication.runningApplications(
            withBundleIdentifier: notificationCenterBundleID
        ).first(where: { !$0.isTerminated }) else {
            invalidateNotificationCenterConnection()
            return false
        }

        if notificationCenterPID == application.processIdentifier,
           let notificationCenterElement,
           notificationCenterElement[kAXRoleAttribute] as? String != nil {
            return true
        }

        invalidateNotificationCenterConnection()
        notificationCenterPID = application.processIdentifier
        notificationCenterElement = AXUIElementCreateApplication(application.processIdentifier)
        return true
    }

    private func invalidateNotificationCenterConnection() {
        guard notificationCenterElement != nil || !liveElements.isEmpty else { return }
        notificationCenterElement = nil
        notificationCenterPID = nil

        let expiredTokens = Array(liveElements.keys)
        liveElements.removeAll()
        heldTokens.removeAll()
        offscreenTokens.removeAll()
        originalWindowPositions.removeAll()
        expiredTokens.forEach { onBannerGone?($0) }
    }

    private func refreshHeldBanners() {
        guard !heldTokens.isEmpty else { return }
        let now = Date()
        guard now.timeIntervalSince(lastRefresh) >= refreshInterval else { return }
        lastRefresh = now

        for token in heldTokens {
            guard let banner = liveElements[token],
                  let action = rawAction(on: banner, semantic: .details)
            else { continue }
            AXUIElementPerformAction(banner, action as CFString)
        }
    }

    /// Keeps the real banner actionable while the notch is showing it, and
    /// moves its window off screen so only one notification surface is visible.
    func hold(token: String) {
        guard let banner = liveElements[token] else { return }
        heldTokens.insert(token)
        guard !offscreenTokens.contains(token) else { return }
        offscreenTokens.insert(token)

        guard let window = axElementAttribute(kAXWindowAttribute, of: banner) else { return }
        if let position = windowPosition(of: window) {
            originalWindowPositions[token] = position
        }
        var target = CGPoint(x: -5_000, y: -5_000)
        guard let position = AXValueCreate(.cgPoint, &target) else { return }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position)
    }

    func release(token: String) {
        heldTokens.remove(token)
        offscreenTokens.remove(token)
        guard let banner = liveElements[token] else {
            originalWindowPositions.removeValue(forKey: token)
            return
        }

        if !performSemanticAction(.close, on: banner) {
            restoreWindowPosition(for: token, banner: banner)
        }
        originalWindowPositions.removeValue(forKey: token)
    }

    private func banners(in element: AXUIElement, depth: Int = 0) -> [AXUIElement] {
        guard depth < 14 else { return [] }
        if let subrole = element[kAXSubroleAttribute] as? String,
           notificationBannerSubroles.contains(subrole) {
            return [element]
        }
        return ((element[kAXChildrenAttribute] as? [AXUIElement]) ?? [])
            .flatMap { banners(in: $0, depth: depth + 1) }
    }

    private func capture(_ banner: AXUIElement, token: String) -> CapturedNotification {
        var textParts: [String: String] = [:]
        collectLabelledText(in: banner, into: &textParts)

        let appName = (banner["AXAttributedDescription"] as? NSAttributedString)?.string
            .components(separatedBy: ",").first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: Self.bidiControlCharacters)

        return CapturedNotification(
            token: token,
            appName: appName,
            bundleID: appName.flatMap(bundleID(forAppNamed:)),
            title: textParts["title"],
            subtitle: textParts["subtitle"],
            body: textParts["body"],
            actions: availableActions(on: banner)
        )
    }

    private func collectLabelledText(
        in element: AXUIElement,
        into parts: inout [String: String],
        depth: Int = 0
    ) {
        guard depth < 10 else { return }
        if let identifier = element[kAXIdentifierAttribute] as? String,
           ["title", "subtitle", "body"].contains(identifier),
           let value = element[kAXValueAttribute] as? String {
            parts[identifier] = value.trimmingCharacters(
                in: Self.bidiControlCharacters.union(.whitespacesAndNewlines)
            )
        }
        for child in (element[kAXChildrenAttribute] as? [AXUIElement]) ?? [] {
            collectLabelledText(in: child, into: &parts, depth: depth + 1)
        }
    }

    private func availableActions(on banner: AXUIElement) -> [String] {
        var actions: [String] = []

        for rawAction in actionNames(of: banner) where rawAction != kAXPressAction {
            let label = actionLabel(rawAction)
            if let semantic = semanticAction(for: label) {
                if semantic == .reply || semantic == .details {
                    actions.append(semantic.rawValue)
                }
            } else {
                actions.append(label)
            }
        }

        for button in descendants(of: banner, matching: [kAXButtonRole, kAXMenuButtonRole]) {
            if let title = button[kAXTitleAttribute] as? String, !title.isEmpty {
                if let semantic = semanticAction(for: title) {
                    if semantic == .reply || semantic == .details {
                        actions.append(semantic.rawValue)
                    }
                } else {
                    actions.append(title)
                }
            }
        }
        return Array(Set(actions)).sorted()
    }

    private func actionNames(of element: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success else { return [] }
        return (names as? [String]) ?? []
    }

    private func actionLabel(_ raw: String) -> String {
        guard raw.hasPrefix("Name:") else { return raw }
        return String(raw.dropFirst("Name:".count).prefix { !$0.isNewline })
    }

    private func normalizedActionLabel(_ label: String) -> String {
        label.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale.current
        )
        .lowercased()
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func semanticAction(for label: String) -> NotificationAXSemanticAction? {
        let normalized = normalizedActionLabel(label)
        if let canonical = NotificationAXSemanticAction(rawValue: normalized) {
            return canonical
        }
        return NotificationAXSemanticAction.allCases.first {
            $0.localizedLabels.contains(normalized)
        }
    }

    private func rawAction(
        on element: AXUIElement,
        semantic: NotificationAXSemanticAction
    ) -> String? {
        actionNames(of: element).first {
            semanticAction(for: actionLabel($0)) == semantic
        }
    }

    @discardableResult
    private func performSemanticAction(
        _ semantic: NotificationAXSemanticAction,
        on element: AXUIElement
    ) -> Bool {
        if let raw = rawAction(on: element, semantic: semantic),
           AXUIElementPerformAction(element, raw as CFString) == .success {
            return true
        }

        guard let button = descendants(
            of: element,
            matching: [kAXButtonRole, kAXMenuButtonRole]
        ).first(where: {
            guard let title = $0[kAXTitleAttribute] as? String else { return false }
            return semanticAction(for: title) == semantic
        }) else { return false }

        return AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
    }

    private func windowPosition(of window: AXUIElement) -> CGPoint? {
        guard let rawValue = window[kAXPositionAttribute] else { return nil }
        let object = rawValue as AnyObject
        guard CFGetTypeID(object) == AXValueGetTypeID() else { return nil }
        let positionValue = object as! AXValue
        var point = CGPoint.zero
        guard AXValueGetValue(positionValue, .cgPoint, &point) else { return nil }
        return point
    }

    private func restoreWindowPosition(for token: String, banner: AXUIElement) {
        guard let originalPosition = originalWindowPositions[token],
              let window = axElementAttribute(kAXWindowAttribute, of: banner)
        else { return }
        var position = originalPosition
        guard let value = AXValueCreate(.cgPoint, &position) else { return }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
    }

    private func axElementAttribute(_ attribute: String, of element: AXUIElement) -> AXUIElement? {
        guard let rawValue = element[attribute] else { return nil }
        let object = rawValue as AnyObject
        guard CFGetTypeID(object) == AXUIElementGetTypeID() else { return nil }
        return (object as! AXUIElement)
    }

    private func rawAction(
        on element: AXUIElement,
        matching predicate: (String) -> Bool
    ) -> String? {
        actionNames(of: element).first { predicate(actionLabel($0)) }
    }

    private func descendants(
        of element: AXUIElement,
        matching roles: [String],
        depth: Int = 0
    ) -> [AXUIElement] {
        guard depth < 10 else { return [] }
        var result: [AXUIElement] = []
        if depth > 0,
           let role = element[kAXRoleAttribute] as? String,
           roles.contains(role) {
            result.append(element)
        }
        for child in (element[kAXChildrenAttribute] as? [AXUIElement]) ?? [] {
            result += descendants(of: child, matching: roles, depth: depth + 1)
        }
        return result
    }

    private func replyField(in element: AXUIElement) -> AXUIElement? {
        descendants(of: element, matching: [kAXTextFieldRole, kAXTextAreaRole]).first
    }

    func reply(token: String, text: String) -> Bool {
        guard let banner = liveElements[token] else { return false }

        if replyField(in: banner) == nil {
            _ = performSemanticAction(.reply, on: banner)
                || performSemanticAction(.details, on: banner)
            Thread.sleep(forTimeInterval: 0.4)
        }

        guard let field = replyField(in: banner) else { return false }
        AXUIElementSetAttributeValue(field, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        guard AXUIElementSetAttributeValue(
            field,
            kAXValueAttribute as CFString,
            text as CFString
        ) == .success else { return false }

        if performSemanticAction(.send, on: banner) { return true }
        return AXUIElementPerformAction(field, kAXConfirmAction as CFString) == .success
    }

    func performAction(token: String, name: String) -> Bool {
        guard let banner = liveElements[token] else { return false }
        if let raw = rawAction(on: banner, matching: {
            $0.localizedCaseInsensitiveCompare(name) == .orderedSame
        }) {
            return AXUIElementPerformAction(banner, raw as CFString) == .success
        }
        guard let button = descendants(
            of: banner,
            matching: [kAXButtonRole, kAXMenuButtonRole]
        ).first(where: {
            ($0[kAXTitleAttribute] as? String)?.localizedCaseInsensitiveCompare(name) == .orderedSame
        }) else { return false }
        return AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
    }

    func open(token: String) -> Bool {
        guard let banner = liveElements[token] else { return false }
        return AXUIElementPerformAction(banner, kAXPressAction as CFString) == .success
    }

    func dismiss(token: String) -> Bool {
        guard let banner = liveElements[token] else { return false }
        return performSemanticAction(.close, on: banner)
    }

    private func bundleID(forAppNamed name: String) -> String? {
        let normalizedName = Self.normalizedAppName(name)
        guard !normalizedName.isEmpty else { return nil }
        return NSWorkspace.shared.runningApplications.first {
            guard let localizedName = $0.localizedName else { return false }
            return Self.normalizedAppName(localizedName) == normalizedName
        }?.bundleIdentifier
    }

    private static func normalizedAppName(_ name: String) -> String {
        name.trimmingCharacters(in: bidiControlCharacters.union(.whitespacesAndNewlines))
            .filter { !$0.unicodeScalars.allSatisfy(bidiControlCharacters.contains) }
            .lowercased()
    }

    private static let bidiControlCharacters: CharacterSet = {
        var characters = CharacterSet(charactersIn: "\u{200E}\u{200F}")
        characters.insert(charactersIn: "\u{2066}"..."\u{2069}")
        characters.insert(charactersIn: "\u{202A}"..."\u{202E}")
        return characters
    }()
}

private extension AXUIElement {
    subscript(attribute: String) -> Any? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            self,
            attribute as CFString,
            &value
        ) == .success else { return nil }
        return value
    }
}
