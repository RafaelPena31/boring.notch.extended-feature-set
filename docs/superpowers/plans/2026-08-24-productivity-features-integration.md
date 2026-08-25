# Productivity Features Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Execute this plan task-by-task with explicit build checkpoints. Steps use checkbox (`- [ ]`) syntax for tracking. The user explicitly waived TDD and automated-test work for this project.

**Goal:** Integrate clipboard history, calendar Live Activity, Pomodoro, and Keep Awake into the current Boring Notch `main` code while excluding unrelated pull-request changes.

**Architecture:** Port feature-owned files from PRs #1449, #1382, #1347, and #1311, then adapt the shared tab, settings, coordinator, lifecycle, and closed-notch composition once per phase. Each feature keeps its own observable manager or store, and every phase ends with a macOS build before the next feature begins.

**Tech Stack:** Swift 5, SwiftUI, AppKit, Defaults, EventKit, UserNotifications, IOKit, Xcode 27 beta, macOS 14 deployment target.

---

## Source Map

| Feature | Source ref | Feature-owned files |
|---|---|---|
| Clipboard | `origin/pr/1449` | `boringNotch/components/Clipboard/**` |
| Calendar Live Activity | `origin/pr/1382` | `CalendarLiveActivity.swift`, `CalendarLiveActivityViewModel.swift` |
| Pomodoro | `origin/pr/1347` | `PomodoroView.swift`, `PomodoroManager.swift` |
| Keep Awake | `origin/pr/1311` | `CaffeineManager.swift` |

Shared files must be adapted against the current branch rather than replaced from a PR: `boringNotch.xcodeproj/project.pbxproj`, `boringNotch/BoringViewCoordinator.swift`, `boringNotch/ContentView.swift`, `boringNotch/Localizable.xcstrings`, `boringNotch/boringNotchApp.swift`, `boringNotch/components/Notch/BoringHeader.swift`, `boringNotch/components/Settings/SettingsView.swift`, `boringNotch/components/Tabs/TabSelectionView.swift`, `boringNotch/enums/generic.swift`, and `boringNotch/models/Constants.swift`.

### Task 1: Establish the build baseline

**Files:**
- Inspect: `boringNotch.xcodeproj/xcshareddata/xcschemes/boringNotch.xcscheme`
- Inspect: `boringNotch.xcodeproj/project.pbxproj`

- [ ] **Step 1: Confirm the branch and clean worktree**

```bash
git status --short --branch
```

Expected: branch `feat/productivity-features` with only this plan uncommitted.

- [ ] **Step 2: Build the unmodified application**

```bash
xcodebuild -quiet \
  -project boringNotch.xcodeproj \
  -scheme boringNotch \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/BoringNotchDerivedData-productivity-baseline \
  CODE_SIGNING_ALLOWED=NO build
```

Expected: exit code 0. If package resolution is blocked by sandboxed network access, rerun with the required environment permission without changing source files.

- [ ] **Step 3: Commit the implementation plan**

```bash
git add docs/superpowers/plans/2026-08-24-productivity-features-integration.md
git commit --no-gpg-sign -m "docs: plan productivity feature integration"
```

### Task 2: Integrate clipboard history

**Files:**
- Create: `boringNotch/components/Clipboard/Models/ClipboardItem.swift`
- Create: `boringNotch/components/Clipboard/Services/ClipboardActionService.swift`
- Create: `boringNotch/components/Clipboard/Services/ClipboardMonitor.swift`
- Create: `boringNotch/components/Clipboard/Services/ClipboardPersistenceService.swift`
- Create: `boringNotch/components/Clipboard/ViewModels/ClipboardStore.swift`
- Create: `boringNotch/components/Clipboard/Views/ClipboardView.swift`
- Modify: `boringNotch.xcodeproj/project.pbxproj`
- Modify: `boringNotch/BoringViewCoordinator.swift`
- Modify: `boringNotch/ContentView.swift`
- Modify: `boringNotch/boringNotchApp.swift`
- Modify: `boringNotch/components/Notch/BoringHeader.swift`
- Modify: `boringNotch/components/Settings/SettingsView.swift`
- Modify: `boringNotch/components/Tabs/TabSelectionView.swift`
- Modify: `boringNotch/enums/generic.swift`
- Modify: `boringNotch/models/BoringViewModel.swift`
- Modify: `boringNotch/models/Constants.swift`

- [ ] **Step 1: Port the six feature-owned Swift files from PR #1449**

Use the exact versions under `origin/pr/1449:boringNotch/components/Clipboard/`, excluding the PR's feature README. Preserve the model, monitor privacy markers, store deduplication, debounced persistence, blob garbage collection, and action service.

Verify the source set before editing:

```bash
git diff --name-only origin/main...origin/pr/1449 -- boringNotch/components/Clipboard
```

Expected: the six production Swift files plus `boringNotch/components/Clipboard/README.md`; do not add the README.

- [ ] **Step 2: Register clipboard files in the Xcode project**

Add one `PBXFileReference` and one `PBXBuildFile` for every new Swift file, place them in `Models`, `Services`, `ViewModels`, and `Views` groups beneath a `Clipboard` group, and add all six build files to the `boringNotch` Sources phase. Do not modify the XPC target.

Validate references:

```bash
rg -n 'Clipboard(Item|ActionService|Monitor|PersistenceService|Store|View)\.swift' boringNotch.xcodeproj/project.pbxproj
```

Expected: file reference, build-file reference, group entry, and Sources entry for each file.

- [ ] **Step 3: Wire clipboard settings and lifecycle**

Add Defaults keys matching PR #1449 for the master switch, item limit, per-kind capture, and concealed-content handling. Keep `clipboardHistoryEnabled` defaulted to `false`. Start or stop `ClipboardMonitor.shared` when the preference changes, load persisted history when enabled, and call `ClipboardStore.shared.flush()` from application termination.

- [ ] **Step 4: Add the clipboard tab**

Add `.clipboard` to `NotchViews`, make `TabSelectionView` derive its tabs from enabled features, and render `ClipboardView()` from `ContentView` when selected. If clipboard is disabled while selected, return the coordinator to `.home`.

- [ ] **Step 5: Add the clipboard Settings section**

Expose the master switch, history limit, type filters, concealed-item filter, and clear-history action. Keep destructive clear confirmation inside the Settings surface and preserve the PR's inline confirmation inside the notch view.

- [ ] **Step 6: Build and review clipboard integration**

```bash
xcodebuild -quiet -project boringNotch.xcodeproj -scheme boringNotch \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/BoringNotchDerivedData-productivity-clipboard \
  CODE_SIGNING_ALLOWED=NO build
git diff --check
git diff --stat
```

Expected: build exit code 0; no generated binaries, sandbox changes, or unrelated README changes.

- [ ] **Step 7: Commit clipboard history**

```bash
git add boringNotch.xcodeproj/project.pbxproj boringNotch
git commit --no-gpg-sign -m "feat: add private clipboard history"
```

### Task 3: Integrate calendar Live Activity

**Files:**
- Create: `boringNotch/components/Live activities/CalendarLiveActivity.swift`
- Create: `boringNotch/managers/CalendarLiveActivityViewModel.swift`
- Modify: `boringNotch.xcodeproj/project.pbxproj`
- Modify: `boringNotch/ContentView.swift`
- Modify: `boringNotch/components/Settings/SettingsView.swift`
- Modify: `boringNotch/managers/CalendarManager.swift`
- Modify: `boringNotch/models/Constants.swift`

- [ ] **Step 1: Port the calendar feature-owned files from PR #1382**

Import only the two Swift files. Exclude `.gitignore`, `boringNotch.dmg`, `build_dmg.sh`, and the PR's design document.

```bash
git diff --name-only origin/main...origin/pr/1382
```

Expected: confirm the excluded packaging artifacts are not added to the worktree.

- [ ] **Step 2: Adapt calendar data flow**

Expose the event updates needed by `CalendarLiveActivityViewModel` through the current `CalendarManager`. Preserve current EventKit permission handling. The derived view model must publish no activity when calendar access is unavailable or there is no future/current event.

- [ ] **Step 3: Compose the closed-notch activity**

Add `CalendarLiveActivity` to the existing closed-notch overlay hierarchy in `ContentView`. It must yield to active HUD and expanding presentations, avoid covering music content, and leave the closed notch unchanged when hidden.

- [ ] **Step 4: Add the calendar preference**

Add a boolean Defaults key defaulted to `false` and place its toggle in the existing Calendar settings area. Disable the toggle when calendar integration itself is disabled.

- [ ] **Step 5: Register, build, and review**

```bash
xcodebuild -quiet -project boringNotch.xcodeproj -scheme boringNotch \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/BoringNotchDerivedData-productivity-calendar \
  CODE_SIGNING_ALLOWED=NO build
git diff --check
git status --short
```

Expected: build exit code 0 and no DMG, build script, or extra `.gitignore` changes.

- [ ] **Step 6: Commit calendar Live Activity**

```bash
git add boringNotch.xcodeproj/project.pbxproj boringNotch
git commit --no-gpg-sign -m "feat: add calendar event live activity"
```

### Task 4: Integrate Pomodoro

**Files:**
- Create: `boringNotch/components/Pomodoro/PomodoroView.swift`
- Create: `boringNotch/managers/PomodoroManager.swift`
- Modify: `boringNotch.xcodeproj/project.pbxproj`
- Modify: `boringNotch/BoringViewCoordinator.swift`
- Modify: `boringNotch/ContentView.swift`
- Modify: `boringNotch/Localizable.xcstrings`
- Modify: `boringNotch/Shortcuts/ShortcutConstants.swift`
- Modify: `boringNotch/boringNotchApp.swift`
- Modify: `boringNotch/components/Settings/SettingsView.swift`
- Modify: `boringNotch/components/Tabs/TabSelectionView.swift`
- Modify: `boringNotch/enums/generic.swift`
- Modify: `boringNotch/models/Constants.swift`

- [ ] **Step 1: Port Pomodoro feature-owned files from PR #1347**

Import `PomodoroManager.swift` and `PomodoroView.swift`. Preserve the three-phase state machine, pause/resume/reset/skip controls, notification request, sound preference, and wall-clock reconciliation.

- [ ] **Step 2: Add Pomodoro defaults and application lifecycle**

Add duration, cycle-count, automatic-progression, sound, and notification Defaults keys using the PR values as initial defaults. Initialize the manager when the app launches and reconcile the timer after wake/activation without automatically starting a session.

- [ ] **Step 3: Add the Pomodoro tab without replacing clipboard**

Add `.pomodoro` to `NotchViews`, add its tab after Clipboard, and render `PomodoroView()` from `ContentView`. Preserve both feature-gated tabs and existing Home/Shelf selection behavior.

- [ ] **Step 4: Add compact closed-notch timer**

Compose the active countdown alongside the calendar activity. When both are eligible, Pomodoro has priority on the timer side and calendar uses the remaining safe region; neither may cover inline HUD or expanding presentations.

- [ ] **Step 5: Add Pomodoro Settings and localization**

Port only Pomodoro strings from the PR's string catalog and add the feature settings to the existing Settings navigation. Do not replace the current catalog wholesale.

- [ ] **Step 6: Build and review**

```bash
xcodebuild -quiet -project boringNotch.xcodeproj -scheme boringNotch \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/BoringNotchDerivedData-productivity-pomodoro \
  CODE_SIGNING_ALLOWED=NO build
git diff --check
git diff --stat
```

Expected: build exit code 0; Clipboard and Calendar integrations remain present.

- [ ] **Step 7: Commit Pomodoro**

```bash
git add boringNotch.xcodeproj/project.pbxproj boringNotch
git commit --no-gpg-sign -m "feat: add integrated pomodoro timer"
```

### Task 5: Integrate Keep Awake

**Files:**
- Create: `boringNotch/managers/CaffeineManager.swift`
- Modify: `boringNotch.xcodeproj/project.pbxproj`
- Modify: `boringNotch/ContentView.swift`
- Modify: `boringNotch/Localizable.xcstrings`
- Modify: `boringNotch/boringNotchApp.swift`
- Modify: `boringNotch/components/Notch/BoringHeader.swift`
- Modify: `boringNotch/components/Settings/SettingsView.swift`
- Modify: `boringNotch/models/Constants.swift`

- [ ] **Step 1: Port and harden `CaffeineManager` from PR #1311**

Preserve native `IOPMAssertionCreateWithName` and `IOPMAssertionRelease` usage. Ensure assertion creation failure leaves `isActive == false`, replacing any stale assertion releases the previous identifier, and `deinit` releases an active assertion.

- [ ] **Step 2: Add Keep Awake controls**

Add the active-state button to the expanded header without removing existing camera, Settings, battery, or feature-tab controls. Add Settings for assertion mode and optional duration only when supported by the manager.

- [ ] **Step 3: Wire termination cleanup**

Call `CaffeineManager.shared.deactivate()` from `applicationWillTerminate`. Keep Awake must remain inactive by default and must never restore an assertion merely because it was active before the previous launch.

- [ ] **Step 4: Build and review**

```bash
xcodebuild -quiet -project boringNotch.xcodeproj -scheme boringNotch \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/BoringNotchDerivedData-productivity-caffeine \
  CODE_SIGNING_ALLOWED=NO build
git diff --check
git diff --stat
```

Expected: build exit code 0 and no App Sandbox or entitlement changes.

- [ ] **Step 5: Commit Keep Awake**

```bash
git add boringNotch.xcodeproj/project.pbxproj boringNotch
git commit --no-gpg-sign -m "feat: add keep awake controls"
```

### Task 6: Final integration validation

**Files:**
- Review: all files changed since `origin/main`
- Update if necessary: `docs/superpowers/specs/2026-08-24-productivity-features-integration-design.md`

- [ ] **Step 1: Perform a clean final build**

```bash
xcodebuild -quiet -project boringNotch.xcodeproj -scheme boringNotch \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/BoringNotchDerivedData-productivity-final \
  clean build CODE_SIGNING_ALLOWED=NO
```

Expected: exit code 0.

- [ ] **Step 2: Inspect the complete diff**

```bash
git diff --check origin/main...HEAD
git diff --stat origin/main...HEAD
git status --short --branch
```

Expected: only the design, plan, four features, shared integration, localization, and Xcode project changes.

- [ ] **Step 3: Run manual smoke checks**

Launch the locally built app and verify:

1. Clipboard is off by default, starts after opt-in, captures allowed types, and clears stored history.
2. Calendar Live Activity stays hidden without a relevant event and appears for an eligible event when enabled.
3. Pomodoro starts, pauses, resumes, skips, resets, and remains correct across app inactivity.
4. Keep Awake activates, visibly reports its state, deactivates, and releases on application termination.
5. Home, Shelf, Calendar, media controls, Settings, and open/closed notch flows remain accessible.

- [ ] **Step 4: Review for prohibited artifacts**

```bash
git diff --name-only origin/main...HEAD | rg '(boringNotch\.dmg|build_dmg\.sh|\.entitlements$|README\.md$)' || true
```

Expected: no DMG, packaging script, entitlement, or unrelated README changes.

- [ ] **Step 5: Commit final integration polish only if needed**

```bash
git add boringNotch.xcodeproj/project.pbxproj boringNotch docs
git commit --no-gpg-sign -m "fix: polish productivity feature integration"
```

Skip this commit when the worktree is already clean.

