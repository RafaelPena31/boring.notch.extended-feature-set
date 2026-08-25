//
//  CaffeineManager.swift
//  boringNotch
//

import Combine
import Defaults
import Foundation
import IOKit.pwr_mgt

final class CaffeineManager: ObservableObject {
    static let shared = CaffeineManager()

    @Published private(set) var isActive = false
    @Published private(set) var lastError: String?

    private var assertionID = IOPMAssertionID(0)
    private var hasAssertion = false
    private var activationDeadline: Date?
    private var safetyTimer: Timer?
    private var batteryObserverID: Int?
    private var timeoutCancellable: AnyCancellable?

    private init() {
        setupBatteryObserver()
        timeoutCancellable = Defaults.publisher(.caffeineSafetyTimeout)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard self?.isActive == true else { return }
                self?.startSafetyTimer(resetDeadline: true)
            }
    }

    func activate() {
        guard Defaults[.caffeineEnabled] else { return }
        guard !hasAssertion else { return }
        lastError = nil

        if assertionID != 0, !releaseAssertion() {
            lastError = String(localized: "Keep Awake could not replace its previous power assertion.")
            return
        }

        guard batteryLevelAllowsActivation() else { return }

        var newAssertionID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Boring Notch Keep Awake" as CFString,
            &newAssertionID
        )

        guard result == kIOReturnSuccess else {
            assertionID = IOPMAssertionID(0)
            hasAssertion = false
            isActive = false
            lastError = String(
                localized: "Keep Awake could not create a macOS power assertion."
            )
            return
        }

        assertionID = newAssertionID
        hasAssertion = true
        isActive = true
        startSafetyTimer(resetDeadline: true)
    }

    func deactivate() {
        safetyTimer?.invalidate()
        safetyTimer = nil
        activationDeadline = nil

        guard hasAssertion || assertionID != 0 else {
            isActive = false
            return
        }

        guard releaseAssertion() else {
            hasAssertion = true
            isActive = true
            lastError = String(localized: "Keep Awake could not release its macOS power assertion.")
            return
        }

        isActive = false
        lastError = nil
    }

    func toggle() {
        isActive ? deactivate() : activate()
    }

    func reconcile() {
        guard isActive else { return }
        checkBatteryThreshold(level: BatteryStatusViewModel.shared.levelBattery)
        guard isActive, let activationDeadline else { return }
        if activationDeadline <= Date() {
            deactivate()
        } else {
            startSafetyTimer(resetDeadline: false)
        }
    }

    private func releaseAssertion() -> Bool {
        guard assertionID != 0 else {
            hasAssertion = false
            return true
        }

        let result = IOPMAssertionRelease(assertionID)
        guard result == kIOReturnSuccess else { return false }

        assertionID = IOPMAssertionID(0)
        hasAssertion = false
        return true
    }

    private func startSafetyTimer(resetDeadline: Bool) {
        safetyTimer?.invalidate()
        safetyTimer = nil

        let timeout = Defaults[.caffeineSafetyTimeout].rawValue
        guard timeout > 0 else {
            activationDeadline = nil
            return
        }

        if resetDeadline || activationDeadline == nil {
            activationDeadline = Date().addingTimeInterval(timeout)
        }

        guard let activationDeadline else { return }
        let remaining = activationDeadline.timeIntervalSinceNow
        guard remaining > 0 else {
            deactivate()
            return
        }

        safetyTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) {
            [weak self] _ in
            self?.deactivate()
        }
        safetyTimer?.tolerance = min(60, remaining * 0.05)
    }

    private func setupBatteryObserver() {
        batteryObserverID = BatteryActivityManager.shared.addObserver { [weak self] event in
            guard let self else { return }
            switch event {
            case .batteryLevelChanged(let level):
                self.checkBatteryThreshold(level: level)
            case .powerSourceChanged(let isPluggedIn):
                if !isPluggedIn {
                    self.checkBatteryThreshold(level: BatteryStatusViewModel.shared.levelBattery)
                }
            default:
                break
            }
        }
    }

    private func batteryLevelAllowsActivation() -> Bool {
        let battery = BatteryStatusViewModel.shared
        guard battery.maxCapacity > 0, !battery.isPluggedIn else { return true }
        guard battery.levelBattery > Float(Defaults[.caffeineLowBatteryCutoff]) else {
            lastError = String(localized: "Keep Awake is unavailable at the current battery level.")
            return false
        }
        return true
    }

    private func checkBatteryThreshold(level: Float) {
        let battery = BatteryStatusViewModel.shared
        guard isActive, battery.maxCapacity > 0, !battery.isPluggedIn else { return }
        if level <= Float(Defaults[.caffeineLowBatteryCutoff]) {
            deactivate()
        }
    }

    deinit {
        safetyTimer?.invalidate()
        if let batteryObserverID {
            BatteryActivityManager.shared.removeObserver(byId: batteryObserverID)
        }
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
        }
    }
}
