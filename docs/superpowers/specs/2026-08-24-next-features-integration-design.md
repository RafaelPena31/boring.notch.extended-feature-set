# Next Features Integration Design

**Date:** 2026-08-24

**Status:** Approved

## Goal

Integrate four selected pull-request features into the current Boring Notch branch without importing the unrelated refactors carried by those branches:

- Join calendar meetings from the notch, sourced from PR #1423.
- Optional media progress around the closed notch, sourced from PR #1350.
- Image conversion from the Shelf, sourced from PR #1303.
- The complete notification Live Activity scope, sourced from PR #1447, including notification capture, OTP handling, stacking, replies, contact avatars, Apple Intelligence suggestions, compact media mode, and audio-output switching.

The work will selectively port feature-owned code and adapt it to the current app architecture. The current notch window, opening animation, tabs, media player, calendar, Shelf, Pomodoro, Clipboard, and Keep Awake implementations remain the foundation.

## Product Principles

- The notch is the only presentation surface. Notifications must not create a floating card, detached lane, or separate panel outside the notch.
- Automatic expansion reuses the app's existing native notch-opening behavior. Only the content inside the notch is temporarily reorganized.
- The user's current notch content and selected tab are preserved while transient content is presented and restored afterward.
- Attention-grabbing behavior is opt-in and configurable by notification category.
- macOS Focus settings are respected through public APIs and Focus Filters.
- Notification contents, reply drafts, and generated suggestions are not persisted to disk.
- Existing behavior remains the default when a new feature is disabled.
- No TDD workflow or new automated test target will be introduced. Validation focuses on builds, targeted manual checks, and diff review.

## Integration Strategy

The selected PR branches have diverged substantially from the current branch. They must not be cherry-picked wholesale. Relevant models, services, and views will be ported in this order:

1. Shelf image conversion.
2. Calendar meeting-link detection and joining.
3. Media progress around the notch.
4. Notification XPC and Accessibility infrastructure.
5. Notification classification, OTP, queue, avatars, and replies.
6. Optional Apple Intelligence suggestions.
7. Compact player and audio-output switching.
8. Final transient-activity resolution and visual polish.

Shared files such as `ContentView.swift`, `BoringViewCoordinator.swift`, `SettingsView.swift`, `Constants.swift`, the app lifecycle, XPC protocols, entitlements, and the Xcode project will be edited against the current branch rather than copied from any PR.

## Shared Notch Presentation Architecture

### Single presentation surface

`ContentView` continues to render the existing notch window. A new transient-presentation coordinator will describe temporary content without creating another window:

- `idle`: normal music, calendar, Pomodoro, Caffeine, Clipboard, or Shelf behavior.
- `compact`: a short informational presentation inside the closed notch.
- `expanded`: temporary notification content inside the normally opened notch.

The coordinator records a restoration snapshot before an automatic presentation:

- whether the notch was open or closed;
- the selected tab or active home content;
- the content that was primary in the closed notch;
- whether the opening was automatic or initiated by the user.

When the presentation expires or is resolved, the snapshot is restored. If the notch was opened automatically, the existing closing animation runs. If it was already open, it stays open. If the user deliberately navigates to another tab while transient content is visible, that action dismisses the transient presentation and the user's new destination wins.

### Activity precedence

The resolver prevents overlapping notch content:

1. An active system HUD keeps its existing precedence and is never covered by an informational notification.
2. A call can preempt another transient notification.
3. OTP, permission, and decision requests can temporarily replace compact music/calendar content when their auto-open policy permits it.
4. Messages, mail, and other informational notifications use the compact closed-notch state unless explicitly configured to auto-open.
5. Media progress is hidden whenever the notch is open or transient content is active.
6. Pomodoro, calendar, music, Caffeine, and the selected tab remain in memory and return after the transient item finishes.

Only one notification is primary. Additional items enter a bounded in-memory queue and appear as a compact stack when the notch is opened. Duplicate updates from the same app and notification are coalesced instead of producing repeated animations.

## Join Calendar Meetings

### User experience

Eligible calendar events show a join action in both the expanded calendar event row and the existing calendar Live Activity. Clicking the primary join control opens the detected meeting URL. The context menu retains an explicit action to open the event in Calendar.

The feature is enabled by default because it adds an action to already visible calendar content and does not request new permissions beyond existing calendar access.

### Link detection

A local `MeetingLinkDetector` scans event fields in this order:

1. Structured event URL.
2. Location.
3. Notes.

It recognizes Google Meet, Zoom, Microsoft Teams, Webex, Whereby, and Jitsi links. Candidates are normalized and validated before use. Unsupported schemes, malformed URLs, tracking-only links, and unrelated web URLs are ignored.

The detected link is represented by a small model containing the normalized URL, provider, display label, and SF Symbol or local icon identifier. No network request is required to classify a meeting link.

### Failure behavior

- Events without a supported link retain their current interaction.
- Failure to open a URL does not alter the selected event or calendar state.
- Calendar permission loss removes both event data and join actions through the existing calendar fallback.

## Media Progress Around the Notch

### User experience

An opt-in progress stroke follows the closed-notch contour while media is playing. It provides glanceable playback position without changing the current player layout.

Settings expose:

- enabled or disabled;
- color source: album-art color, white, or system accent;
- thickness from 1 to 5 points.

### Rendering rules

The progress indicator is visible only when all conditions are true:

- the notch is closed;
- media is the primary closed-notch activity;
- valid duration and playback position are available;
- no system HUD or transient notification is visible.

The indicator disappears during opening and does not render behind expanded content. Playback position uses the existing estimated-position logic from `MusicManager` so the stroke advances smoothly without increasing MediaRemote polling.

Invalid, live, unknown-duration, or zero-duration streams omit progress. A missing album-art color falls back to the system accent color.

## Shelf Image Conversion

### User experience

Image files in the Shelf gain a contextual submenu:

`Image Actions` → `Convert Image` → `PNG`, `JPEG`, `HEIC`, or `WebP`

The current source format is omitted. Conversion creates a new Shelf item and retains the original. There is no confirmation sheet for a routine conversion; success is shown inline and failures use a concise non-modal error state.

### Conversion behavior

`ImageProcessingService` will use ImageIO and `UTType` to decode and encode only formats supported by the running macOS version. The first release does not expose resizing, batch conversion, metadata controls, or quality controls.

The output keeps the source base name and uses the target extension. Existing files are never overwritten; collisions receive a numeric suffix such as `photo 2.png`. Output is created through the Shelf's temporary-file storage so bookmark and lifecycle behavior remain consistent with other generated Shelf assets.

If an encoder such as WebP is unavailable on the running system, that option is disabled or omitted rather than failing after selection.

### Failure behavior

- Unsupported or corrupt images keep their original Shelf item unchanged.
- Partial output is removed after an encoding or write failure.
- Security-scoped access is held only while reading the source.

## Notification Live Activity

### Explicit enablement

Notification integration is disabled by default. Enabling it launches a dedicated setup flow that:

1. Explains that Boring Notch reads visible notification UI through Accessibility.
2. Requests Accessibility authorization only after the user confirms.
3. Offers Contacts access separately for contact photos.
4. Offers Apple Intelligence suggestions separately, disabled by default.
5. Lets the user choose the source-app allowlist and automatic-opening defaults.

Initial suggested apps are Messages, WhatsApp, Telegram, Discord, Mail, Outlook, FaceTime, and Claude. The allowlist remains editable in Settings.

Disabling notification integration stops observation, clears the in-memory queue, restores any held system banner, and removes transient notification content from the notch.

### Capture and transport

The existing XPC helper is extended with the notification-watching pieces from PR #1447. Accessibility observation captures visible notification banners and their actionable controls without reading private Notification Center databases.

The XPC payload contains only transient presentation data:

- stable runtime identifier;
- source app name and bundle identifier;
- title, subtitle, and body;
- timestamp and detected actions;
- optional avatar image data;
- whether the original banner is currently being held for interaction.

The main app owns classification, queueing, policy evaluation, and SwiftUI state. XPC interruption triggers bounded reconnection. Any system banner hidden or repositioned for interaction must be restored when the item expires, the feature is disabled, the helper disconnects, or the app terminates.

### Notification categories

Classification uses deterministic detectors before any optional intelligent model:

1. `otp`: one-time passwords and security codes.
2. `call`: incoming audio or video calls.
3. `permission`: permission or authorization requests.
4. `decision`: review, approval, confirmation, or manual-decision requests.
5. `message`: chat and direct-message content.
6. `mail`: email notifications.
7. `other`: informational fallback.

OTP detection has priority over the source app's default category. App identifiers and available actions help distinguish calls, messages, and mail. Unknown content always falls back to `other`; it must never be promoted to a more interruptive category solely because classification is uncertain.

### Per-category presentation settings

Each category has two independent settings:

- `Show in notch`: whether eligible notifications in that category are presented at all.
- `Automatic opening`: `Never`, `Only outside Focus`, or `Always`.

Recommended onboarding defaults are conservative:

| Category | Show | Automatic opening |
| --- | --- | --- |
| OTP/security code | On | Only outside Focus |
| Calls | On | Always |
| Permissions | On | Only outside Focus |
| Decisions/reviews | On | Only outside Focus |
| Messages | On | Never |
| Mail | On | Never |
| Other | On | Never |

`Never` still permits the compact notification inside the closed notch; it only prevents automatic expansion. Clicking the compact presentation opens the existing notch with its native animation. Turning `Show in notch` off suppresses the category entirely.

### macOS Focus integration

Focus integration uses public platform APIs only:

- `INFocusStatusCenter` reports whether notifications are currently silenced after the user grants Focus-status access.
- A `SetFocusFilterIntent` exposes a Boring Notch Focus Filter in macOS Focus settings.
- The Focus Filter lets the user select the notification categories permitted to open the notch automatically for that specific Focus mode.

macOS does not publicly expose the name of the active Focus to the app. The system associates each configured Focus mode with its chosen Boring Notch filter and activates the corresponding intent. Boring Notch therefore stores and displays the active policy, not a privately discovered Focus name.

Automatic-opening eligibility is evaluated in this order:

1. The notification must have passed the macOS Focus filter and appeared as an observable banner.
2. Its app and category must be enabled in Boring Notch.
3. If an active Boring Notch Focus Filter supplies a category set, that set is authoritative for automatic opening.
4. Without a category override, the category's `Never`, `Only outside Focus`, or `Always` policy applies.
5. If Focus state is unavailable or authorization is denied, `Only outside Focus` behaves conservatively and does not auto-open.

Settings show the current effective Focus policy and explain that per-Focus category selection is configured in System Settings. The app does not attempt to reproduce or edit the user's list of named Focus modes.

### Closed and expanded presentation

Informational notifications reorganize the inside of the closed notch into a compact row containing app identity, concise text, and an optional action hint. They never extend outside the notch box.

When automatic opening is permitted, the normal notch-opening animation runs and the expanded interior temporarily shows:

- source app and optional contact avatar;
- title and readable message body;
- OTP copy action when applicable;
- native notification actions when safely available;
- reply field and suggestions for supported message sources;
- a small stack affordance for queued notifications.

Resolving, dismissing, or expiring the notification restores the previous notch content. Reduce Motion uses the app's reduced-motion alternative while preserving the same state transitions.

### OTP and action handling

OTP values are detected locally and displayed with a prominent Copy action. Copying uses the normal pasteboard and marks the notification resolved without claiming that the source notification was dismissed unless the helper confirms it.

Action buttons are enabled only when the helper can identify a corresponding system-notification control. If an action disappears or cannot be invoked, the item remains visible with an explicit failure state rather than reporting success.

### Replies

Reply execution follows a capability ladder:

1. Interact with an active notification reply control through Accessibility.
2. Interact with a deliberately held notification while it remains valid.
3. Use direct Messages support where available.
4. Use a supported WhatsApp deep link.
5. Copy the reply and open the source app.

Only confirmed Accessibility, held-banner, or direct-app operations may show `Sent`. The final fallback reports `Copied` and opens the app, never a false success. The notch window becomes key only while the reply field is active and returns focus afterward.

### Contact avatars

Contacts access is optional. When authorized, sender identifiers are matched locally and cached only as short-lived in-memory avatar data. Without permission or a match, the UI uses the source app icon or a monogram. Avatar failure never suppresses a notification.

### Apple Intelligence

Apple Intelligence support is optional and disabled by default. When the on-device Foundation Models capability is available, it may:

- propose short reply suggestions;
- refine classification when deterministic rules return `other`;
- summarize long text for the compact presentation.

Deterministic OTP, call, permission, and app-based classification always wins. Notification text is not sent to a remote service or persisted. Model unavailability, device ineligibility, or generation failure simply removes smart suggestions and keeps the normal notification flow.

### Queue and expiry

The queue exists only in memory and has a fixed upper bound. Calls have highest precedence, followed by OTP, permission/decision, message, mail, and other content. Within the same priority, newer items appear first while preserving a path back to older queued items.

Expiry is category-sensitive: informational items time out quickly, while calls and actionable prompts remain until the source control disappears, the user resolves them, or a safety timeout restores the original banner. App termination clears all notification state.

## Compact Player and Audio Output

### Compact player

The current media player remains the default. An opt-in compact layout from PR #1447 reorganizes the same controls into a denser expanded-notch presentation; it does not create a new window or replace the media backend.

Both layouts share the existing `MusicManager` state and control-slot configuration. Switching layout mode preserves playback, selected source, and current progress.

### Audio-output switching

An audio-output selector is available from both normal and compact player layouts. `AudioRouteManager` uses public CoreAudio APIs to enumerate active output devices, identify the current default output, and request a new default device.

The menu updates when devices connect, disconnect, or change. A device that disappears during selection is ignored and the current route remains unchanged. Failure to switch is shown inline without interrupting playback.

## Settings Structure

Existing Settings navigation is extended without replacing the current window architecture:

- **Calendar:** `Show meeting join actions`.
- **Media:** progress indicator, color, thickness, compact player, and audio-output selector visibility.
- **Shelf:** explanatory text for image conversion; conversion itself remains contextual to image items.
- **Notifications:** master enablement, setup status, app allowlist, per-category visibility and automatic-opening policy, active Focus policy, Contacts, Apple Intelligence, and reset actions.

Controls use native SwiftUI pickers, toggles, menus, semantic colors, keyboard focus, VoiceOver labels, and the existing resizable Settings window. Recurring permission problems are presented inline with a route to the relevant System Settings pane rather than repeated modal alerts.

## Privacy and Security

- Notification payloads, reply drafts, avatars, and model suggestions remain in memory only.
- Accessibility access is requested only after explicit enablement and can be revoked without breaking app launch.
- Contacts access is independent from notification access.
- Apple Intelligence is independent from both Accessibility and Contacts.
- The app observes visible notification UI; it does not read Notification Center databases or bypass macOS Focus filtering.
- App and category allowlists are persisted, but notification contents are not.
- Security-scoped Shelf URLs are accessed only for the duration of conversion.

## Failure and Recovery

- XPC failures trigger bounded retries and restore any held notification UI.
- Unknown notification structures degrade to non-actionable compact content or are ignored if safe extraction is impossible.
- Focus-status denial disables only Focus-dependent automatic opening.
- Contacts and Apple Intelligence failures degrade independently.
- A notification renderer failure must restore the prior notch content.
- Meeting-link, image-conversion, media-progress, or audio-route failures must not affect unrelated notch activities.
- Feature disablement is immediate and leaves no background observer or power/resource assertion active.

## Validation

Implementation validation will be incremental and non-TDD:

1. Build after each feature slice with Derived Data under `/tmp`.
2. Review compiler errors and new warnings before continuing.
3. Manually verify image conversion for each available encoder and collision naming.
4. Manually verify supported meeting providers and malformed-link fallback.
5. Verify media progress across play, pause, seek, unknown duration, notch opening, and transient activities.
6. Verify notification setup, permission denial, helper reconnect, category policies, queueing, OTP copy, replies, and state restoration.
7. Verify Focus inactive, Focus active without a Boring Notch filter, and Focus active with per-category filter overrides.
8. Verify normal and compact players plus audio-device connect/disconnect behavior.
9. Verify Light/Dark Mode, Reduce Motion, Reduce Transparency, keyboard navigation, and VoiceOver labels on new controls.
10. Perform a final Release build and install/smoke check without importing unrelated PR artifacts.

## Out of Scope

- Cherry-picking or merging the selected PR branches wholesale.
- A floating notification card or any actionable surface outside the notch.
- Reading private macOS notification databases or private Focus-mode names.
- Replacing the current notch window or opening animation.
- Persisting notification history or reply content.
- Cloud-based notification analysis.
- Batch image conversion, resizing, quality controls, video conversion, or source overwrite.
- Supporting meeting providers beyond the initial local detector set.
- Replacing the current player with compact mode by default.
- Publishing, pushing, or opening a pull request as part of this implementation.
