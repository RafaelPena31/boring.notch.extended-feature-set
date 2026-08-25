//
//  CalendarLiveActivity.swift
//  boringNotch
//
//  Right-side ring of the closed-notch calendar live activity: a countdown
//  ring around a calendar glyph. `progress` is 1 (full) → 0 (empty).
//

import AppKit
import Defaults
import SwiftUI

struct CalendarLiveActivityRing: View {
    let progress: Double
    var size: CGFloat
    var symbolName: String = "calendar"

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.25), lineWidth: 2)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
            Image(systemName: symbolName)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundStyle(.gray)
        }
        .frame(width: size, height: size)
    }
}

struct CalendarLiveActivityControl: View {
    @Environment(\.openURL) private var openURL
    @Default(.joinMeetingOnEventTap) private var joinMeetingOnEventTap

    let event: EventModel
    let progress: Double
    let size: CGFloat
    let countdownLabel: String

    private var meeting: MeetingLink? { event.meetingLink }

    var body: some View {
        Button(action: openPrimaryAction) {
            CalendarLiveActivityRing(
                progress: progress,
                size: size,
                symbolName: meeting?.symbolName ?? "calendar"
            )
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .help(helpText)
        .accessibilityLabel(accessibilityText)
        .contextMenu {
            if let meeting {
                Button(meeting.displayLabel, systemImage: meeting.symbolName) {
                    openURL(meeting.url)
                }
                Button("Copy Meeting Link", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(
                        meeting.url.absoluteString,
                        forType: .string
                    )
                }
                Divider()
            }
            if let calendarURL = event.calendarAppURL() {
                Button("Open in Calendar", systemImage: "calendar") {
                    openURL(calendarURL)
                }
            }
        }
    }

    private var helpText: String {
        guard let meeting else { return countdownLabel }
        return "\(meeting.displayLabel) · \(countdownLabel)"
    }

    private var accessibilityText: String {
        guard let meeting else { return countdownLabel }
        return "\(meeting.displayLabel). \(countdownLabel)"
    }

    private func openPrimaryAction() {
        if joinMeetingOnEventTap, let meeting {
            openURL(meeting.url)
        } else if let calendarURL = event.calendarAppURL() {
            openURL(calendarURL)
        }
    }
}
