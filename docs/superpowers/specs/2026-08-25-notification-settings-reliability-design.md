# Notification Settings Reliability Design

## Context

The locally installed ad-hoc build exposes four usability failures: Accessibility appears enabled while notification capture remains inactive, requesting Focus status crashes, Apple Intelligence reply suggestions cannot be enabled, and the media progress feature is difficult to find.

## Decisions

### Notification capture authorization

Keep Accessibility work in `BoringNotchXPCHelper`. macOS correctly attributes the helper request to the containing `theboringteam.boringnotch` app, so moving the watcher would add risk without solving the observed failure.

The installed build is ad-hoc signed and the Mac has no Apple code-signing identity. Each rebuilt binary therefore has a different code requirement. The current TCC record belongs to an older build even though System Settings still renders its switch as enabled. Installation must reset only the boringNotch Accessibility record, relaunch the current build, and request authorization again.

### Focus status

Add `NSFocusStatusUsageDescription` to the app Info.plist. Continue using `INFocusStatusCenter` for authorization and status monitoring. The request button remains visible only until authorization reaches a terminal state.

### Apple Intelligence reply suggestions

The preference is an opt-in, not an availability indicator. Let users save the opt-in even while the on-device model is unavailable. Show a separate availability status and recovery guidance; suggestions continue to be generated only when `SystemLanguageModel.default.availability` is `.available`.

For unknown unavailability reasons, explain the conditions observed on this Mac: Apple Intelligence must be enabled and the Mac and Siri must use the same supported language. Provide a direct route to System Settings and refresh the displayed status when the app becomes active.

### Media progress discovery

Move the existing progress toggle and customization controls into their own section at the top of Media settings. Name the section “Playback progress around the notch” and explain that it is visible while media is playing and the notch is closed. The rendering behavior and defaults remain unchanged.

## Validation

Per project preference, validation is implementation-focused rather than TDD:

- Build the Release target for Apple silicon.
- Inspect the built Info.plist for the Focus usage description.
- Install the build, reset only the app Accessibility TCC entry, and relaunch.
- Verify Focus authorization no longer crashes.
- Verify Apple Intelligence opt-in remains selectable while unavailable and displays recovery guidance.
- Verify the Media page exposes the playback progress section without scrolling through unrelated controls.

