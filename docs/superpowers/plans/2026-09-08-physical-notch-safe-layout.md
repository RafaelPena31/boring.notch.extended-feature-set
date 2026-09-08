# Physical Notch Safe Layout Implementation Plan

> Execute this plan task-by-task in the current session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the physical MacBook notch centered inside an empty exclusion region while balancing compact activities across symmetric wings that grow horizontally.

**Architecture:** Add one reusable screen-aware horizontal layout in the existing sizing module, then route every compact top-row presentation through it on hardware-notch displays. Keep the current rendering path on displays without a physical notch and use a deterministic width-based planner for Pomodoro, Calendar, and Keep Awake indicators.

**Tech Stack:** Swift 6, SwiftUI, AppKit `NSScreen`, Defaults, the existing Boring Notch window and animation system.

---

### Task 1: Add Shared Physical-Notch Geometry and Container

**Files:**
- Modify: `boringNotch/sizing/matters.swift`
- Modify: `boringNotch/models/BoringViewModel.swift`

- [ ] **Step 1: Expose per-window hardware geometry from the view model**

Add computed properties that resolve only the view model's selected display:

```swift
@MainActor
extension BoringViewModel {
    var currentScreen: NSScreen? {
        guard let screenUUID else { return NSScreen.main }
        return NSScreen.screen(withUUID: screenUUID)
    }

    var hasPhysicalNotch: Bool {
        (currentScreen?.safeAreaInsets.top ?? 0) > 0
    }

    var physicalNotchExclusionWidth: CGFloat {
        hasPhysicalNotch ? closedNotchSize.width : 0
    }
}
```

Expected behavior: a missing UUID temporarily falls back to the main screen, while an unresolved explicit UUID returns no screen and therefore does not reserve an unverified cutout.

- [ ] **Step 2: Add deterministic width helpers**

Add a small value type to `matters.swift`:

```swift
struct NotchSafeLayoutMetrics {
    static func wingWidth(leading: CGFloat, trailing: CGFloat) -> CGFloat {
        max(0, max(leading, trailing))
    }

    static func contentWidth(
        exclusionWidth: CGFloat,
        leading: CGFloat,
        trailing: CGFloat,
        spacing: CGFloat
    ) -> CGFloat {
        (2 * wingWidth(leading: leading, trailing: trailing))
            + exclusionWidth
            + (2 * spacing)
    }

    static func silhouetteWidth(
        exclusionWidth: CGFloat,
        leading: CGFloat,
        trailing: CGFloat,
        spacing: CGFloat
    ) -> CGFloat {
        min(
            windowSize.width,
            contentWidth(
                exclusionWidth: exclusionWidth,
                leading: leading,
                trailing: trailing,
                spacing: spacing
            ) + (2 * cornerRadiusInsets.closed.bottom)
        )
    }
}
```

- [ ] **Step 3: Add the reusable safe horizontal container**

Add `NotchSafeHorizontalLayout` to `matters.swift`. It must frame both wings to the larger width only when `vm.hasPhysicalNotch` is true, reserve `vm.physicalNotchExclusionWidth` in the center, disable interaction and accessibility for that spacer, and otherwise render the supplied legacy layout unchanged.

The initializer accepts `leadingWidth`, `trailingWidth`, `spacing`, two view builders for the safe wings, and one view builder for the legacy non-notch presentation. This keeps current external-display layouts byte-for-byte equivalent at the call sites.

- [ ] **Step 4: Check the source diff**

Run:

```bash
git diff --check
git diff -- boringNotch/sizing/matters.swift boringNotch/models/BoringViewModel.swift
```

Expected: no whitespace errors; only screen geometry and the shared layout primitive are added.

---

### Task 2: Balance Media and Productivity Activities

**Files:**
- Modify: `boringNotch/ContentView.swift`

- [ ] **Step 1: Model the three compact accessory kinds**

Add a private `CompactActivityKind` with `pomodoro`, `calendar`, and `caffeine`, plus a `BalancedCompactActivities` result containing leading/trailing arrays and accumulated widths.

The active array is always created in this order:

```swift
private var activeCompactActivities: [CompactActivityKind] {
    var activities: [CompactActivityKind] = []
    if pomodoroActivityActive { activities.append(.pomodoro) }
    if calendarActivityActive { activities.append(.calendar) }
    if caffeineActivityActive { activities.append(.caffeine) }
    return activities
}
```

Use `pomodoroCompactWidth` for Pomodoro and `compactActivitySize` for Calendar and Keep Awake.

- [ ] **Step 2: Implement deterministic balancing**

Add a function that starts with optional leading and trailing anchor widths. For each active activity, add it to the currently narrower wing, choosing the leading wing on a tie. Include the existing 8-point spacing only when that wing already contains an anchor or activity.

Expected media distribution with all activities active: Pomodoro joins the leading artwork; Calendar and Keep Awake join the trailing visualizer. The two resulting wing frames have the same final width.

- [ ] **Step 3: Extract reusable compact subviews**

Extract the current album artwork and visualizer/animation into focused view-builder properties. Add one activity renderer that preserves the existing Pomodoro action, Calendar meeting action, Keep Awake help text, accessibility labels, sizes, and colors.

Leading accessories render in reverse assignment order so the stable media artwork remains closest to the physical notch. Trailing accessories render in assignment order so the visualizer remains closest to the physical notch.

- [ ] **Step 4: Route music through the safe layout on hardware displays**

Use `NotchSafeHorizontalLayout` with artwork and leading accessories in the leading wing and the visualizer plus trailing accessories in the trailing wing. Supply the untouched current `MusicLiveActivity` HStack as the legacy builder for non-notch displays.

- [ ] **Step 5: Route productivity-only activities through the safe layout**

On a hardware-notch display, balance only the distinct active activities and render each exactly once. Supply the untouched current `ProductivityLeadingIcon` plus trailing indicators as the legacy builder for non-notch displays.

- [ ] **Step 6: Match the black silhouette and lower chin width**

For hardware-notch media and productivity states, calculate `computedChinWidth` with `NotchSafeLayoutMetrics.silhouetteWidth`. Preserve every existing non-notch calculation and the fixed battery width.

- [ ] **Step 7: Inspect the activity diff**

Run:

```bash
git diff --check
git diff -- boringNotch/ContentView.swift
```

Expected: the active-state predicates and user actions are unchanged; only compact composition and width calculation differ.

---

### Task 3: Apply the Central Exclusion Rule to Remaining Surfaces

**Files:**
- Modify: `boringNotch/ContentView.swift`
- Modify: `boringNotch/components/Live activities/InlineHUD.swift`
- Modify: `boringNotch/components/Notch/NotificationLiveActivity.swift`
- Modify: `boringNotch/components/Notch/BoringHeader.swift`

- [ ] **Step 1: Make power status symmetric**

On hardware-notch displays, render the power-status label and battery view inside equal fixed wings around `vm.physicalNotchExclusionWidth`. Preserve the existing 640-point legacy battery presentation on external displays.

- [ ] **Step 2: Make the inline HUD use the physical exclusion width**

Route its existing 100-point left and right controls through `NotchSafeHorizontalLayout`. Preserve its current `closedNotchSize.width - 20` center spacer in the legacy builder.

- [ ] **Step 3: Generalize the notification compact layout**

Keep the current 205-point notification wings, but replace its local center-gap calculation with the shared safe container. On hardware-notch displays the gap must equal `vm.physicalNotchExclusionWidth`; on external displays it remains `closedNotchSize.width - cornerRadiusInsets.closed.top`.

Update `NotificationCompactLayout.silhouetteWidth` to accept the physical-notch flag and use `NotchSafeLayoutMetrics` only for hardware screens.

- [ ] **Step 4: Protect the idle face and open header**

On hardware-notch displays, give the idle-face placeholder and face feature equal wing frames around the full exclusion width. In `BoringHeader`, derive the central black spacer from `vm.physicalNotchExclusionWidth` and keep equal flexible header wings.

- [ ] **Step 5: Audit every closed top-row branch**

Run:

```bash
rg -n "closedNotchSize\.width|physicalNotchExclusionWidth|NotchSafeHorizontalLayout" \
  boringNotch/ContentView.swift \
  'boringNotch/components/Live activities/InlineHUD.swift' \
  boringNotch/components/Notch/NotificationLiveActivity.swift \
  boringNotch/components/Notch/BoringHeader.swift
```

Expected: every physical-notch top-row branch uses the shared exclusion width; legacy widths remain only inside non-notch builders or unrelated sizing.

---

### Task 4: Build, Install, and Verify

**Files:**
- Verify: `scripts/install-local.sh`
- Verify: `/Applications/boringNotch.app`

- [ ] **Step 1: Run static checks**

Run:

```bash
git diff --check
git status --short
```

Expected: only the planned Swift files and this documentation are tracked changes; `.superpowers/` remains untracked and is not added.

- [ ] **Step 2: Build and install through the sole supported process**

Run:

```bash
./scripts/install-local.sh
```

Expected: the script builds, signs, installs, verifies entitlements, and launches `/Applications/boringNotch.app` successfully.

- [ ] **Step 3: Confirm the installed binary is the new build**

Compare the installed executable timestamp and code signature with the script output. Confirm the running process path resolves inside `/Applications/boringNotch.app`.

- [ ] **Step 4: Perform physical-display smoke checks**

On the built-in display, verify music with Pomodoro, Calendar, and Keep Awake active together. Then verify notifications, battery, inline HUD, idle face, and the open header. No visual component or hit target may cross the physical camera housing.

- [ ] **Step 5: Perform display-switch smoke checks**

Move or switch the notch to an external display, confirm the legacy compact arrangement, then return it to the MacBook display without restarting.

- [ ] **Step 6: Commit and publish**

Run:

```bash
git add boringNotch/sizing/matters.swift \
  boringNotch/models/BoringViewModel.swift \
  boringNotch/ContentView.swift \
  'boringNotch/components/Live activities/InlineHUD.swift' \
  boringNotch/components/Notch/NotificationLiveActivity.swift \
  boringNotch/components/Notch/BoringHeader.swift
git commit -m "fix: keep compact activities outside physical notch"
git push origin main
```

Expected: the implementation commit reaches `origin/main`; `.superpowers/` is not included.
