# Physical Notch Safe Layout Design

**Date:** 2026-09-04

**Status:** Approved

## Goal

Keep every visible control outside the physical MacBook notch while allowing the black notch silhouette to grow horizontally as more compact activities appear. Preserve the current virtual-notch layout on displays without a hardware notch.

## Root Cause

The app already detects a hardware notch through the selected `NSScreen` and calculates its width from `auxiliaryTopLeftArea`, `auxiliaryTopRightArea`, and `safeAreaInsets.top`.

The failure is in closed-notch composition. Music renders one leading item, a central black rectangle, and several trailing activities inside one centered `HStack`. Pomodoro, Calendar, and Keep Awake are appended only to the trailing side. As that side grows, SwiftUI centers the complete row, so the central rectangle moves away from the physical center and controls can render behind the camera housing.

The notification layout avoids this failure by giving its two wings equal widths. That local pattern will become a shared layout rule.

## Screen Geometry

The active `BoringViewModel` will expose geometry for its own `screenUUID`:

- whether that specific display has a physical notch;
- the width of the central hardware exclusion region;
- the maximum content width available to each side within the existing 640-point host window.

A display is considered to have a physical notch when its `safeAreaInsets.top` is greater than zero. The existing closed-notch width remains the fallback exclusion width when the auxiliary top areas are unavailable.

Geometry must be resolved from the view model's screen, not from `NSScreen.main`, so independent windows and automatic display switching receive the correct behavior.

## Shared Safe Layout

A reusable closed-notch container will render three horizontal regions:

1. A leading wing aligned toward the hardware.
2. A fixed central exclusion region aligned to the screen center.
3. A trailing wing aligned toward the hardware.

On a hardware-notch display, both wing frames use the width required by the larger wing. This keeps the exclusion region centered and makes the black silhouette expand equally to the left and right. The exclusion region contains only black or transparent layout space and never hosts a visual component or hit target.

On a display without a hardware notch, each existing compact presentation keeps its current arrangement and sizing.

## Balanced Activity Distribution

The media presentation keeps its two stable anchors:

- album artwork on the leading side;
- visualizer or idle animation on the trailing side.

The currently active Pomodoro, Calendar, and Keep Awake indicators are processed in that stable order. Each indicator is added to the wing with the smaller accumulated width. Equal widths choose the leading wing. The calculation includes the actual fixed width of each indicator and inter-item spacing.

The productivity-only presentation uses the same algorithm without media anchors. Each active indicator appears exactly once; the existing duplicated leading activity icon is removed on hardware-notch displays.

The distribution is deterministic, so an unchanged set of active activities does not move between sides during view updates.

## Affected Presentations

The central exclusion rule will be applied to:

- closed media Live Activity;
- closed productivity activities;
- power-status activity;
- inline system HUD;
- notification Live Activity;
- idle face presentation;
- the open-notch header at the physical-notch height.

Expanded content already starts below the hardware-height header and remains centered in the visible panel beneath the camera housing. It will not be split into wings.

## Width and Animation

The intrinsic width of the shared safe layout determines the closed black silhouette. It equals the central exclusion width plus two equal wings, spacing, and the existing outer corner insets. The lower chin uses the same calculated width when present.

The implementation keeps the existing open and close springs, hover behavior, and notch window position. Only the horizontal content calculation changes. The existing 640-point window is sufficient for the currently supported compact indicators, so no overflow menu or new maximum-width preference will be added.

## Display Changes and Fallbacks

When a window moves to another display or the preferred display changes, the existing screen-update flow recalculates the view model's closed size. The safe layout derives from the updated `screenUUID`, so it switches automatically between hardware-safe and existing virtual-notch behavior.

If the screen cannot be resolved temporarily, the app uses the existing non-hardware layout rather than reserving an unverified center region.

## Accessibility and Interaction

- Existing controls retain their labels, help text, actions, and hit targets.
- The central hardware exclusion region does not accept clicks.
- The visual order within each wing matches its accessibility traversal order.
- Existing Reduce Motion behavior and system appearance remain unchanged.

## Validation

Validation remains implementation-focused and does not introduce TDD or a new test target:

1. Build and install only through `./scripts/install-local.sh`.
2. On the built-in hardware-notch display, activate music, Pomodoro, Calendar Live Activity, and Keep Awake together and verify that all indicators remain visible outside the camera housing.
3. Verify notification, battery, inline HUD, idle face, and open-header presentations against the physical notch.
4. Move or switch the notch to an external non-notch display and confirm the existing compact layout is preserved.
5. Return to the built-in display and confirm geometry updates without restarting the app.
6. Confirm hover, open, close, clicks, media progress, and automatic notification expansion still behave normally.

Because screen capture cannot show the opaque hardware cutout, final physical alignment may be confirmed with a photo of the MacBook display.

## Out of Scope

- New user-facing layout settings.
- Overflow counters or hiding active indicators.
- Redesigning expanded content below the physical notch.
- Changing feature priority or notification policy.
- Increasing the existing host window beyond 640 points.
- Adding an automated test target or adopting TDD.
