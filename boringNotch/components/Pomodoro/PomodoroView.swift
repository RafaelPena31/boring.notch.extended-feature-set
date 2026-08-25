//
//  PomodoroView.swift
//  boringNotch
//

import Defaults
import SwiftUI

struct PomodoroView: View {
    @ObservedObject private var pomodoroManager = PomodoroManager.shared
    @Default(.pomodoroFocusDuration) private var focusDuration
    @Default(.pomodoroShortBreakDuration) private var shortBreakDuration
    @Default(.pomodoroLongBreakDuration) private var longBreakDuration
    @Default(.pomodoroSessionsBeforeLongBreak) private var sessionsBeforeLongBreak

    var body: some View {
        Group {
            if pomodoroManager.hasStarted {
                activeView
            } else {
                idleView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var idleView: some View {
        VStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.system(size: 22))
                .foregroundStyle(.gray)

            Text("Pomodoro Timer")
                .font(.headline)
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                durationPill(icon: "target", value: focusDuration / 60)
                durationPill(icon: "cup.and.saucer", value: shortBreakDuration / 60)
                durationPill(icon: "cup.and.saucer.fill", value: longBreakDuration / 60)
            }

            Button("Start Focus") {
                pomodoroManager.start()
            }
            .font(.headline)
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(0.15)))
        }
    }

    private var activeView: some View {
        VStack(spacing: 0) {
            Spacer()

            HStack(spacing: 6) {
                Image(systemName: pomodoroManager.phaseIcon)
                    .font(.system(size: 12))
                Text(pomodoroManager.phaseLabel)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(phaseColor.opacity(0.7))

            Text(pomodoroManager.formattedTime)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .opacity(pomodoroManager.isRunning ? 1 : 0.5)
                .padding(.vertical, 6)

            pomodoroProgress
                .padding(.horizontal, 24)

            if pomodoroManager.phase == .focus {
                Text(
                    "Session \(pomodoroManager.completedSessions + 1) of \(sessionsBeforeLongBreak)"
                )
                .font(.caption)
                .foregroundStyle(.gray.opacity(0.6))
                .padding(.top, 4)
            }

            Spacer()

            HStack(spacing: 0) {
                controlCapsule(icon: "forward.end.fill", label: "Skip") {
                    pomodoroManager.skip()
                }
                controlCapsule(
                    icon: pomodoroManager.isRunning ? "pause.fill" : "play.fill",
                    label: pomodoroManager.isRunning ? "Pause" : "Resume"
                ) {
                    if pomodoroManager.isRunning {
                        pomodoroManager.pause()
                    } else {
                        pomodoroManager.resume()
                    }
                }
                controlCapsule(icon: "arrow.counterclockwise", label: "Reset") {
                    pomodoroManager.reset()
                }
            }

            Spacer()
        }
    }

    private var pomodoroProgress: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(phaseColor.opacity(0.15))
                    .frame(height: 5)

                RoundedRectangle(cornerRadius: 2.5)
                    .fill(phaseColor)
                    .frame(
                        width: max(0, min(pomodoroManager.progress, 1)) * geometry.size.width,
                        height: 5
                    )
            }
        }
        .frame(height: 10)
    }

    private func durationPill(icon: String, value: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text("\(value)m")
                .font(.caption2)
        }
        .foregroundStyle(.gray)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.white.opacity(0.06)))
    }

    private func controlCapsule(
        icon: String,
        label: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .padding(.horizontal, 15)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.8))
        .help(Text(label))
        .accessibilityLabel(Text(label))
    }

    private var phaseColor: Color {
        switch pomodoroManager.phase {
        case .focus: .orange
        case .shortBreak: .green
        case .longBreak: .blue
        }
    }
}
