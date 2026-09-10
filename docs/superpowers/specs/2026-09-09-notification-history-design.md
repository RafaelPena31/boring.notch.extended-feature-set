# Notification History — Grouped by App

**Status:** Approved for implementation planning on 2026-09-09, including the 200-item session limit.

## Scope

Add a manually opened notification history inside the existing notch. This is the first delivery in the agreed sequence: notification history, clipboard search and favorites, then favorite actions. The latter two features are separate follow-up designs, not part of this implementation.

## Presentation

- Add a Notifications entry to notch navigation and a discoverable menu command. Keep an entry available from the expanded live notification so a busy notification queue cannot block access to history.
- Use the selected option B: collapsible groups by application, ordered by their most recent notification. Within each group, show newest first. Open the most recent group initially; allow multiple groups to remain expanded while browsing.
- Identify sources using the existing source key (bundle identifier when known, normalized app name otherwise). Reuse source icons and their existing fallback, without claiming to fix missing iPhone icons.
- Show source, sender/title, relative time and the complete captured message. No additional ellipses or line limits. Long content scrolls; Read opens a full-text detail view inside the same notch, with Back navigation.
- Provide Recent and Saved for later filters, plus the app filter shown in the prototype. Saving means bookmarking for this session, not scheduling another notification.
- Keep per-item remove controls visible without hover. Provide Clear history and one-step Undo. Use English product labels, following the existing app.

## Notch Geometry and Interaction

- Reuse the existing panel, opening animation and black silhouette. Never create a detached card or second floating window.
- History uses the same 640 × 190-point open silhouette and the same native panel frame as every other tab. Switching to it changes only the tab content; controls remain compact and notification rows scroll inside the available area.
- Reserve the actual physical camera height and width before laying out controls or scrollable content. Preserve equal horizontal insets on the outer edges. Screens without a physical notch must remain usable.
- Use one vertical scrolling area. Scrolling must not trigger the notch-close gesture; Escape returns from detail to history, then closes the notch. Keep mouse and keyboard actions independent of the enclosing content click.
- Entering history is an explicit browsing action. New captures update its groups without replacing the list or resetting the current detail/scroll position. Leaving history returns to the ordinary live-notification presentation. Outside history, automatic-opening defaults, category/app rules and Focus behavior are unchanged.

## Capture and Lifetime

- Copy accepted notifications into a small in-memory history store before they can expire or be dropped from the short live queue. Reuse the current app/category visibility decisions and duplicate detection; do not capture previously hidden notifications or query old macOS Notification Center contents.
- History is independent of live presentation. Dismissing a transient banner, opening its app, answering it or its native expiration does not remove the history item.
- Match updates by notification token: update an existing record without inserting duplicates or moving its original received time. Late updates must not recreate a removed/cleared record or redisplay a dismissed banner.
- Keep at most 200 snapshots per session, evicting the oldest when full. Saved is a filter, not unlimited storage; saved items share this limit. Show the session-only retention and limit in the feature's help text.
- Closing the app or disabling notifications clears history, saved marks and undo data. Temporarily losing the helper connection does not require clearing text already captured, but must not leave executable stale actions. Hiding a source/category removes its retained records as well.
- No notification text, saved marks, reply drafts or history thumbnails are written to disk, logs, analytics or cloud services. Do not retain Accessibility objects or extend native banner lifetimes for history.

## Actions and Errors

- Clicking a notification's content or Open in app requests its source application. Reuse the live banner destination only if it is still available; otherwise use the existing local-app fallback. Do not invent deep links or claim every old notification can reopen its original conversation.
- Read, Save for later, Remove and Undo affect history only. They must not invoke the content-open action, dismiss another active notification, or delete anything from macOS Notification Center.
- History is a reading/bookmarking surface in this version: no reply composer, Answer/Decline buttons or saved native action handles. Live notification controls keep their existing capability checks.
- If the source cannot be opened, keep the item and display a concise inline error. An empty list explains whether no items have been captured or the selected filter has no matches.
- Undo restores only the last history removal/clear, merging with newer arrivals rather than replacing the current history. It must not restore entries from now-hidden sources or survive disabling the feature.

## Implementation Boundaries

- A value-only history item holds the source identity, captured text, original token/time, category and saved flag. It is not an active notification or a retained Accessibility action.
- A dedicated observable history store owns insertion/update, grouping, filters, capacity, removal and undo. `SystemNotificationManager` feeds it at the existing acceptance/update points while continuing to own the live queue, helper connection and transient actions.
- A history view owns group expansion, selected detail and inline feedback. Notch navigation and presentation own the manual-history mode, geometry and return behavior. Opening a historical source must report failure to history rather than only to the active live item.
- Update notification settings/help and `docs/notifications.md` to explain the session history. Do not add a persistence preference, scheduled reminders, notification search or unrelated refactoring in this delivery.

## Verification and Delivery

Use the existing build/install process, exclusively `./scripts/install-local.sh`. No TDD or new test infrastructure is required for this project.

Manually verify grouping, multiple open groups, full-text reading, filters, bookmarking, removal/undo with new arrivals, and source opening without triggering another control. Confirm that a dismissed notification remains readable, an expired call never has live call/reply actions, late updates cannot resurrect deleted items, and disabling/relaunching clears session data.

Check a physical-notch display and a notchless display, including scrolling below the camera, symmetric insets and restoration of the regular panel size. Recheck the existing media progress border and default-off automatic opening. Review the implementation before committing, then publish to the fork's `main` and verify that the installed binary matches the scripted build.
