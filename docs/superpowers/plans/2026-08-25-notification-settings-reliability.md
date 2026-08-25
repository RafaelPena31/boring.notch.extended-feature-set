# Notification Settings Reliability Implementation Plan

> **For agentic workers:** Execute the checked tasks in order. The user explicitly requested implementation-first validation without TDD for this project.

**Goal:** Make notification authorization, Focus authorization, Apple Intelligence reply settings, and media-progress discovery reliable in the local macOS build.

**Architecture:** Preserve notification capture in the existing XPC helper because TCC already attributes its Accessibility request to the containing app. Correct the missing privacy metadata, separate AI opt-in from runtime model availability, reorganize the existing Media form, and repair the installed build's stale TCC authorization after installation.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Intents, Foundation Models, XPC, macOS TCC, Xcode

---

### Task 1: Prevent the Focus authorization crash

**Files:**
- Modify: `boringNotch/Info.plist`

- [ ] Add `NSFocusStatusUsageDescription` with user-facing text explaining that Focus status selects which notification categories may open the notch automatically.
- [ ] Build the app and inspect the generated application Info.plist with `plutil`.
- [ ] Confirm the crash report's missing-key condition is no longer possible.

### Task 2: Make Apple Intelligence opt-in understandable and persistent

**Files:**
- Modify: `boringNotch/managers/SmartReplyManager.swift`
- Modify: `boringNotch/components/Settings/NotificationSettingsView.swift`

- [ ] Extend the availability presentation so unknown reasons explain Apple Intelligence enablement and matching supported Mac/Siri languages.
- [ ] Remove availability-based disabling from the opt-in toggle; retain the availability guard in `suggestReplies` so no model request runs while unavailable.
- [ ] Add a status row that distinguishes ready, waiting for setup, and unavailable states.
- [ ] Add a System Settings action for unavailable states and refresh the status when the app becomes active.
- [ ] Build and verify the unavailable path on the current Portuguese-Mac/English-Siri configuration.

### Task 3: Expose feature 4 in Media settings

**Files:**
- Modify: `boringNotch/components/Settings/SettingsView.swift`

- [ ] Move `showMediaProgressBar`, thickness, and color controls to a dedicated section near the top of the Media form.
- [ ] Name the section “Playback progress around the notch”.
- [ ] Add footer text stating that progress appears during playback while the notch is closed.
- [ ] Build and inspect the Media settings hierarchy.

### Task 4: Build, install, and repair Accessibility authorization

**Files:**
- No source changes.

- [ ] Produce an arm64 Release build with the project's existing ad-hoc local signing configuration.
- [ ] Verify the main app and embedded XPC helper signatures and bundle identifiers.
- [ ] Replace `/Applications/boringNotch.app` while keeping a recoverable backup.
- [ ] Run `tccutil reset Accessibility theboringteam.boringnotch` so the stale code requirement is removed without affecting other apps.
- [ ] Relaunch boringNotch, request Accessibility again, and confirm notification capture changes from “Not active” to “Active”.
- [ ] Trigger Focus authorization and confirm the app remains running.

