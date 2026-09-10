# Stable Tab and Notch Transition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or execute the plan inline task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep tab icons and module content stationary while animating only the notch height between Notification Center and regular tabs.

**Architecture:** Preserve the existing tab buttons, module switch and `BoringNotchSkyLightWindow`. Give the selection capsule one valid matched-geometry participant, suppress animation only for the transaction that replaces a module, and drive the SwiftUI silhouette plus AppKit panel with the same non-bouncy timing.

**Tech Stack:** Swift 6, SwiftUI, AppKit, QuartzCore, existing local install script.

---

## File map

- Modify `boringNotch/components/Tabs/TabSelectionView.swift`: keep tab button geometry stable and animate a single selection capsule.
- Modify `boringNotch/components/Clipboard/Views/ClipboardView.swift`: remove the inherited animation responsible for card entry movement.
- Modify `boringNotch/ContentView.swift`: suppress module replacement animation and use the shared height timing.
- Modify `boringNotch/components/NotificationHistory/NotificationHistoryPanelHost.swift`: use the same duration and ease curve for the native panel.
- Modify `boringNotch/sizing/matters.swift`: define the single height-animation duration.
- Modify this plan after verification to record the installed executable hash.

### Task 1: Stabilize the tab selector

**Files:**
- Modify: `boringNotch/components/Tabs/TabSelectionView.swift:38-66`

- [ ] **Step 1: Give the capsule one geometry identity**

Replace the selected/unselected background branches with a selected-only participant:

```swift
.background {
    if tab.view == coordinator.currentView {
        Capsule()
            .fill(Color(nsColor: .secondarySystemFill))
            .matchedGeometryEffect(id: "capsule", in: animation)
    }
}
```

Keep every `TabButton` height and horizontal padding unchanged. Retain the animation on `TabSelectionView` itself so only the local capsule and foreground color receive the selection transaction.

- [ ] **Step 2: Inspect the identity path**

Run:

```bash
rg -n "matchedGeometryEffect|hidden\(\)|currentView" boringNotch/components/Tabs/TabSelectionView.swift
git diff --check
```

Expected: exactly one `matchedGeometryEffect` call remains in the file, and no hidden capsule participates in the namespace.

### Task 2: Stop module content from inheriting navigation animation

**Files:**
- Modify: `boringNotch/components/Clipboard/Views/ClipboardView.swift:10-27`
- Modify: `boringNotch/ContentView.swift:718-763`

- [ ] **Step 1: Remove Clipboard's whole-tree transaction**

Delete this property, which is used only by the unwanted root transaction:

```swift
@EnvironmentObject var vm: BoringViewModel
```

Replace the complete body with:

```swift
var body: some View {
    panel
}
```

Do not change the existing animations bound to `confirmingClear`, `isHovering` or `justCopied`; those are local interaction feedback rather than navigation animation.

- [ ] **Step 2: Disable animation only while replacing the selected module**

Wrap the existing `switch coordinator.currentView` in a `Group` and override only the selection transaction:

```swift
Group {
    switch coordinator.currentView {
    case .home:
        NotchHomeView(albumArtNamespace: albumArtNamespace)
    case .shelf:
        ShelfView()
    case .clipboard:
        ClipboardView()
    case .pomodoro:
        PomodoroView()
    case .notificationHistory:
        NotificationHistoryView(maximumHeight: historyContentHeight)
    }
}
.transaction(value: coordinator.currentView) { transaction in
    transaction.animation = nil
    transaction.disablesAnimations = true
}
```

Keep the outer notch open/close transition unchanged. The transaction override belongs only on the normal module switch, not on the whole `ContentView`, so local hover and action feedback continue to work after navigation.

- [ ] **Step 3: Inspect animation scope**

Run:

```bash
rg -n "transaction|transition|animation" boringNotch/components/Clipboard/Views/ClipboardView.swift boringNotch/ContentView.swift | sed -n '1,220p'
git diff --check
```

Expected: Clipboard has no root `vm.animation` transaction; the module switch has one `currentView`-scoped transaction; existing local Clipboard feedback animations remain.

### Task 3: Synchronize SwiftUI and native height timing

**Files:**
- Modify: `boringNotch/sizing/matters.swift:15-22`
- Modify: `boringNotch/ContentView.swift:416-422`
- Modify: `boringNotch/components/NotificationHistory/NotificationHistoryPanelHost.swift:64-68`

- [ ] **Step 1: Define one duration**

Add beside the existing window and history sizing constants:

```swift
let notchResizeAnimationDuration: TimeInterval = 0.24
```

- [ ] **Step 2: Use matching non-bouncy geometry animations**

Change the scoped SwiftUI frame animation to:

```swift
.animation(
    reduceMotion ? nil : .easeInOut(duration: notchResizeAnimationDuration)
) { content in
    content.frame(height: openLayoutHeight, alignment: .top)
}
```

Use the same duration in the existing AppKit animation context:

```swift
context.duration = notchResizeAnimationDuration
context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
```

Keep top-edge anchoring, resize generations, interruption reconciliation and Reduce Motion behavior unchanged.

- [ ] **Step 3: Review the focused diff**

Run:

```bash
git diff --check
git diff -- boringNotch/sizing/matters.swift boringNotch/ContentView.swift boringNotch/components/NotificationHistory/NotificationHistoryPanelHost.swift boringNotch/components/Tabs/TabSelectionView.swift boringNotch/components/Clipboard/Views/ClipboardView.swift
```

Expected: navigation content has no movement or opacity transition; only the height frame and local tab selection indicator animate.

### Task 4: Build, install, review and publish

**Files:**
- Modify: `docs/superpowers/plans/2026-09-09-tab-transition-animation.md`

- [ ] **Step 1: Build and install through the canonical process**

Run from the repository root:

```bash
./scripts/install-local.sh
```

Expected: exit 0 and output ending with `Installed boringNotch ... with the configured development team.` Existing unrelated compiler warnings do not invalidate an exit-0 build.

- [ ] **Step 2: Verify product identity**

Run:

```bash
shasum -a 256 .build/local-install/Build/Products/Release/boringNotch.app/Contents/MacOS/boringNotch /Applications/boringNotch.app/Contents/MacOS/boringNotch
```

Expected: the two SHA-256 values are identical. Record the value in this plan.

- [ ] **Step 3: Verify the installed behavior**

On the installed app:

1. Repeat Notification Center to Home and confirm the icons do not move while the notch contracts smoothly.
2. Repeat Home to Notification Center and confirm the notch expands smoothly from the fixed top edge.
3. Open Clipboard and confirm its cards appear in place without moving from below.
4. Navigate among Home, Shelf, Clipboard and Pomodoro and confirm their 190-point silhouette does not animate.
5. Switch rapidly between Notification Center and regular tabs; the last selected tab must own the final height.
6. Enable Reduce Motion and confirm the height changes immediately.

- [ ] **Step 4: Request focused code review**

Ask the reviewer to inspect the working diff for matched-geometry uniqueness, stable tab widths, transaction scope, retained local Clipboard feedback, matching geometry timing, Reduce Motion and rapid-interruption handling. Resolve every critical or important finding.

- [ ] **Step 5: Commit and publish**

Stage only the implementation files and this plan; leave `.superpowers/` untracked:

```bash
git add boringNotch/components/Tabs/TabSelectionView.swift \
  boringNotch/components/Clipboard/Views/ClipboardView.swift \
  boringNotch/ContentView.swift \
  boringNotch/components/NotificationHistory/NotificationHistoryPanelHost.swift \
  boringNotch/sizing/matters.swift \
  docs/superpowers/plans/2026-09-09-tab-transition-animation.md
git diff --cached --check
git commit -m "fix: stabilize notch tab transitions"
git push origin main
git rev-list --left-right --count HEAD...origin/main
git status --short
```

Expected: divergence is `0 0`; only `.superpowers/` remains untracked.
