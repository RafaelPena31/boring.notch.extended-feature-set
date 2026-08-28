# Expanded Notification Alignment

## Problem

The expanded notification centers its content group while positioning the dismiss button independently at the trailing edge. These two independent anchors cannot guarantee equal outer clearances, so the avatar remains farther from the left edge than the dismiss button is from the right edge.

## Design

- Keep the notification panel and its automatic/manual sizing behavior unchanged.
- Anchor the avatar/content group to the leading edge of the available notification area.
- Keep the dismiss button anchored to the trailing edge.
- Use the same effective horizontal inset on both anchors: the avatar's leading edge and the dismiss button's trailing edge must be equidistant from the panel edges.
- Let the text/action column use the remaining width and preserve wrapping for long messages.
- Keep the dismiss button independent from the content width so short and long notifications use the same edge geometry.
- Preserve the existing notification types, actions, animations, and compact closed-notch layout.

## Validation

- Build and install only with `./scripts/install-local.sh`.
- Inject a short call notification into the installed build.
- Capture short and long expanded notifications and verify that the measured left clearance before the avatar equals the measured right clearance after the dismiss button.
- No new automated tests are required for this visual-only adjustment, per the project workflow.
