# Stable Tab and Notch Transition Design

## Goal

Make navigation between notch modules visually stable. Tab icons must not move, Clipboard cards must not enter from an edge, and the only module-navigation animation must be the notch height change between Notification Center and regular tabs.

## Root causes

- `TabSelectionView` currently attaches the same `matchedGeometryEffect` identifier to every tab background, including hidden backgrounds. SwiftUI therefore has multiple simultaneous participants for one geometry identity, which can reposition the indicator and its layout unpredictably during selection changes.
- `ClipboardView` overrides the transaction for its entire subtree with `vm.animation`. When the view and its `LazyHStack` are inserted, that inherited animation also animates initial card layout, producing the broken bottom-to-top movement.
- The SwiftUI silhouette uses a smooth spring while the native panel uses an AppKit ease-in/ease-out timing function. The two representations of the same height transition can visibly drift.

## Chosen approach

Keep tab and module identity stable, remove inherited content animation, and synchronize the two existing height animations.

- Tab buttons retain fixed widths and positions. Only the selected tab owns the matched-geometry capsule; unselected tabs use no hidden matched-geometry participant.
- The module switch is explicitly non-animated. Home, Shelf, Clipboard, Pomodoro and Notification Center content changes immediately in place.
- `ClipboardView` no longer assigns `vm.animation` to its complete view tree. Its existing local hover, copy-feedback and clear-confirmation animations remain unchanged.
- The black SwiftUI silhouette and the existing `BoringNotchSkyLightWindow` use the same non-bouncy ease-in/ease-out duration for height changes.
- The same native panel continues to grow downward from its fixed top edge. No panel recreation, overlay window or content-driven height is introduced.

## Expected behavior

- Notification Center to Home animates only from 340 to 190 points; the tab icons remain stationary and Home content appears without sliding or fading.
- Home to Notification Center animates only from 190 to 340 points.
- Navigation between tabs that are already 190 points tall does not animate the silhouette because its size is unchanged.
- Opening Clipboard never animates its cards from below. Clipboard's interaction feedback still animates locally.
- Rapid tab changes finish at the latest selected tab and height.
- Reduce Motion makes the height change immediate while preserving all navigation behavior.

## Scope

The change is limited to tab selection identity, module-switch transactions, Clipboard's inherited transaction and synchronization of the existing height timing. It does not redesign module content, change notification data, alter notch dimensions or introduce new settings.

## Verification

No new automated tests are required, following the project's agreed workflow. Verification consists of:

1. Static inspection confirming one matched-geometry capsule participant and no animation on the module switch.
2. Building and installing exclusively through `./scripts/install-local.sh`.
3. Comparing the generated and installed executable hashes.
4. On the installed app, repeating Notification Center to Home, Home to Notification Center and Home to Clipboard.
5. Repeating the navigation rapidly and once with Reduce Motion enabled.
