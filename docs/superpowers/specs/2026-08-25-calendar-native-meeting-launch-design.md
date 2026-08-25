# Calendar Native Meeting Launch Design

**Date:** 2026-08-25

**Status:** Approved

## Context

Calendar event rows currently render the meeting camera as a decorative image inside a button that covers the entire row. The camera therefore has no independent hit target. When the row opens an HTTPS Zoom or Teams meeting URL, macOS launches the browser and the meeting client may subsequently launch as a second step.

## Goals

- Make the camera a distinct join control in expanded calendar event rows.
- Keep the rest of the event row available for opening the event in Calendar.
- Open supported installed meeting clients directly, without also opening the browser.
- Fall back to the original HTTPS meeting URL when the native client is unavailable or the link cannot be converted safely.
- Reuse the same meeting-launch behavior from calendar Live Activity controls and context-menu join actions.

## Interaction Design

The event row will expose two sibling interactions instead of nesting the camera inside the row button:

- Clicking the event content opens the event in Calendar.
- Clicking the camera joins the meeting.

The camera will be a real SwiftUI `Button` with a compact macOS-sized hit area, hover feedback, a help label, and an accessibility label containing the meeting provider. Events without a supported meeting link keep the existing row behavior and do not show the join button.

The compact calendar Live Activity remains a meeting join control when it represents an event with a detected meeting link. Its action and the explicit Join item in context menus will use the same launcher as the event-row camera.

## Launch Architecture

A centralized meeting launcher will receive a detected `MeetingLink` and perform exactly one launch route.

For providers with a supported installed desktop client, it will convert the normalized HTTPS URL to that provider's native deep link:

- Zoom uses the locally registered `zoommtg` scheme for standard meeting URLs, preserving the meeting identifier and password when present.
- Microsoft Teams uses the `msteams` scheme while preserving the meeting path and query.
- Additional native providers are used only when both a reliable conversion and an installed handler can be verified.

Google Meet, Whereby, Jitsi, and other browser-oriented providers continue using HTTPS. Webex uses HTTPS until a reliable installed-client route is available.

Before opening a native deep link, the launcher verifies that macOS has an application registered for its scheme. If no handler exists, the link is unsupported for conversion, or the native launch reports failure, the launcher opens the original HTTPS URL in the default browser. The browser fallback is a separate branch and is never executed after a successful native launch.

## Failure Behavior

- A malformed meeting URL does nothing and leaves the calendar state unchanged.
- A missing native application opens the original meeting URL in the browser.
- A failed native open makes one browser fallback attempt.
- The launcher does not issue both native and browser opens speculatively.
- Opening the event in Calendar never attempts to join the meeting.

## Validation

Per project preference, validation is implementation-focused rather than TDD:

- Build the macOS application.
- Confirm the event row and camera are separately clickable.
- Confirm a standard Zoom link opens Zoom without opening the browser.
- Confirm a Microsoft Teams link opens Teams without opening the browser.
- Confirm a provider without an installed native client opens in the browser.
- Confirm the calendar Live Activity and join context-menu actions use the same behavior.
