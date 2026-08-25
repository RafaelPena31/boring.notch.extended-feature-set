import AppKit
import ApplicationServices
import Foundation

private let notificationCenterBundleID = "com.apple.notificationcenterui"
private let notificationBannerSubroles: Set<String> = [
    "AXNotificationCenterBanner",
    "AXNotificationCenterAlert",
]

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
    private var pollTimer: DispatchSourceTimer?
    private var liveElements: [String: AXUIElement] = [:]
    private var heldTokens: Set<String> = []
    private var offscreenTokens: Set<String> = []
    private var lastRefresh = Date.distantPast

    private let pollInterval: TimeInterval = 0.35
    private let refreshInterval: TimeInterval = 2.5

    var isRunning: Bool { notificationCenterElement != nil }

    @discardableResult
    func start() -> Bool {
        guard AXIsProcessTrusted() else { return false }
        guard !isRunning else { return true }
        guard let app = NSRunningApplication.runningApplications(
            withBundleIdentifier: notificationCenterBundleID
        ).first else { return false }

        notificationCenterElement = AXUIElementCreateApplication(app.processIdentifier)

        // XPC services are driven by dispatch_main(), not a CFRunLoop. A
        // dispatch timer therefore remains reliable when Timer/AXObserver do not.
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + pollInterval, repeating: pollInterval)
        timer.setEventHandler { [weak self] in self?.scan() }
        timer.resume()
        pollTimer = timer
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
        liveElements.removeAll()
        heldTokens.removeAll()
        offscreenTokens.removeAll()
    }

    private func scan() {
        guard let notificationCenterElement else { return }
        var visibleTokens: Set<String> = []

        for window in (notificationCenterElement[kAXWindowsAttribute] as? [AXUIElement]) ?? [] {
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
            onBannerGone?(token)
        }

        refreshHeldBanners()
    }

    private func refreshHeldBanners() {
        guard !heldTokens.isEmpty else { return }
        let now = Date()
        guard now.timeIntervalSince(lastRefresh) >= refreshInterval else { return }
        lastRefresh = now

        for token in heldTokens {
            guard let banner = liveElements[token],
                  let action = rawAction(on: banner, matching: {
                      $0.localizedCaseInsensitiveContains("details")
                  })
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

        guard let windowValue = banner[kAXWindowAttribute] else { return }
        let window = windowValue as! AXUIElement
        var target = CGPoint(x: -5_000, y: -5_000)
        guard let position = AXValueCreate(.cgPoint, &target) else { return }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position)
    }

    func release(token: String) {
        heldTokens.remove(token)
        offscreenTokens.remove(token)
        guard let banner = liveElements[token],
              let closeAction = rawAction(on: banner, matching: {
                  $0.localizedCaseInsensitiveContains("close")
              })
        else { return }
        AXUIElementPerformAction(banner, closeAction as CFString)
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
        var actions = actionNames(of: banner)
            .map(actionLabel)
            .filter { $0 != kAXPressAction }

        for button in descendants(of: banner, matching: [kAXButtonRole, kAXMenuButtonRole]) {
            if let title = button[kAXTitleAttribute] as? String, !title.isEmpty {
                actions.append(title)
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
            if let action = rawAction(on: banner, matching: {
                $0.localizedCaseInsensitiveContains("reply")
            }) ?? rawAction(on: banner, matching: {
                $0.localizedCaseInsensitiveContains("details")
            }) {
                AXUIElementPerformAction(banner, action as CFString)
            } else if let replyButton = descendants(of: banner, matching: [kAXButtonRole]).first(where: {
                ($0[kAXTitleAttribute] as? String)?.localizedCaseInsensitiveContains("reply") == true
            }) {
                AXUIElementPerformAction(replyButton, kAXPressAction as CFString)
            }
            Thread.sleep(forTimeInterval: 0.4)
        }

        guard let field = replyField(in: banner) else { return false }
        AXUIElementSetAttributeValue(field, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        guard AXUIElementSetAttributeValue(
            field,
            kAXValueAttribute as CFString,
            text as CFString
        ) == .success else { return false }

        if let send = rawAction(on: banner, matching: {
            $0.localizedCaseInsensitiveContains("send")
        }) {
            return AXUIElementPerformAction(banner, send as CFString) == .success
        }
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
        guard let banner = liveElements[token],
              let close = rawAction(on: banner, matching: {
                  $0.localizedCaseInsensitiveContains("close")
              })
        else { return false }
        return AXUIElementPerformAction(banner, close as CFString) == .success
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
