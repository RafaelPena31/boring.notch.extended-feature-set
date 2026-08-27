# Notifications From All Apps Design

## Goal

Mirror visible notification banners from every application by default instead of restricting capture to a fixed allowlist. Users can still silence individual sources after the app observes them.

## Source policy

Notification source filtering changes from an allowlist to an ignored-source list. An empty ignored list means every source is allowed. Category visibility, automatic notch opening, and Focus overrides remain unchanged and are evaluated after the source policy.

The existing `notificationAllowedApps` preference is retired. The new ignored list starts empty rather than converting old allowlist selections, so enabling this version immediately allows every application as requested.

## Observed applications

When a visible banner is captured, the app records only its source display name and bundle identifier. Notification titles, bodies, actions, and other content are never persisted.

Sources are deduplicated by bundle identifier. If a banner has no bundle identifier, a normalized display name is used as a fallback. Banners without either value remain allowed but cannot be configured individually.

The initially displayed source list contains the existing suggested applications. Newly observed applications are appended and persisted so they remain configurable after relaunch.

## Settings

The existing Apps section remains in the Notifications settings page. Its footer explains that every app is enabled by default and that turning off a source ignores future notifications from it.

Each source has a `Show notifications` toggle that defaults to on. Turning it off adds the source key to the ignored list; turning it back on removes the key. Suggested and observed sources share the same behavior and are displayed without duplicates.

The master `Show notifications inside the notch` toggle continues to control the entire feature.

## Runtime flow

1. The Accessibility watcher captures a visible Notification Center banner.
2. The notification manager records the source metadata when available.
3. The policy manager rejects the notification only if its source is ignored.
4. Existing category and Focus rules decide whether to show it and whether the notch opens automatically.
5. Allowed notifications use the existing queue, presentation, action, and expiry flow.

## Privacy and failure behavior

Only source identity metadata is stored. Notification content remains memory-only and is discarded after presentation.

Unknown sources fail open: if the app cannot determine a bundle identifier or name, the banner is still eligible for presentation. A malformed or missing source therefore does not recreate the current allowlist limitation.

## Validation

Validation remains implementation-focused without adding a test suite:

- Build and install exclusively with `./scripts/install-local.sh`.
- Confirm capture remains active after installation.
- Trigger a notification from an existing suggested app and from an app outside the current list; both must appear.
- Disable the newly observed app and confirm subsequent notifications from it are ignored.
- Re-enable it and confirm presentation resumes.
- Confirm category and Focus automatic-opening behavior remains unchanged.
