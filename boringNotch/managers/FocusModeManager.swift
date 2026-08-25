//
//  FocusModeManager.swift
//  boringNotch
//

import Defaults
import Foundation
import Intents

@MainActor
final class FocusModeManager: ObservableObject {
    static let shared = FocusModeManager()

    @Published private(set) var authorizationStatus: INFocusStatusAuthorizationStatus
    @Published private(set) var isFocused: Bool?
    @Published private(set) var overrideCategories: Set<SystemNotificationCategory> = []
    @Published private(set) var hasActiveOverride = false

    private let statusCenter = INFocusStatusCenter.default
    private var monitoringTask: Task<Void, Never>?

    private init() {
        authorizationStatus = statusCenter.authorizationStatus
        refresh()
    }

    deinit { monitoringTask?.cancel() }

    func startMonitoring() {
        guard monitoringTask == nil else { return }
        refresh()
        monitoringTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.refresh()
                await self?.refreshFilterOverride()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    func requestAuthorization() async {
        let status = await withCheckedContinuation { continuation in
            statusCenter.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        authorizationStatus = status
        refresh()
        await refreshFilterOverride()
    }

    func refresh() {
        authorizationStatus = statusCenter.authorizationStatus
        isFocused = authorizationStatus == .authorized
            ? statusCenter.focusStatus.isFocused
            : nil
        hasActiveOverride = Defaults[.notificationFocusOverrideActive]
        overrideCategories = Set(
            Defaults[.notificationFocusAllowedCategories].compactMap(
                SystemNotificationCategory.init(rawValue:)
            )
        )
    }

    /// Resolves the filter attached to the currently active Focus. The public
    /// API exposes the configured intent, but deliberately not the Focus name.
    func refreshFilterOverride() async {
        guard isFocused == true else {
            Defaults[.notificationFocusOverrideActive] = false
            Defaults[.notificationFocusAllowedCategories] = []
            hasActiveOverride = false
            overrideCategories = []
            return
        }

        do {
            let current = try await NotificationFocusFilterIntent.current
            let categories = Set(
                (current.allowedCategories ?? []).compactMap {
                    SystemNotificationCategory(rawValue: $0.rawValue)
                }
            )
            Defaults[.notificationFocusOverrideActive] = true
            Defaults[.notificationFocusAllowedCategories] = categories.map(\.rawValue)
            hasActiveOverride = true
            overrideCategories = categories
        } catch {
            Defaults[.notificationFocusOverrideActive] = false
            Defaults[.notificationFocusAllowedCategories] = []
            hasActiveOverride = false
            overrideCategories = []
        }
    }
}
