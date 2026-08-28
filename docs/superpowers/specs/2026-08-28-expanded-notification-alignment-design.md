# Expanded Notification Alignment

## Problem

The expanded notification centers a wide layout container while its visible content remains leading-aligned. The dismiss button is positioned independently at the trailing edge, so short notifications look shifted and the lateral empty space is visibly asymmetric.

## Design

- Keep the notification panel and its automatic/manual sizing behavior unchanged.
- Center the complete visible notification group: avatar, text, and actions.
- Let the text/action column use its intrinsic width for short content, while retaining a maximum width for long messages.
- Keep the dismiss button as an independent trailing overlay.
- Give the content group and dismiss control equivalent effective edge clearance.
- Preserve the existing notification types, actions, animations, and compact closed-notch layout.

## Validation

- Build and install only with `./scripts/install-local.sh`.
- Inject a short call notification into the installed build.
- Capture the expanded notch and verify that the visible group no longer appears shifted and both lateral clearances are visually balanced.
- No new automated tests are required for this visual-only adjustment, per the project workflow.
