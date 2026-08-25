//
//  PomodoroManager.swift
//  boringNotch
//

import AppKit
import Combine
import Defaults
import SwiftUI
import UserNotifications

@MainActor
final class PomodoroManager: ObservableObject {
    static let shared = PomodoroManager()

    @Published private(set) var phase: PomodoroPhase = .focus
    @Published private(set) var remainingSeconds: Int
    @Published private(set) var isRunning = false
    @Published private(set) var completedSessions = 0
    @Published private(set) var hasStarted = false

    private var endDate: Date?
    private var timerCancellable: AnyCancellable?
    private var defaultsCancellables = Set<AnyCancellable>()
    private var notificationRequested = false

    var totalSeconds: Int {
        switch phase {
        case .focus: Defaults[.pomodoroFocusDuration]
        case .shortBreak: Defaults[.pomodoroShortBreakDuration]
        case .longBreak: Defaults[.pomodoroLongBreakDuration]
        }
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }

    var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var nextPhase: PomodoroPhase {
        switch phase {
        case .focus:
            completedSessions + 1 >= Defaults[.pomodoroSessionsBeforeLongBreak]
                ? .longBreak
                : .shortBreak
        case .shortBreak, .longBreak:
            .focus
        }
    }

    var phaseLabel: String {
        Self.label(for: phase)
    }

    var phaseIcon: String {
        switch phase {
        case .focus: "target"
        case .shortBreak: "cup.and.saucer"
        case .longBreak: "cup.and.saucer.fill"
        }
    }

    private init() {
        remainingSeconds = Defaults[.pomodoroFocusDuration]

        Defaults.publisher(.pomodoroFocusDuration)
            .merge(with: Defaults.publisher(.pomodoroShortBreakDuration))
            .merge(with: Defaults.publisher(.pomodoroLongBreakDuration))
            .sink { [weak self] _ in
                Task { @MainActor in self?.synchronizeIdleDuration() }
            }
            .store(in: &defaultsCancellables)
    }

    func start() {
        guard !isRunning else { return }
        hasStarted = true
        requestNotificationPermissionIfNeeded()
        endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        isRunning = true
        startTimer()
    }

    func pause() {
        if let endDate {
            remainingSeconds = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
        }
        endDate = nil
        timerCancellable?.cancel()
        timerCancellable = nil
        isRunning = false
    }

    func resume() {
        start()
    }

    func skip() {
        guard hasStarted else { return }
        pause()
        advancePhase()
    }

    func reset() {
        pause()
        hasStarted = false
        phase = .focus
        remainingSeconds = Defaults[.pomodoroFocusDuration]
        completedSessions = 0
    }

    /// Reconciles against wall-clock time after sleep or app inactivity.
    func reconcile() {
        tick(now: Date())
    }

    private func synchronizeIdleDuration() {
        guard !hasStarted else { return }
        remainingSeconds = totalSeconds
    }

    private func startTimer() {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                self?.tick(now: now)
            }
    }

    private func tick(now: Date) {
        guard isRunning, let endDate else { return }
        let remaining = Int(ceil(endDate.timeIntervalSince(now)))
        if remaining > 0 {
            remainingSeconds = remaining
        } else {
            remainingSeconds = 0
            phaseComplete()
        }
    }

    private func phaseComplete() {
        timerCancellable?.cancel()
        timerCancellable = nil
        endDate = nil
        isRunning = false

        let completedPhase = phase
        let upcomingPhase = nextPhase
        let shouldAutoStart = autoStartNext()

        playSound()
        sendNotification(completedPhase: completedPhase, nextPhase: upcomingPhase)
        advancePhase()

        if shouldAutoStart {
            start()
        }
    }

    private func advancePhase() {
        switch phase {
        case .focus:
            completedSessions += 1
            if completedSessions >= Defaults[.pomodoroSessionsBeforeLongBreak] {
                phase = .longBreak
                remainingSeconds = Defaults[.pomodoroLongBreakDuration]
                completedSessions = 0
            } else {
                phase = .shortBreak
                remainingSeconds = Defaults[.pomodoroShortBreakDuration]
            }
        case .shortBreak, .longBreak:
            phase = .focus
            remainingSeconds = Defaults[.pomodoroFocusDuration]
        }

        BoringViewCoordinator.shared.toggleSneakPeek(
            status: true,
            type: .pomodoro,
            duration: 3,
            icon: phaseIcon
        )
    }

    private func autoStartNext() -> Bool {
        switch phase {
        case .focus: Defaults[.pomodoroAutoStartBreaks]
        case .shortBreak, .longBreak: Defaults[.pomodoroAutoStartFocus]
        }
    }

    private func playSound() {
        let soundName: NSSound.Name
        switch Defaults[.pomodoroNotificationSound] {
        case .chime: soundName = NSSound.Name("Glass")
        case .bell: soundName = NSSound.Name("Funk")
        case .silent: return
        }

        (NSSound(named: soundName) ?? NSSound(named: NSSound.Name("Glass")))?.play()
    }

    private func sendNotification(completedPhase: PomodoroPhase, nextPhase: PomodoroPhase) {
        let content = UNMutableNotificationContent()
        content.title = String(
            localized: "pomodoro.notification.complete",
            defaultValue: "\(Self.label(for: completedPhase)) Complete"
        )
        content.body = String(
            localized: "pomodoro.notification.next",
            defaultValue: "Time for \(Self.label(for: nextPhase))."
        )
        content.sound = Defaults[.pomodoroNotificationSound] == .silent ? nil : .default

        UNUserNotificationCenter.current().add(
            UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
        )
    }

    private func requestNotificationPermissionIfNeeded() {
        guard !notificationRequested else { return }
        notificationRequested = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) {
            granted, _ in
            if !granted {
                print("Pomodoro: notification permission denied")
            }
        }
    }

    private static func label(for phase: PomodoroPhase) -> String {
        switch phase {
        case .focus: String(localized: "Focus")
        case .shortBreak: String(localized: "Short Break")
        case .longBreak: String(localized: "Long Break")
        }
    }
}
