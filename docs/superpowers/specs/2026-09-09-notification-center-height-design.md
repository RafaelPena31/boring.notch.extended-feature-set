# Notification Center Height Design

## Goal

Give Notification Center more vertical room without recreating the notch window or bringing back the history-only content transition. Home, Shelf, Clipboard and Pomodoro keep the existing 190-point open height. Notification Center uses a fixed 340-point open height.

## Chosen approach

Resize the existing `BoringNotchSkyLightWindow` while keeping its top edge fixed. The native panel is 360 points tall while Notification Center is active: 340 points for the black notch silhouette plus the existing 20-point shadow allowance. Returning to another tab restores the normal 210-point panel canvas.

The height is fixed rather than content-driven. This avoids geometry changes when groups expand, filters change or notification text varies. A permanently oversized transparent panel was rejected because its invisible area could intercept pointer interaction outside the visible notch.

## Behavior

- Selecting Notification Center expands the same panel from 190 to 340 points below the camera area.
- The window remains horizontally centered and its upper edge remains aligned with the top of the current display.
- Selecting any other tab shrinks the same panel back to 190 points.
- Only geometry animates. The selected module changes immediately, so History and Home do not slide, fade or enter from the top.
- The tab selection capsule keeps its existing locally scoped animation and respects Reduce Motion.
- History retains keyboard focus, Escape handling, hover protection and internal scrolling.

## Components and state flow

- `matters.swift` defines the 340-point Notification Center body height and the matching panel height including shadow space.
- `ContentView` derives history content height from the larger fixed body and updates the view model's active notch height when the selected tab changes.
- `BoringViewModel` exposes a small open-height setter so pointer containment uses the visible 340-point bounds while history is active and returns to the normal height afterward.
- `NotificationHistoryPanelHost` keeps its current keyboard-ownership role and adds top-anchored resizing of the same `NSPanel`; it never creates or replaces a window.

## Animation and interruption

Panel and silhouette resizing use one short, non-bouncy animation. A new tab selection supersedes the current target, so rapid switching finishes at the height of the latest selected tab. Reduce Motion makes the geometry change immediate.

## Failure handling

If the representable is temporarily detached from a window, it performs no resize and retries on `viewDidMoveToWindow`. Dismantling releases history keyboard ownership and restores the normal panel height. No notification data is changed by geometry failures.

## Verification

No new automated tests are required for this project change. Verification consists of:

1. Building and installing only with `./scripts/install-local.sh`.
2. Confirming Home and the other tabs remain at 190 points.
3. Confirming Notification Center reaches 340 points and scrolls internally.
4. Repeating History → Home and History → another tab to verify there is no content slide, close/reopen or panel replacement.
5. Checking the top edge on a physical-notch display and confirming pointer exit still closes normally.
6. Comparing hashes of the scripted product and `/Applications/boringNotch.app`.
