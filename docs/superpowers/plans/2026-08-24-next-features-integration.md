# Next Features Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development only when the user explicitly requests delegation; otherwise execute this plan inline, task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Shelf image conversion, calendar meeting joining, media progress, compact player/audio routing, and configurable notification Live Activities with macOS Focus integration while preserving the existing notch window and animation.

**Architecture:** Port only the feature-owned pieces of PRs #1303, #1423, #1350, and #1447. Keep the current `ContentView`, `BoringViewModel`, `BoringViewCoordinator`, XPC helper, Settings window, and media/calendar services as the integration points; introduce focused managers for transient presentation, notification policy, Focus, audio routing, and generated Shelf files.

**Tech Stack:** Swift 6, SwiftUI, AppKit, EventKit, ImageIO, UniformTypeIdentifiers, CoreAudio, ApplicationServices Accessibility, NSXPCConnection/AsyncXPCConnection, Contacts, Intents, AppIntents, Foundation Models when available, Defaults, Xcode 27/macOS 14+ deployment.

---

## Working Rules

- Do not cherry-pick the selected PR branches. Read their feature files and port against the current branch.
- Do not add a test target or follow TDD. The user explicitly chose implementation-first validation for this project.
- Build after every task with Derived Data and package caches under `/tmp`.
- Keep `.superpowers/` visual-companion output untracked.
- Use `apply_patch` for source edits.
- Commit after every task that leaves the app building.

Use this build command throughout:

```bash
xcodebuild -quiet \
  -project boringNotch.xcodeproj \
  -scheme boringNotch \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/BoringNotchDerivedData-next \
  -clonedSourcePackagesDirPath /tmp/BoringNotchSourcePackages-next \
  CODE_SIGNING_ALLOWED=NO build
```

Expected result: exit code `0` with no new `error:` lines. Existing dependency or deprecation warnings may remain, but every new warning introduced by these tasks must be resolved before the task commit.

## File and Responsibility Map

### Shelf conversion

- Modify `boringNotch/components/Shelf/Services/ImageProcessingService.swift`: supported encoder discovery and single-format ImageIO conversion.
- Modify `boringNotch/components/Shelf/ViewModels/ShelfItemViewModel.swift`: contextual conversion submenu, filename collision handling, result insertion, and inline status.
- Modify `boringNotch/components/Shelf/Views/ShelfItemView.swift`: non-modal conversion progress/error presentation.

### Calendar meetings

- Create `boringNotch/models/MeetingLink.swift`: meeting provider and normalized link value.
- Create `boringNotch/Providers/MeetingLinkDetector.swift`: URL/location/notes parsing and host validation.
- Modify `boringNotch/models/EventModel.swift`: computed `meetingLink`.
- Modify `boringNotch/components/Calendar/BoringCalendar.swift`: join action, hover affordance, and context menu.
- Modify `boringNotch/components/Live activities/CalendarLiveActivity.swift`: interactive ring button with accessibility text.
- Modify `boringNotch/ContentView.swift`: pass the active event to the Live Activity.
- Modify `boringNotch/models/Constants.swift` and `boringNotch/components/Settings/SettingsView.swift`: enabled-by-default preference.

### Media

- Create `boringNotch/components/Music/MediaProgressBar.swift`: tapered notch-contour progress renderer.
- Create `boringNotch/managers/AudioRouteManager.swift`: CoreAudio output enumeration, listeners, and switching.
- Create `boringNotch/components/Notch/CompactHomeView.swift`: opt-in compact player and shared output picker.
- Modify `boringNotch/models/MusicControlButton.swift`: media-output slot.
- Modify `boringNotch/components/Notch/NotchHomeView.swift`: standard-player output control.
- Modify `boringNotch/ContentView.swift`: progress overlay and compact/full layout selection.
- Modify `boringNotch/models/Constants.swift` and `boringNotch/components/Settings/SettingsView.swift`: media preferences.

### Notifications and Focus

- Create `BoringNotchXPCHelper/NotificationWatcher.swift`: Notification Center Accessibility capture and action execution.
- Create `BoringNotchXPCHelper/MessagesSender.swift`: direct Messages fallback.
- Modify both copies of `BoringNotchXPCHelperProtocol.swift`: notification transport and action methods.
- Modify `BoringNotchXPCHelper/BoringNotchXPCHelper.swift`: watcher ownership and protocol implementation.
- Modify `boringNotch/XPCHelperClient/XPCHelperClient.swift`: exported callback object, reconnect, and async wrappers.
- Create `boringNotch/models/SystemNotification.swift`: transient payload, category, action, and presentation policy values.
- Create `boringNotch/helpers/OTPDetector.swift`: deterministic OTP extraction.
- Create `boringNotch/managers/NotificationPolicyManager.swift`: app/category/Focus eligibility.
- Create `boringNotch/managers/FocusModeManager.swift`: public Focus authorization and active state.
- Create `boringNotch/AppIntents/NotificationFocusFilterIntent.swift`: per-Focus category override.
- Create `boringNotch/managers/SystemNotificationManager.swift`: queue, expiry, helper lifecycle, actions, and replies.
- Create `boringNotch/managers/ContactAvatarManager.swift`: optional in-memory Contacts lookup.
- Create `boringNotch/managers/SmartReplyManager.swift`: optional on-device suggestions.
- Create `boringNotch/managers/TransientNotchPresentationCoordinator.swift`: snapshot, auto-open, and restoration.
- Create `boringNotch/components/Notch/NotificationLiveActivity.swift`: compact and expanded notification content.
- Create `boringNotch/components/Notch/LiveActivityStack.swift`: queued notification navigation.
- Create `boringNotch/components/Settings/NotificationSettingsView.swift`: setup, app allowlist, category matrix, Focus, Contacts, and intelligence settings.
- Modify `boringNotch/ContentView.swift`, `boringNotch/boringNotchApp.swift`, `boringNotch/models/Constants.swift`, `boringNotch/enums/generic.swift`, `boringNotch/Info.plist`, entitlements, and the Xcode project for final integration.

### Project registration

The project uses explicit PBX groups. Every new Swift file must be added to its matching group and target membership in `boringNotch.xcodeproj/project.pbxproj`; helper files belong only to `BoringNotchXPCHelper`, while app files belong only to `boringNotch`.

---

### Task 1: Establish a Clean Baseline

**Files:**
- Inspect: `boringNotch.xcodeproj/project.pbxproj`
- Inspect: `boringNotch/ContentView.swift`
- Inspect: `boringNotch/components/Shelf/Services/ImageProcessingService.swift`

- [ ] **Step 1: Confirm the current branch and expected untracked files**

Run:

```bash
git branch --show-current
git status --short
```

Expected: branch `feat/productivity-features`; only `.superpowers/` is untracked.

- [ ] **Step 2: Run the baseline build**

Run the shared Debug build command from the top of this plan.

Expected: exit code `0`. If the package cache is empty and network access is blocked, retry the same command with approved network access; do not modify package versions.

- [ ] **Step 3: Record the baseline without creating a commit**

Run:

```bash
git status --short
git log -1 --oneline
```

Expected: no source changes and current HEAD at or after `4916eb92 docs: define next feature integrations`.

---

### Task 2: Complete Quick Shelf Image Conversion

**Files:**
- Modify: `boringNotch/components/Shelf/Services/ImageProcessingService.swift`
- Modify: `boringNotch/components/Shelf/ViewModels/ShelfItemViewModel.swift`
- Modify: `boringNotch/components/Shelf/Views/ShelfItemView.swift`

- [ ] **Step 1: Replace the broad conversion options with the approved format model**

Define the supported cases and runtime encoder check in `ImageProcessingService.swift`:

```swift
enum ImageConversionFormat: String, CaseIterable, Identifiable, Sendable {
    case png, jpeg, heic, webP

    var id: String { rawValue }

    var contentType: UTType {
        switch self {
        case .png: .png
        case .jpeg: .jpeg
        case .heic: .heic
        case .webP: .webP
        }
    }

    var fileExtension: String {
        switch self {
        case .jpeg: "jpg"
        default: rawValue.lowercased()
        }
    }

    var displayName: String { rawValue == "webP" ? "WebP" : rawValue.uppercased() }
}
```

Expose:

```swift
func supportedOutputFormats(for sourceURL: URL) -> [ImageConversionFormat]
func convertImage(from sourceURL: URL, to format: ImageConversionFormat, suggestedName: String) async throws -> URL
```

Use `CGImageSourceCreateWithURL`, `CGImageSourceCreateImageAtIndex`, `CGImageDestinationCreateWithURL`, and `CGImageDestinationFinalize`. Preserve pixel dimensions and omit the source format from the returned list. Use fixed system-default encoder quality because resizing and quality controls are outside scope.

- [ ] **Step 2: Replace the conversion dialog with direct contextual actions**

In `ShelfItemViewModel.presentContextMenu`, replace `Convert Image…` with one menu item per supported target:

```swift
let conversionMenu = NSMenu()
for format in ImageProcessingService.shared.supportedOutputFormats(for: url) {
    let action = NSMenuItem(
        title: format.displayName,
        action: #selector(convertImageFromMenu(_:)),
        keyEquivalent: ""
    )
    action.representedObject = format.rawValue
    action.target = self
    conversionMenu.addItem(action)
}
```

The action must resolve the security-scoped source URL, compute `name`, `name 2`, `name 3` against filenames already represented in `ShelfStateViewModel.shared.items`, run conversion, create a temporary bookmark, and append a new `ShelfItem(isTemporary: true)` without removing the source.

- [ ] **Step 3: Add non-modal operation state**

Publish conversion state from the item view model:

```swift
enum ShelfImageOperationState: Equatable {
    case idle
    case converting(ImageConversionFormat)
    case succeeded(String)
    case failed(String)
}

@Published private(set) var imageOperationState: ShelfImageOperationState = .idle
```

Render a small progress spinner over the thumbnail while converting and an accessible transient status label for success or failure. Clear success after two seconds; retain failure until the next action or item dismissal. Do not show an `NSAlert`.

- [ ] **Step 4: Build and smoke-check conversion**

Run the shared build command. Then run the Debug app and manually check PNG to JPEG, JPEG to PNG, HEIC when available, WebP only when ImageIO exposes an encoder, numeric suffixes, source retention, and corrupt-data failure.

- [ ] **Step 5: Commit the Shelf slice**

```bash
git add boringNotch/components/Shelf/Services/ImageProcessingService.swift \
  boringNotch/components/Shelf/ViewModels/ShelfItemViewModel.swift \
  boringNotch/components/Shelf/Views/ShelfItemView.swift
git commit -m "feat: add quick shelf image conversion"
```

---

### Task 3: Detect and Join Calendar Meetings

**Files:**
- Create: `boringNotch/models/MeetingLink.swift`
- Create: `boringNotch/Providers/MeetingLinkDetector.swift`
- Modify: `boringNotch/models/EventModel.swift`
- Modify: `boringNotch/components/Calendar/BoringCalendar.swift`
- Modify: `boringNotch/components/Live activities/CalendarLiveActivity.swift`
- Modify: `boringNotch/ContentView.swift`
- Modify: `boringNotch/models/Constants.swift`
- Modify: `boringNotch/components/Settings/SettingsView.swift`
- Modify: `boringNotch.xcodeproj/project.pbxproj`

- [ ] **Step 1: Port the provider model and conservative detector**

Port `MeetingProvider`, `MeetingLink`, and `MeetingLinkDetector` from PR #1423. Keep the exact provider host rules:

```swift
case googleMeet: ["meet.google.com", "hangouts.google.com"]
case zoom: ["zoom.us", "zoomgov.com"]
case teams: ["teams.microsoft.com", "teams.live.com"]
case webex: ["webex.com"]
case whereby: ["whereby.com"]
case jitsi: ["meet.jit.si"]
```

Accept only HTTP/HTTPS URLs and match either the exact host or a `.`-delimited subdomain suffix. Detection order is structured URL, location, then notes.

- [ ] **Step 2: Add the event-level computed value**

Add to `EventModel`:

```swift
var meetingLink: MeetingLink? {
    guard type.isEvent else { return nil }
    return MeetingLinkDetector.detect(url: url, location: location, notes: notes)
}
```

This keeps EventKit mapping unchanged and makes reminders ineligible.

- [ ] **Step 3: Add the event-row join behavior**

Add `joinMeetingOnEventTap` to Defaults with `true` as the default. In `EventListView`, primary click joins when enabled, otherwise opens Calendar. Add a stable 16-point `video.fill` affordance and context actions for Join, Copy Meeting Link, and Open in Calendar. Give icon-only actions explicit accessibility labels.

- [ ] **Step 4: Make the existing calendar Live Activity clickable**

Change `CalendarLiveActivityRing` to accept `event: EventModel?` and `joinEnabled: Bool`. Wrap the ring in a plain button only when a meeting link exists; otherwise keep the noninteractive ring. The action is:

```swift
if let url = event?.meetingLink?.url {
    NSWorkspace.shared.open(url)
}
```

Add provider-specific help and accessibility text. Update both call sites in `ContentView`.

- [ ] **Step 5: Add the Calendar setting and register files**

Add `Show meeting join actions` beneath the calendar Live Activity toggle. Register both new Swift files in the app target only.

- [ ] **Step 6: Build and smoke-check providers**

Run the shared build. Create local events containing each provider in URL, location, and notes. Verify field priority, join behavior, Calendar fallback, unsupported host rejection, and malformed URL rejection.

- [ ] **Step 7: Commit the calendar slice**

```bash
git add boringNotch/models/MeetingLink.swift \
  boringNotch/Providers/MeetingLinkDetector.swift \
  boringNotch/models/EventModel.swift \
  boringNotch/components/Calendar/BoringCalendar.swift \
  'boringNotch/components/Live activities/CalendarLiveActivity.swift' \
  boringNotch/ContentView.swift \
  boringNotch/models/Constants.swift \
  boringNotch/components/Settings/SettingsView.swift \
  boringNotch.xcodeproj/project.pbxproj
git commit -m "feat: join calendar meetings from notch"
```

---

### Task 4: Add Optional Media Progress Around the Closed Notch

**Files:**
- Create: `boringNotch/components/Music/MediaProgressBar.swift`
- Modify: `boringNotch/ContentView.swift`
- Modify: `boringNotch/models/Constants.swift`
- Modify: `boringNotch/components/Settings/SettingsView.swift`
- Modify: `boringNotch.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add progress preferences**

Use the existing `SliderColorEnum` and add:

```swift
static let showMediaProgressBar = Key<Bool>("showMediaProgressBar", default: false)
static let mediaProgressBarThickness = Key<Double>("mediaProgressBarThickness", default: 2)
static let mediaProgressBarColor = Key<SliderColorEnum>("mediaProgressBarColor", default: .albumArt)
```

Do not expose the PR's update-interval control; a fixed 0.5-second periodic timeline matches the approved scope.

- [ ] **Step 2: Port the tapered contour shape**

Port `MediaProgressBar` and `TaperedNotchProgress` from PR #1350. Keep playback calculation based on:

```swift
let duration = musicManager.songDuration
let position = musicManager.estimatedPlaybackPosition(at: date)
let fraction = duration > 0 ? min(max(position / duration, 0), 1) : 0
```

Return an empty path for invalid duration, fraction, or thickness. Tint from album art, white, or effective accent; album-art failure falls back to accent.

- [ ] **Step 3: Overlay the progress on the current notch shape**

Add a computed visibility predicate to `ContentView`:

```swift
private var mediaProgressVisible: Bool {
    Defaults[.showMediaProgressBar]
        && vm.notchState == .closed
        && !vm.hideOnClosed
        && !closedSystemHUDActive
        && !TransientNotchPresentationCoordinator.shared.isPresenting
        && (musicManager.isPlaying || !musicManager.isPlayerIdle)
        && musicManager.songDuration > 0
}
```

Apply the bar as a non-hit-testing overlay on the clipped notch shape. Fade out before expansion and back in after the closed state settles.

- [ ] **Step 4: Add Media settings**

Add the master toggle, 1–5 point slider with 0.5 steps, and album-art/white/accent picker. Disable child controls while the toggle is off.

- [ ] **Step 5: Build and smoke-check playback states**

Verify play, pause, seek, track change, unknown duration, notch open/close, productivity indicators, HUD, and feature disabled.

- [ ] **Step 6: Commit the media-progress slice**

```bash
git add boringNotch/components/Music/MediaProgressBar.swift \
  boringNotch/ContentView.swift \
  boringNotch/models/Constants.swift \
  boringNotch/components/Settings/SettingsView.swift \
  boringNotch.xcodeproj/project.pbxproj
git commit -m "feat: add optional notch media progress"
```

---

### Task 5: Add Audio-Output Switching

**Files:**
- Create: `boringNotch/managers/AudioRouteManager.swift`
- Modify: `boringNotch/models/MusicControlButton.swift`
- Modify: `boringNotch/components/Notch/NotchHomeView.swift`
- Modify: `boringNotch.xcodeproj/project.pbxproj`

- [ ] **Step 1: Port and harden the CoreAudio manager**

Port `AudioOutputDevice` and `AudioRouteManager` from PR #1447. Keep blocking reads on a private serial queue. Publish:

```swift
@Published private(set) var devices: [AudioOutputDevice] = []
@Published private(set) var activeDeviceID: AudioDeviceID = 0
@Published private(set) var lastError: String?

func refreshDevices()
func select(_ device: AudioOutputDevice)
```

Register CoreAudio property listeners for device-list and default-output changes during initialization and remove them in `deinit`. A failed switch leaves `activeDeviceID` unchanged and sets a concise error.

- [ ] **Step 2: Add the shared output picker**

Add `AudioOutputPicker` and `MediaOutputSlotButton` to `NotchHomeView.swift`. Refresh on opening, show active-device checkmark and `lastError`, close after success, dismiss on Escape, and expose device names to accessibility.

- [ ] **Step 3: Add the configurable standard-player slot**

Add `.mediaOutput` to `MusicControlButton`, label it `Audio Output`, use `airplayaudio`, include it in `pickerOptions`, and render `MediaOutputSlotButton()` in `MusicControlsView.slotView(for:)`.

- [ ] **Step 4: Build and smoke-check route changes**

Verify built-in speakers, a connected route, disconnect while open, and switch failure. Playback must continue.

- [ ] **Step 5: Commit the audio-routing slice**

```bash
git add boringNotch/managers/AudioRouteManager.swift \
  boringNotch/models/MusicControlButton.swift \
  boringNotch/components/Notch/NotchHomeView.swift \
  boringNotch.xcodeproj/project.pbxproj
git commit -m "feat: switch audio output from player"
```

---

### Task 6: Add the Opt-In Compact Player

**Files:**
- Create: `boringNotch/components/Notch/CompactHomeView.swift`
- Modify: `boringNotch/ContentView.swift`
- Modify: `boringNotch/models/Constants.swift`
- Modify: `boringNotch/components/Settings/SettingsView.swift`
- Modify: `boringNotch.xcodeproj/project.pbxproj`

- [ ] **Step 1: Port the compact layout against current player components**

Port `CompactHomeView` from PR #1447, reusing current `MusicSliderView`, `MusicManager`, album art, visualizer, and `AudioOutputPicker`. Keep five controls fixed to shuffle, previous, play/pause, next, and audio output. Do not duplicate media state.

- [ ] **Step 2: Select the layout only for the Home media view**

Add:

```swift
static let compactMode = Key<Bool>("compactMode", default: false)
```

Render `CompactHomeView` only when compact mode is enabled, the selected view is `.home`, and media content is available. Other tabs, HUDs, and transient notification branches retain their renderers.

- [ ] **Step 3: Add the opt-in setting**

Add `Use compact player when the notch is open` to Media settings. Default stays off.

- [ ] **Step 4: Build and smoke-check layout switching**

Verify standard and compact modes, playback preservation, seek, five controls, audio output, paused media, opening/closing, and non-Home tabs.

- [ ] **Step 5: Commit the compact-player slice**

```bash
git add boringNotch/components/Notch/CompactHomeView.swift \
  boringNotch/ContentView.swift \
  boringNotch/models/Constants.swift \
  boringNotch/components/Settings/SettingsView.swift \
  boringNotch.xcodeproj/project.pbxproj
git commit -m "feat: add opt-in compact media player"
```

---

### Task 7: Add Notification XPC Capture and Action Transport

**Files:**
- Create: `BoringNotchXPCHelper/NotificationWatcher.swift`
- Create: `BoringNotchXPCHelper/MessagesSender.swift`
- Modify: `BoringNotchXPCHelper/BoringNotchXPCHelperProtocol.swift`
- Modify: `boringNotch/XPCHelperClient/BoringNotchXPCHelperProtocol.swift`
- Modify: `BoringNotchXPCHelper/BoringNotchXPCHelper.swift`
- Modify: `boringNotch/XPCHelperClient/XPCHelperClient.swift`
- Modify: `boringNotch.xcodeproj/project.pbxproj`

- [ ] **Step 1: Port the helper watcher without debug UI**

Port `NotificationWatcher` from PR #1447 with dispatch-source polling, banner-subrole matching, bidirectional-control normalization, held-banner refresh, and action traversal. Exclude `NotificationDebugWindow` and debug-dump UI.

Keep this contract:

```swift
var onBanner: ((CapturedNotification) -> Void)?
var onBannerGone: ((String) -> Void)?
func start() -> Bool
func stop()
func hold(token: String)
func release(token: String)
func reply(token: String, text: String) -> Bool
func performAction(token: String, name: String) -> Bool
func open(token: String) -> Bool
func dismiss(token: String) -> Bool
```

When holding a banner, store its original window position before moving it off-screen. A normal release restores that position and stops the keep-alive refresh; dismissal is a separate explicit action. `stop()` and connection invalidation restore every held window before clearing state. Never log message bodies.

- [ ] **Step 2: Extend both protocol copies identically**

Add:

```swift
@objc protocol BoringNotchXPCAppDelegate {
    func notificationDidAppear(_ payload: [String: String])
    func notificationDidDisappear(_ token: String)
}
```

Add helper methods for start, stop, hold, release, reply, named action, open, dismiss, and direct Messages sending. Configure allowed classes for dictionary payloads.

- [ ] **Step 3: Wire helper ownership and callbacks**

The helper owns one watcher, forwards a string dictionary through the exported delegate, and stops/releases on teardown. Reuse the existing Accessibility authorization path.

- [ ] **Step 4: Add client reconnect and async wrappers**

`XPCHelperClient` exports one callback delegate, republishes `.systemNotificationDidAppear` and `.systemNotificationDidDisappear`, and clears its connection on interruption/invalidation. While notification integration remains enabled, reconnect with delays of 0.5, 1, and 2 seconds, then wait for the next lifecycle or settings trigger. Failed calls return `false` without optimistic success.

- [ ] **Step 5: Build both targets and inspect target membership**

Run the shared build, then:

```bash
rg -n "NotificationWatcher.swift|MessagesSender.swift" boringNotch.xcodeproj/project.pbxproj
```

Expected: helper group and helper Sources membership only.

- [ ] **Step 6: Commit the transport slice**

```bash
git add BoringNotchXPCHelper/NotificationWatcher.swift \
  BoringNotchXPCHelper/MessagesSender.swift \
  BoringNotchXPCHelper/BoringNotchXPCHelperProtocol.swift \
  boringNotch/XPCHelperClient/BoringNotchXPCHelperProtocol.swift \
  BoringNotchXPCHelper/BoringNotchXPCHelper.swift \
  boringNotch/XPCHelperClient/XPCHelperClient.swift \
  boringNotch.xcodeproj/project.pbxproj
git commit -m "feat: capture notification banners through xpc"
```

---

### Task 8: Model Notifications and Per-Category Policies

**Files:**
- Create: `boringNotch/models/SystemNotification.swift`
- Create: `boringNotch/helpers/OTPDetector.swift`
- Create: `boringNotch/managers/NotificationPolicyManager.swift`
- Modify: `boringNotch/models/Constants.swift`
- Modify: `boringNotch.xcodeproj/project.pbxproj`

- [ ] **Step 1: Define stable notification values**

```swift
enum NotificationCategory: String, CaseIterable, Codable, Hashable, Defaults.Serializable, Sendable {
    case otp, call, permission, decision, message, mail, other
}

enum NotificationAutoOpenPolicy: String, CaseIterable, Codable, Defaults.Serializable, Sendable {
    case never, outsideFocus, always
}

struct NotificationCategoryPreference: Codable, Defaults.Serializable, Equatable, Sendable {
    var isVisible: Bool
    var autoOpen: NotificationAutoOpenPolicy
}

enum NotificationPresentationDecision: Equatable, Sendable {
    case ignore, compact, autoOpen
}

enum NotificationActionState: Equatable, Sendable {
    case idle
    case working
    case sent
    case copiedAndOpened
    case failed(String)
}

struct SystemNotificationItem: Identifiable, Equatable, Sendable {
    let id: String
    let appName: String
    let bundleIdentifier: String?
    let title: String
    let subtitle: String?
    let body: String?
    let actions: [String]
    let receivedAt: Date
    let category: NotificationCategory
    let otpCode: String?
}
```

Do not conform `SystemNotificationItem` to persisted storage.

- [ ] **Step 2: Port deterministic OTP extraction**

Port `OTPDetector` and expose `static func detect(in text: String) -> String?`. Require security context or an app/action signal for a bare token. Reject dates, prices, phone numbers, years, and long identifiers.

- [ ] **Step 3: Add the policy manager and defaults**

Classify by OTP, call, permission, decision, known messaging app, known mail app, then other. Persist master enablement, app allowlist, category preference matrix, Contacts flag, and intelligence flag. The suggested app set is Messages, FaceTime, Mail, Outlook, WhatsApp, Telegram, Telegram Desktop, Discord, and Claude, using the bundle identifiers from PR #1447.

Define the recommended matrix explicitly:

```swift
static let recommendedPreferences: [NotificationCategory: NotificationCategoryPreference] = [
    .otp: .init(isVisible: true, autoOpen: .outsideFocus),
    .call: .init(isVisible: true, autoOpen: .always),
    .permission: .init(isVisible: true, autoOpen: .outsideFocus),
    .decision: .init(isVisible: true, autoOpen: .outsideFocus),
    .message: .init(isVisible: true, autoOpen: .never),
    .mail: .init(isVisible: true, autoOpen: .never),
    .other: .init(isVisible: true, autoOpen: .never)
]
```

Use:

```swift
func decision(
    for item: SystemNotificationItem,
    isFocusActive: Bool?,
    focusOverride: Set<NotificationCategory>?
) -> NotificationPresentationDecision
```

Return `.ignore`, `.compact`, or `.autoOpen`. Treat unknown Focus as active for `outsideFocus`.

- [ ] **Step 4: Build and perform deterministic checks**

Check representative OTP, call, message, mail, permission, decision, and other inputs through a temporary app debug path. Confirm unknown content stays noninterruptive and no notification text reaches Defaults.

- [ ] **Step 5: Commit the model/policy slice**

```bash
git add boringNotch/models/SystemNotification.swift \
  boringNotch/helpers/OTPDetector.swift \
  boringNotch/managers/NotificationPolicyManager.swift \
  boringNotch/models/Constants.swift \
  boringNotch.xcodeproj/project.pbxproj
git commit -m "feat: add notification category policies"
```

---

### Task 9: Integrate macOS Focus Status and Focus Filters

**Files:**
- Create: `boringNotch/managers/FocusModeManager.swift`
- Create: `boringNotch/AppIntents/NotificationFocusFilterIntent.swift`
- Modify: `boringNotch/boringNotchApp.swift`
- Modify: `boringNotch.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add public Focus-status observation**

Wrap `INFocusStatusCenter.default` and publish:

```swift
@Published private(set) var authorizationStatus: INFocusStatusAuthorizationStatus
@Published private(set) var isFocusActive: Bool?

func requestAuthorization() async
func refresh()
```

The public API has no named-Focus property or change notification. Refresh on app activation and run a low-frequency two-second `DispatchSourceTimer` only while notification integration is enabled. Each tick reads `focusStatus.isFocused`; `nil` means unavailable or denied. Stop the timer when notification integration is disabled, the screen locks, or the app terminates. Do not infer a name.

- [ ] **Step 2: Define the Focus Filter intent**

Create an `AppEnum` for the seven categories and a `SetFocusFilterIntent`:

```swift
struct NotificationFocusFilterIntent: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "Boring Notch Notifications"

    @Parameter(title: "Categories allowed to open the notch")
    var categories: [NotificationFocusCategory]

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .notificationFocusFilterChanged,
            object: categories.map(\.rawValue)
        )
        return .result()
    }
}
```

Suggest `Calls and codes`, `No automatic opening`, and `All configured categories`. Map `NotificationFocusFilterIntent.current.categories` to `Set<NotificationCategory>`. Store only the effective set while active.

- [ ] **Step 3: Refresh Focus state during lifecycle**

Refresh at launch, app activation, and filter change. Request authorization only from notification setup.

- [ ] **Step 4: Build and verify System Settings integration**

Run the shared build, launch a signed Debug app, and verify Boring Notch under System Settings → Focus → Focus Filters. Configure two Focus modes and verify effective sets switch.

- [ ] **Step 5: Commit the Focus slice**

```bash
git add boringNotch/managers/FocusModeManager.swift \
  boringNotch/AppIntents/NotificationFocusFilterIntent.swift \
  boringNotch/boringNotchApp.swift \
  boringNotch.xcodeproj/project.pbxproj
git commit -m "feat: respect macos focus notification policy"
```

---

### Task 10: Add the In-Memory Notification Queue and Actions

**Files:**
- Create: `boringNotch/managers/SystemNotificationManager.swift`
- Modify: `boringNotch/boringNotchApp.swift`
- Modify: `boringNotch.xcodeproj/project.pbxproj`

- [ ] **Step 1: Port the manager around the new policy types**

Create one `@MainActor` singleton:

```swift
@Published private(set) var primary: SystemNotificationItem?
@Published private(set) var queued: [SystemNotificationItem] = []
@Published private(set) var presentationDecision: NotificationPresentationDecision = .ignore
@Published private(set) var actionState: NotificationActionState = .idle

func startIfEnabled() async
func stop()
func select(_ item: SystemNotificationItem)
func resolvePrimary()
func copyOTP()
func openPrimary() async
func dismissPrimary() async
func perform(action: String) async
func reply(_ text: String) async
```

Cap the queue at 8, coalesce by token, and prioritize call, OTP, permission, decision, message, mail, other.

- [ ] **Step 2: Implement category-sensitive lifecycle**

Informational content expires after 8 seconds, OTP after 30 seconds, and calls/actionable prompts while live with a 60-second safety release. Cancellation, disappearance, disablement, helper failure, lock, and termination release banners and cancel tasks.

- [ ] **Step 3: Implement truthful actions and reply fallbacks**

Reply order is active Accessibility banner, held banner, direct Messages, WhatsApp deep link, then pasteboard plus source app. Only confirmed sends produce `.sent`; final fallback produces `.copiedAndOpened`.

- [ ] **Step 4: Wire launch, lock, unlock, disablement, and termination**

Start only when enabled and authorized. Stop on lock/termination; restart on unlock. Use a Defaults publisher for live enable/disable changes.

- [ ] **Step 5: Build and smoke-check without UI**

Use allowed-app notifications and verify capture, coalescing, order, disappearance, action confirmation, reconnect, and absence of payloads in persisted defaults.

- [ ] **Step 6: Commit the queue/action slice**

```bash
git add boringNotch/managers/SystemNotificationManager.swift \
  boringNotch/boringNotchApp.swift \
  boringNotch.xcodeproj/project.pbxproj
git commit -m "feat: manage transient notification queue"
```

---

### Task 11: Add Avatars and Optional On-Device Suggestions

**Files:**
- Create: `boringNotch/managers/ContactAvatarManager.swift`
- Create: `boringNotch/managers/SmartReplyManager.swift`
- Modify: `boringNotch/managers/SystemNotificationManager.swift`
- Modify: `boringNotch/Info.plist`
- Modify: `boringNotch/boringNotch.entitlements`
- Modify: `boringNotch.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add optional in-memory Contacts lookup**

Port Contacts lookup from PR #1447. Request only from Settings. Match normalized sender names, emails, or phones. Cache `NSImage` values in process-only `NSCache`; return `nil` when denied or unmatched.

Add `NSContactsUsageDescription` explaining that photos identify notification senders inside the notch. Add the sandbox entitlement `com.apple.security.personal-information.addressbook = true` to the app target only.

- [ ] **Step 2: Add availability-gated Foundation Models suggestions**

Port `SmartReplyManager` with compile/runtime guards:

```swift
enum Availability { case available; case unavailable(String) }
static var availability: Availability { get }
func suggestions(for item: SystemNotificationItem) async -> [String]
func compactSummary(for item: SystemNotificationItem) async -> String?
```

Generate at most three replies and one summary. Deterministic categories win. Cancel on primary change; never log or persist input/output.

- [ ] **Step 3: Feed enrichment into the notification manager**

Enrich only the current primary. Failure leaves app icon, monogram, and body intact. Clear results on resolution.

- [ ] **Step 4: Build and smoke-check degradation**

Verify Contacts granted/denied, matched/unmatched sender, intelligence available/unavailable/disabled, rapid replacement, and no persistence.

- [ ] **Step 5: Commit the enrichment slice**

```bash
git add boringNotch/managers/ContactAvatarManager.swift \
  boringNotch/managers/SmartReplyManager.swift \
  boringNotch/managers/SystemNotificationManager.swift \
  boringNotch/Info.plist \
  boringNotch/boringNotch.entitlements \
  boringNotch.xcodeproj/project.pbxproj
git commit -m "feat: enrich notifications on device"
```

---

### Task 12: Reuse Native Notch Opening for Notification Presentation

**Files:**
- Create: `boringNotch/managers/TransientNotchPresentationCoordinator.swift`
- Create: `boringNotch/components/Notch/NotificationLiveActivity.swift`
- Create: `boringNotch/components/Notch/LiveActivityStack.swift`
- Modify: `boringNotch/ContentView.swift`
- Modify: `boringNotch/enums/generic.swift`
- Modify: `boringNotch.xcodeproj/project.pbxproj`

- [ ] **Step 1: Implement restoration snapshots**

```swift
struct NotchRestorationSnapshot {
    let wasOpen: Bool
    let selectedView: NotchViews
    let openedAutomatically: Bool
    let screenUUID: String?
}

@MainActor
final class TransientNotchPresentationCoordinator: ObservableObject {
    enum Mode: Equatable {
        case idle
        case compact(SystemNotificationItem.ID)
        case expanded(SystemNotificationItem.ID)
    }

    static let shared = TransientNotchPresentationCoordinator()
    @Published private(set) var mode: Mode = .idle
    var isPresenting: Bool { mode != .idle }

    func present(_ item: SystemNotificationItem, decision: NotificationPresentationDecision, on vm: BoringViewModel)
    func expandByUser(on vm: BoringViewModel)
    func restore(on vm: BoringViewModel)
    func userDidNavigate(to view: NotchViews, on vm: BoringViewModel)
}
```

For `.autoOpen`, save and call existing `vm.open()`. For `.compact`, keep closed. Call `vm.close()` only when automatically opened. User navigation cancels restoration.

- [ ] **Step 2: Build the compact notification row inside the closed notch**

Show app identity, one text line, OTP when present, and copy/open hint. Fit the existing closed width, clip to `currentNotchShape`, and create no window, popover, or outside overlay.

- [ ] **Step 3: Build expanded notification content**

Show app/avatar, title, body, OTP, safe actions, reply field, suggestions, result status, dismiss, and stack. Escape dismisses; Return submits nonempty reply. Make the window key only while replying and restore accessory behavior afterward.

- [ ] **Step 4: Integrate ContentView branches**

Place notifications ahead of productivity/music compact content but behind system HUD. Expanded content replaces normal tab content inside the existing open container. Do not change bounds beyond `vm.open()` dimensions. Hide media progress while presenting.

- [ ] **Step 5: Honor Reduce Motion and accessibility**

Use reduced animation when requested. Add logical VoiceOver grouping, button labels, keyboard order, and semantic contrast.

- [ ] **Step 6: Build and visually verify the approved flow**

```text
normal compact content
→ notification compact content inside closed notch
→ existing native notch open animation when policy allows
→ expanded notification content inside notch
→ previous tab/content restored
→ native close animation only if automatically opened
```

Verify `Never`, compact click-to-open, and zero drawing outside the box.

- [ ] **Step 7: Commit the presentation slice**

```bash
git add boringNotch/managers/TransientNotchPresentationCoordinator.swift \
  boringNotch/components/Notch/NotificationLiveActivity.swift \
  boringNotch/components/Notch/LiveActivityStack.swift \
  boringNotch/ContentView.swift \
  boringNotch/enums/generic.swift \
  boringNotch.xcodeproj/project.pbxproj
git commit -m "feat: present notifications inside native notch flow"
```

---

### Task 13: Add Notification Setup, Category Matrix, and Focus Status UI

**Files:**
- Create: `boringNotch/components/Settings/NotificationSettingsView.swift`
- Modify: `boringNotch/components/Settings/SettingsView.swift`
- Modify: `boringNotch/boringNotchApp.swift`
- Modify: `boringNotch.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add the Notifications destination**

Add a sidebar row and render `NotificationSettingsView` inside the existing resizable `NavigationSplitView`.

- [ ] **Step 2: Implement explicit setup**

The disabled state shows `Set Up Notifications…`, explains Accessibility capture, then invokes:

```swift
let granted = await XPCHelperClient.shared.ensureAccessibilityAuthorization(promptIfNeeded: true)
```

Enable and start only after success. Denial leaves off with inline `Open Accessibility Settings`.

- [ ] **Step 3: Add app allowlist and category controls**

Render known apps with icons/toggles. Each category has `Show in notch` and `Never`/`Only outside Focus`/`Always`. Add `Restore Recommended Defaults`.

- [ ] **Step 4: Add Focus controls**

Provide `Allow Focus status`, show authorization and effective category override, explain System Settings ownership, and add `Open Focus Settings`. Never guess a Focus name.

- [ ] **Step 5: Add separate Contacts and intelligence controls**

Request Contacts only when enabled. Disable intelligence when unavailable and show reason inline. Disabling either clears in-memory data.

- [ ] **Step 6: Build and smoke-check permissions**

Check Accessibility denied/granted/revoked, Focus denied/granted, Contacts denied/granted, intelligence unavailable/available, allowlist changes, policy changes, and master cleanup.

- [ ] **Step 7: Commit the Settings slice**

```bash
git add boringNotch/components/Settings/NotificationSettingsView.swift \
  boringNotch/components/Settings/SettingsView.swift \
  boringNotch/boringNotchApp.swift \
  boringNotch.xcodeproj/project.pbxproj
git commit -m "feat: configure notification and focus behavior"
```

---

### Task 14: Resolve Cross-Feature Activity Precedence and Lifecycle

**Files:**
- Modify: `boringNotch/ContentView.swift`
- Modify: `boringNotch/BoringViewCoordinator.swift`
- Modify: `boringNotch/boringNotchApp.swift`
- Modify: `boringNotch/managers/SystemNotificationManager.swift`
- Modify: `boringNotch/managers/TransientNotchPresentationCoordinator.swift`

- [ ] **Step 1: Centralize final closed-notch precedence**

```text
system HUD
notification transient content
music plus compatible productivity indicators
Pomodoro/calendar/Caffeine without music
existing fallback face/idle content
```

Refactor only relevant predicates. Keep existing productivity width calculations; add notifications as a mutually exclusive branch.

- [ ] **Step 2: Handle multi-display ownership**

Present on preferred/current window only. Store screen UUID in the snapshot and restore the same `BoringViewModel`. Clicking another notch dismisses the transient item before navigation.

- [ ] **Step 3: Close lifecycle leaks**

On lock, termination, disable, helper invalidation, or Accessibility revocation: cancel tasks, release banners, stop watcher, clear transient data, restore notch without stealing focus, and leave unrelated managers under existing rules.

- [ ] **Step 4: Build and perform cross-feature matrix**

Exercise notifications over music, calendar, Pomodoro, Caffeine, Clipboard, Shelf, HUD, compact player, and media progress. Verify restoration and no stuck-open state.

- [ ] **Step 5: Commit integration**

```bash
git add boringNotch/ContentView.swift \
  boringNotch/BoringViewCoordinator.swift \
  boringNotch/boringNotchApp.swift \
  boringNotch/managers/SystemNotificationManager.swift \
  boringNotch/managers/TransientNotchPresentationCoordinator.swift
git commit -m "fix: resolve transient notch activity precedence"
```

---

### Task 15: Final Build, Privacy Audit, and Local Installation

**Files:**
- Review: all files changed since `4916eb92`
- Modify if required: only files with verified integration defects

- [ ] **Step 1: Run hygiene checks**

```bash
git diff --check 4916eb92..HEAD
git diff --stat 4916eb92..HEAD
rg -n "TO[D]O|TB[D]|[P]LACEHOLDER|print\(.*body|NSLog\(.*body" boringNotch BoringNotchXPCHelper
```

Expected: no whitespace errors, unfinished markers added by this plan, or notification-body logging.

- [ ] **Step 2: Run a clean Release build**

```bash
xcodebuild -quiet \
  -project boringNotch.xcodeproj \
  -scheme boringNotch \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/BoringNotchDerivedData-next-release \
  -clonedSourcePackagesDirPath /tmp/BoringNotchSourcePackages-next \
  CODE_SIGN_IDENTITY=- \
  ENABLE_HARDENED_RUNTIME=NO build
```

Expected app: `/tmp/BoringNotchDerivedData-next-release/Build/Products/Release/boringNotch.app`.

- [ ] **Step 3: Audit the bundle**

```bash
codesign -dv --verbose=4 /tmp/BoringNotchDerivedData-next-release/Build/Products/Release/boringNotch.app
plutil -p /tmp/BoringNotchDerivedData-next-release/Build/Products/Release/boringNotch.app/Contents/Info.plist
find /tmp/BoringNotchDerivedData-next-release/Build/Products/Release/boringNotch.app -maxdepth 4 -type f | sort
```

Expected: arm64 Release app, ad hoc identity, embedded helper, Contacts text, no debug notification window, and no generated notification files.

- [ ] **Step 4: Install after resolving the exact target**

Verify source bundle and current `/Applications/boringNotch.app`, preserve a timestamped backup under `/tmp`, replace the app bundle, and open it. Do not recursively delete a broader directory.

- [ ] **Step 5: Perform final acceptance**

Confirm existing productivity features, conversion outputs, meeting join, opt-in media features, output routing, notch-contained notifications, per-category policies, two Focus Filter policies, OTP/queue/avatar/actions/replies, and no history after restart.

- [ ] **Step 6: Commit verified corrections only**

If acceptance required corrections, stage only those files and run:

```bash
git commit -m "fix: polish next feature integrations"
```

If no correction was required, keep the existing task commits.

---

## Completion Criteria

- Debug and Release builds succeed.
- No selected PR is merged or cherry-picked wholesale.
- Notification contents remain memory-only.
- No notification UI exists outside the current notch shape.
- Existing `BoringViewModel.open()` and `close()` drive automatic expansion/restoration.
- Per-category policies and macOS Focus Filters determine automatic opening.
- Every held system banner is released on all termination paths.
- Existing Shelf, Calendar, media, Clipboard, Pomodoro, and Caffeine behavior remains available.
- The locally installed app passes the acceptance checks.
