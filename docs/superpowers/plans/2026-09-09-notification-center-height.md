# Taller Notification Center Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand Notification Center to a fixed 340-point notch height while every other tab remains at 190 points, without recreating the panel or animating the module content.

**Architecture:** Keep the existing `BoringNotchSkyLightWindow` instance and resize its frame from the top edge. `ContentView` owns the selected-tab height, `BoringViewModel` mirrors that height for pointer containment, and `NotificationHistoryPanelHost` coordinates AppKit frame geometry plus existing keyboard ownership.

**Tech Stack:** Swift 6, SwiftUI, AppKit `NSPanel`, Defaults, existing local install script.

---

## File map

- Modify `boringNotch/sizing/matters.swift`: fixed Notification Center silhouette and panel-height constants.
- Modify `boringNotch/models/BoringViewModel.swift`: open-state height update used by rendering and pointer containment.
- Modify `boringNotch/components/NotificationHistory/NotificationHistoryPanelHost.swift`: resize the same panel with a top-fixed frame and keep keyboard ownership.
- Modify `boringNotch/ContentView.swift`: select the history height, scope geometry animation, and allocate the larger history viewport.
- Modify `boringNotch/boringNotchApp.swift`: preserve the open pointer-containment size when moving between displays.
- Modify `docs/superpowers/plans/2026-09-09-notification-center-height.md`: record completed verification evidence.

### Task 1: Define fixed geometry and view-model state

**Files:**
- Modify: `boringNotch/sizing/matters.swift:15-18`
- Modify: `boringNotch/models/BoringViewModel.swift:213-228`

- [x] **Step 1: Add the fixed Notification Center dimensions**

Add these constants after `windowSize`:

```swift
let notificationHistoryNotchHeight: CGFloat = 340
let notificationHistoryWindowHeight: CGFloat = notificationHistoryNotchHeight + shadowPadding
```

Keep `openNotchSize.height == 190` and `windowSize.height == 210` unchanged for every other tab.

- [x] **Step 2: Restore a narrow open-height API**

Add this method between `open()` and `close()`:

```swift
func setOpenContentHeight(_ height: CGFloat) {
    guard notchState == .open else { return }
    notchSize = CGSize(width: openNotchSize.width, height: height)
}
```

This state must describe the visible black silhouette so `isMouseHovering()` includes the complete 340-point history area.

- [x] **Step 3: Check the focused diff**

Run:

```bash
git diff --check
git diff -- boringNotch/sizing/matters.swift boringNotch/models/BoringViewModel.swift
```

Expected: no whitespace errors; only the two constants and one guarded setter are present.

### Task 2: Resize the same panel and expand only history

**Files:**
- Modify: `boringNotch/components/NotificationHistory/NotificationHistoryPanelHost.swift:4-48`
- Modify: `boringNotch/ContentView.swift:15-200`
- Modify: `boringNotch/ContentView.swift:385-565`

- [x] **Step 1: Pass the geometry target and Reduce Motion preference to the AppKit host**

Give `NotificationHistoryPanelHost` these inputs:

```swift
let isActive: Bool
let reduceMotion: Bool
```

Its `HostView` stores the same two values and a weak reference to the current `BoringNotchSkyLightWindow`:

```swift
var isActive = false
var reduceMotion = false
private weak var panel: BoringNotchSkyLightWindow?
```

The normal target is always the existing `windowSize.height` constant. Do not capture an in-flight frame height; that could make a rapid History → Home → History sequence restore to an intermediate size.

- [x] **Step 2: Add top-anchored resizing without creating a window**

In `apply()`, keep the current panel reference, resize to `notificationHistoryWindowHeight` when history is active or `windowSize.height` otherwise, and mirror `isActive` to `wantsKeyForHistory`. When the representable moves to another panel or is dismantled, restore the old panel to `windowSize.height`, release keyboard ownership and clear the reference.

Use one helper for both directions:

```swift
private func resize(_ panel: NSWindow, height: CGFloat, animated: Bool) {
    var target = panel.frame
    guard abs(target.height - height) > 0.5 else { return }
    target.origin.y = target.maxY - height
    target.size.height = height

    guard animated else {
        panel.setFrame(target, display: true)
        return
    }

    NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.24
        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        panel.animator().setFrame(target, display: true)
    }
}
```

Import `QuartzCore` for `CAMediaTimingFunction`. `viewDidMoveToWindow`, `updateNSView` and `dismantleNSView` must continue to reuse the representable's existing panel; none may instantiate an `NSWindow`.

The implementation also assigns a generation to each resize request. Completion handlers from superseded animations are ignored, while the current request reconciles its final height. This prevents a stale animation from interrupting rapid tab changes or a Reduce Motion update.

- [x] **Step 3: Derive the taller history viewport in `ContentView`**

Add:

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
```

Use the fixed height for history only:

```swift
private var historyContentHeight: CGFloat {
    max(0, notificationHistoryNotchHeight - historyHeaderHeight - 8 - openSecondaryPadding)
}

private var openLayoutHeight: CGFloat? {
    guard vm.notchState == .open else { return nil }
    if historyActive { return notificationHistoryNotchHeight }
    return usesCompactPlayer || usesAutomaticNotificationPanel
        ? nil
        : vm.notchSize.height
}
```

- [x] **Step 4: Keep content replacement outside the height animation**

Update the existing `historyActive` observer:

```swift
.onChange(of: historyActive) { _, active in
    hoverTask?.cancel()
    vm.setOpenContentHeight(active ? notificationHistoryNotchHeight : openNotchSize.height)
    if active {
        gestureProgress = .zero
        clearAutomaticNotificationRestoration()
        notificationManager.resumeExpiry(after: 3)
    }
}
```

Scope the 0.24-second animation to the `mainLayout` frame modifier rather than wrapping `coordinator.currentView` or the module switch in a transaction. With Reduce Motion, use no geometry animation. Keep the tab selector implementation from commit `a4afec66` unchanged.

```swift
mainLayout
    .animation(reduceMotion ? nil : .smooth(duration: 0.24)) { content in
        content.frame(height: openLayoutHeight, alignment: .top)
    }
```

- [x] **Step 5: Allocate the matching root and native panel height**

Change the root maximum height and host call to:

```swift
.frame(
    maxWidth: windowSize.width,
    maxHeight: historyActive ? notificationHistoryWindowHeight : windowSize.height,
    alignment: .top
)
.background {
    NotificationHistoryPanelHost(
        isActive: historyActive,
        reduceMotion: reduceMotion
    )
    .frame(width: 0, height: 0)
}
```

Expected: the native window grows down from an unchanged `frame.maxY`; no second panel, overlay window or dynamic content measurement is introduced.

- [x] **Step 6: Review the geometry paths**

Run:

```bash
git diff --check
rg -n "notificationHistory(Notch|Window)Height|setOpenContentHeight|NotificationHistoryPanelHost" boringNotch
git diff -- boringNotch/ContentView.swift boringNotch/components/NotificationHistory/NotificationHistoryPanelHost.swift
```

Expected: one fixed 340-point history target; the regular 190/210 sizes remain intact; tab navigation still assigns `currentView` without a global `withAnimation`.

### Task 3: Build, install, inspect and publish

**Files:**
- Modify: `docs/superpowers/plans/2026-09-09-notification-center-height.md`

- [x] **Step 1: Build and install through the only approved process**

Run from the repository root:

```bash
./scripts/install-local.sh
```

Expected: exit 0; app/helper signature checks pass; output ends with `Installed boringNotch ... with the configured development team.` Existing unrelated compiler warnings do not invalidate an exit-0 build.

- [ ] **Step 2: Verify native behavior without adding a test target**

Using the installed app, verify:

1. Home, Shelf, Clipboard and Pomodoro retain the 190-point silhouette.
2. Notification Center reaches 340 points while its list scrolls internally.
3. The upper window edge remains fixed on the physical-notch display.
4. History → Home and History → another tab shrink the panel without sliding/fading the replacement module or recreating the window.
5. Repeated quick tab changes end at the latest tab's correct height.
6. Pointer exit, Escape and the close button continue to dismiss normally.

- [x] **Step 3: Request focused review**

Ask the reviewer to inspect the working diff for top-edge preservation, key-window release, Reduce Motion behavior, pointer containment, rapid selection, display movement, and accidental reintroduction of a global content animation. Resolve every critical or important finding before committing.

- [x] **Step 4: Confirm product/install identity**

Run:

```bash
shasum -a 256 .build/local-install/Build/Products/Release/boringNotch.app/Contents/MacOS/boringNotch /Applications/boringNotch.app/Contents/MacOS/boringNotch
```

Expected: both SHA-256 values are identical. Record the hash and any physical-pointer limitation in this plan.

- [x] **Step 5: Commit implementation and publish `main`**

Stage only the implementation files and this plan; leave `.superpowers/` untracked:

```bash
git add boringNotch/sizing/matters.swift \
  boringNotch/models/BoringViewModel.swift \
  boringNotch/components/NotificationHistory/NotificationHistoryPanelHost.swift \
  boringNotch/ContentView.swift \
  docs/superpowers/plans/2026-09-09-notification-center-height.md
git diff --cached --check
git commit -m "feat: expand notification center vertically"
git push origin main
git rev-list --left-right --count HEAD...origin/main
git status --short
```

Expected: divergence is `0 0`; only `.superpowers/` remains untracked.

## Execution notes

- Implementation commit: `2581c6a7` (`feat: expand notification center vertically`).
- Canonical `./scripts/install-local.sh` build and installation completed with exit 0 for that commit.
- Built and installed executable SHA-256: `6dcddd999196b0856c3303b23be1002383418cb02c91fac151470cfcd634e4d7`.
- Focused static review found no remaining critical or important issues after fixing animation-generation and display-change races.
- Physical-notch pointer and motion checks remain intentionally unchecked above because they require direct observation on the Mac display.
