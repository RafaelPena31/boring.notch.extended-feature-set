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
}
