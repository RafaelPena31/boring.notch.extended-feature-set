# Calendar Native Meeting Launch Implementation Plan

> **For agentic workers:** Execute this plan task-by-task in the current session. The user explicitly requested implementation-first validation without TDD for this project.

**Goal:** Give calendar meeting cameras an independent click target and open installed Zoom or Teams clients directly, with a browser fallback only when native launch is unavailable.

**Architecture:** Add a small AppKit-backed `MeetingLauncher` that converts normalized provider links into native deep links and performs one mutually exclusive launch path. Restructure expanded calendar rows into sibling buttons and route every meeting action, including the closed-notch Live Activity, through the launcher.

**Tech Stack:** Swift, SwiftUI, AppKit `NSWorkspace`, Defaults, Xcode, macOS 14+

---

### Task 1: Add the centralized native meeting launcher

**Files:**
- Create: `boringNotch/Providers/MeetingLauncher.swift`
- Modify: `boringNotch.xcodeproj/project.pbxproj`

- [ ] Add `MeetingLauncher.open(_:)`, which attempts one registered native URL and returns immediately after `NSWorkspace.open` succeeds; otherwise it opens the original HTTPS URL.
- [ ] Add a Zoom conversion for standard `/j/<meeting-number>` URLs. Build `zoommtg://<original-host>/join?action=join&confno=<meeting-number>` and preserve a non-empty `pwd` query item.
- [ ] Add a Teams conversion by replacing the normalized HTTPS scheme with `msteams` while retaining host, path, and query.
- [ ] Keep Google Meet, Webex, Whereby, and Jitsi browser-first until a reliable native conversion is known.
- [ ] Register the new Swift source in the Providers group and main app Sources phase.
- [ ] Commit the isolated launcher change with `feat: open meetings in native clients`.

The launch branch must remain mutually exclusive:

```swift
static func open(_ meeting: MeetingLink) {
    let workspace = NSWorkspace.shared
    if let nativeURL = nativeURL(for: meeting),
       workspace.urlForApplication(toOpen: nativeURL) != nil,
       workspace.open(nativeURL)
    {
        return
    }
    workspace.open(meeting.url)
}
```

### Task 2: Split expanded event-row interactions

**Files:**
- Modify: `boringNotch/components/Calendar/BoringCalendar.swift`
- Modify: `boringNotch/components/Settings/SettingsView.swift`
- Modify: `boringNotch/models/Constants.swift`

- [ ] Replace the single button around a calendar event row with sibling controls: the main row opens `event.calendarAppURL()`, while a trailing camera button calls `MeetingLauncher.open(meeting)`.
- [ ] Keep reminder rows and their completion control working without adding a meeting button.
- [ ] Give the camera button a 22-point content shape, plain style, provider-specific help text, accessibility label, and accent-color hover state.
- [ ] Route the context-menu Join action through `MeetingLauncher` and keep Copy Meeting Link and Open in Calendar unchanged.
- [ ] Remove the obsolete “Join meeting when selecting an event” toggle and its unused Defaults key because the row and camera now have unambiguous fixed actions.
- [ ] Commit the row interaction change with `fix: separate calendar join action`.

The meeting button will use this interaction contract:

```swift
Button {
    MeetingLauncher.open(meeting)
} label: {
    Image(systemName: meeting.symbolName)
        .frame(width: 22, height: 22)
        .contentShape(Rectangle())
}
.buttonStyle(.plain)
.help(meeting.displayLabel)
.accessibilityLabel(meeting.displayLabel)
```

### Task 3: Reuse the launcher in the calendar Live Activity

**Files:**
- Modify: `boringNotch/components/Live activities/CalendarLiveActivity.swift`

- [ ] Remove the obsolete event-tap preference from the compact control.
- [ ] When the compact control represents a meeting, call `MeetingLauncher.open(meeting)`; otherwise open the event in Calendar.
- [ ] Route the Live Activity context-menu Join action through the same launcher.
- [ ] Confirm help and accessibility text still describe the provider and countdown.
- [ ] Commit with `fix: reuse native calendar meeting launch`.

### Task 4: Build and validate the installed behavior

**Files:**
- Review: all files changed by Tasks 1-3

- [ ] Run `git diff --check` and verify no unrelated `.superpowers/` files are staged.
- [ ] Build the macOS target without code signing:

```bash
xcodebuild -quiet \
  -project boringNotch.xcodeproj \
  -scheme boringNotch \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/BoringNotchDerivedData-meeting-launch \
  CODE_SIGNING_ALLOWED=NO build
```

- [ ] Produce the existing arm64 ad-hoc Release build after the Debug build succeeds.
- [ ] Preserve the currently installed `/Applications/boringNotch.app` as a timestamped backup, install the Release app, and relaunch it.
- [ ] Verify that the camera and event body are independently clickable.
- [ ] Verify that Zoom opens without an additional browser window and that the event body opens Calendar.
- [ ] Verify that Teams uses its native client and a browser-only provider still opens the default browser.
- [ ] Verify the same launch behavior from the calendar Live Activity and context menu.

## Completion Criteria

- The camera is an independent accessible button.
- Clicking the event body never joins the meeting.
- Successful Zoom and Teams native launches do not also invoke the browser.
- Missing native handlers and unsupported providers use exactly one HTTPS fallback.
- Expanded calendar rows, context menus, and the closed-notch Live Activity share one launch implementation.
- Debug and Release builds succeed and the local installed build contains the fix.
