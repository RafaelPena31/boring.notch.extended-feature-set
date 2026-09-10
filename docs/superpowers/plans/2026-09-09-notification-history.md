# Grouped Notification History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver option B: session-only notification history grouped by application, fully readable inside the same notch, with bookmarking, removal/undo and source opening.

**Architecture:** Keep value-only snapshots in a dedicated observable store fed by the existing capture acceptance path. Keep history navigation and panel geometry separate from live-notification presentation, so reading history neither retains AX objects nor replaces live queue ownership. Reuse source identity, icons and policy decisions.

**Tech Stack:** Swift, SwiftUI, AppKit, Combine, Defaults and the existing XPC notification helper; no new dependencies.

---

## Constraints and Baseline

- Approved specification: `docs/superpowers/specs/2026-09-09-notification-history-design.md`.
- Start from the current local checkout of the fork's `main`; preserve unrelated files. The user wants the established local build/install workflow, not another checkout/install source.
- The user explicitly opted out of TDD and new test infrastructure. Implement first, review, compile and exercise the native UI. Do not introduce a test target for this feature.
- Every app build/install must use `./scripts/install-local.sh`. Never invoke a separate build/copy/signing workflow. Never expose `.local-signing.env` or commit `.superpowers/`.
- Implement this feature only. Clipboard search/favorites and favorite actions follow afterward.
- The existing panel canvas is 640 × 210 points, with a 190-point normal open silhouette. Merely increasing a SwiftUI child height clips the history: both the native panel and root canvas must accommodate the history mode.

## File Map

Create a cohesive `boringNotch/components/NotificationHistory/` folder containing:

- `NotificationHistoryItem.swift`: text/source snapshot, display projection and grouping value.
- `NotificationHistoryStore.swift`: acceptance/update, retention, filtering, deletion and undo.
- `NotificationHistoryView.swift`: grouped list, detail, independent controls and intrinsic-height reporting.
- `NotificationHistoryPanelHost.swift`: scoped resizing/key ownership of the existing NSPanel, with restoration.

Modify:

- `boringNotch.xcodeproj/project.pbxproj`: register the new folder with the app target.
- `boringNotch/managers/SystemNotificationManager.swift`: feed history and open historical sources without dismissing an unrelated live notification.
- `boringNotch/enums/generic.swift`, `boringNotch/BoringViewCoordinator.swift`: history navigation and availability.
- `boringNotch/components/Tabs/TabSelectionView.swift`, `TabButton.swift`: accessible entry with compact hit targets that fit the camera-safe wing.
- `boringNotch/components/Notch/NotificationLiveActivity.swift`: History entry and reusable source icon visibility.
- `boringNotch/components/Notch/BoringNotchSkyLightWindow.swift`: independent history keyboard ownership without disturbing reply focus.
- `boringNotch/ContentView.swift`, `boringNotch/models/BoringViewModel.swift`, `boringNotch/boringNotchApp.swift`: route manual access and resize/restore the current panel.
- `boringNotch/components/Settings/NotificationSettingsView.swift`, `docs/notifications.md`: retention/privacy guidance and settings access.

### Task 1: Value Snapshots and Bounded Store

- [x] **Add the snapshot and group types.** Keep no AX references, native actions, images or persistence conformance. Use this model in `NotificationHistoryItem.swift`:

```swift
import Foundation

struct NotificationHistoryItem: Identifiable, Equatable {
    let id: String
    let receivedAt: Date
    var appName: String?
    var bundleID: String?
    var title: String?
    var subtitle: String?
    var body: String?
    var category: SystemNotificationCategory
    var isSaved = false

    init(_ notification: SystemNotification) {
        id = notification.id
        receivedAt = notification.receivedAt
        appName = notification.appName
        bundleID = notification.bundleID
        title = notification.title
        subtitle = notification.subtitle
        body = notification.body
        category = notification.category
    }

    var sourceKey: String {
        NotificationSourceApp.sourceKey(bundleID: bundleID, appName: appName)
            ?? "unknown-source"
    }

    var sourceName: String { appName ?? bundleID ?? "Unknown app" }

    var displayNotification: SystemNotification {
        SystemNotification(
            id: id, appName: appName, bundleID: bundleID, title: title,
            subtitle: subtitle, body: body, actions: [], receivedAt: receivedAt,
            category: category, isLive: false
        )
    }

    mutating func update(from notification: SystemNotification) {
        appName = notification.appName ?? appName
        bundleID = notification.bundleID ?? bundleID
        title = notification.title ?? title
        subtitle = notification.subtitle ?? subtitle
        body = notification.body ?? body
        category = notification.category
    }
}

struct NotificationHistoryGroup: Identifiable {
    let id: String
    let name: String
    let items: [NotificationHistoryItem]
}
```

- [x] **Implement the memory store in `NotificationHistoryStore.swift`.** Keep original arrival times, update without reordering, and share one 200-record limit across Recent and Saved:

```swift
import Combine
import Defaults
import Foundation

@MainActor
final class NotificationHistoryStore: ObservableObject {
    static let shared = NotificationHistoryStore()
    static let capacity = 200
    @Published private(set) var items: [NotificationHistoryItem] = []
    @Published private(set) var undoItems: [NotificationHistoryItem] = []
    private var subscriptions = Set<AnyCancellable>()

    private init() {
        Publishers.Merge3(
            Defaults.publisher(.notificationsEnabled).map { _ in () },
            Defaults.publisher(.notificationIgnoredSources).map { _ in () },
            Defaults.publisher(.notificationCategoryPreferences).map { _ in () }
        )
        .sink { [weak self] in
            Task { @MainActor in self?.applyVisibility() }
        }
        .store(in: &subscriptions)
    }

    func item(id: String) -> NotificationHistoryItem? {
        items.first { $0.id == id }
    }

    func record(_ notification: SystemNotification, updateOnly: Bool) {
        guard NotificationPolicyManager.decision(for: notification).shouldShow else {
            items.removeAll { $0.id == notification.id }
            undoItems.removeAll { $0.id == notification.id }
            return
        }
        if let index = items.firstIndex(where: { $0.id == notification.id }) {
            items[index].update(from: notification)
        } else if !updateOnly {
            items.insert(NotificationHistoryItem(notification), at: 0)
            items = Array(items.prefix(Self.capacity))
        }
    }

    func toggleSaved(id: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isSaved.toggle()
    }

    func remove(id: String) {
        guard let item = item(id: id) else { return }
        undoItems = [item]
        items.removeAll { $0.id == id }
    }

    func clear() {
        guard !items.isEmpty else { return }
        undoItems = items
        items.removeAll()
    }

    func undo() {
        let existing = Set(items.map(\.id))
        let restored = undoItems.filter {
            !existing.contains($0.id)
                && NotificationPolicyManager.decision(for: $0.displayNotification).shouldShow
        }
        items = Array((items + restored).sorted { $0.receivedAt > $1.receivedAt }
            .prefix(Self.capacity))
        undoItems.removeAll()
    }

    func reset() {
        items.removeAll()
        undoItems.removeAll()
    }

    func applyVisibility() {
        guard Defaults[.notificationsEnabled] else { reset(); return }
        items.removeAll { !NotificationPolicyManager.decision(for: $0.displayNotification).shouldShow }
        undoItems.removeAll { !NotificationPolicyManager.decision(for: $0.displayNotification).shouldShow }
    }

    func groups(savedOnly: Bool, source: String?) -> [NotificationHistoryGroup] {
        let visible = items.filter {
            (!savedOnly || $0.isSaved) && (source == nil || source == $0.sourceKey)
        }
        var seen = Set<String>()
        return visible.compactMap { item in
            guard seen.insert(item.sourceKey).inserted else { return nil }
            return NotificationHistoryGroup(
                id: item.sourceKey, name: item.sourceName,
                items: visible.filter { $0.sourceKey == item.sourceKey }
            )
        }
    }
}
```

- [x] **Register the folder once in Xcode.** Follow the existing Clipboard synchronized-folder pattern, not the XPC helper target. Add this unused ID to `PBXFileSystemSynchronizedRootGroup`, the `components` group's children, and the `boringNotch` target's `fileSystemSynchronizedGroups`:

```text
AA0900010000000000000001 /* NotificationHistory */ = {
    isa = PBXFileSystemSynchronizedRootGroup;
    explicitFileTypes = {};
    explicitFolders = ();
    path = NotificationHistory;
    sourceTree = "<group>";
};
```

Use `AA0900010000000000000001` in all three locations. Verify it is unused with `rg 'AA0900010000000000000001' boringNotch.xcodeproj/project.pbxproj` before insertion.

### Task 2: Connect Capture Without Extending Live Actions

**File:** `boringNotch/managers/SystemNotificationManager.swift`.

- [x] **Use historical text as a fallback when reconstructing an update.** After resolving the active/queued `existing`, add a history lookup. Preserve metadata and timestamp through the snapshot type, not a new arrival. The parser's title/subtitle/body fallback becomes:

```swift
let history = NotificationHistoryStore.shared
let historical = history.item(id: token)
let title = value("title") ?? existing?.title ?? historical?.title
let subtitle = value("subtitle") ?? existing?.subtitle ?? historical?.subtitle
let body = value("body") ?? existing?.body ?? historical?.body
```

Resolve bundle ID and app name from the historical item too when an update omits them; move that lookup before classification/source recording:

```swift
let historical = NotificationHistoryStore.shared.item(id: token)
let bundleID = value("bundleID") ?? historical?.bundleID
let appName = value("appName") ?? historical?.appName
```

Use a single `historical` declaration in the final method.

- [x] **Feed snapshots at the three acceptance branches.** Existing active/queued branches call `record(notification, updateOnly: true)` after reconstruction, including when visibility changed so stored content is pruned. For a historical-only late update, record with `updateOnly: true` and return without holding or enqueueing it. For a genuinely new accepted nonduplicate banner, call `record(notification, updateOnly: false)` immediately before the existing `holdNotification` call:

```swift
// After handling matching active/queued entries, before accepting a new one:
if payload["isUpdate"] == "true" {
    history.record(notification, updateOnly: true)
    return
}
guard !isDuplicate(notification), decision.shouldShow else { return }
history.record(notification, updateOnly: false)
notification.isHeld = true
XPCHelperClient.shared.holdNotification(token: notification.id)
```

Do not use unconditional insertion in the active/queued update paths: deleting an item from history while its native banner is alive must not recreate it on enrichment. Keep the existing short-window duplicate check and live queue priorities.

- [x] **Clear session data only at the approved boundaries.** Add `NotificationHistoryStore.shared.reset()` to `stop()` (used on disable/termination). Do not add it to `dismissActive`, `markExpired`, `handleHelperDisconnect`, or the shared live-queue cleanup method.

- [x] **Add a history-only open method.** It must not call `open(_:)`, which dismisses the active item, and must not send a stale history token to native action execution:

```swift
func openHistoricalSource(_ item: NotificationHistoryItem) async -> Bool {
    let live = ([activeNotification].compactMap { $0 } + queued)
        .first { $0.id == item.id && $0.isLive }
    if let live,
       await XPCHelperClient.shared.openNotification(token: live.id) { return true }
    guard let bundleID = item.bundleID,
          let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    else { return false }
    return (try? await NSWorkspace.shared.openApplication(at: url, configuration: .init())) != nil
}
```

### Task 3: Grouped Reading View

**Files:** `NotificationHistoryView.swift`; existing `NotificationLiveActivity.swift`.

- [x] **Expose only the reusable icon.** Change `private struct NotificationSourceIcon` to `struct NotificationSourceIcon`; leave live action, avatar and dismiss ownership untouched.

- [x] **Create the history view with stable identity.** Use a non-lazy bounded VStack for reliable intrinsic measurement at 200 records, a single vertical ScrollView, and no `.id(items)`/`.id(activeNotification)` reset. The view's complete state contract is:

```swift
@ObservedObject private var store = NotificationHistoryStore.shared
@EnvironmentObject private var vm: BoringViewModel
@State private var savedOnly = false
@State private var source: String?
@State private var expanded = Set<String>()
@State private var didSelectInitialGroup = false
@State private var detailID: String?
@State private var feedback: String?
@State private var measuredHeight: CGFloat = 0
@State private var chromeHeight: CGFloat = 90
let maximumHeight: CGFloat
let onHeightChange: (CGFloat) -> Void

private var groups: [NotificationHistoryGroup] {
    store.groups(savedOnly: savedOnly, source: source)
}

private func toggleGroup(_ id: String) {
    if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
}

private func selectInitialGroup() {
    guard !didSelectInitialGroup, let first = groups.first else { return }
    expanded.insert(first.id)
    didSelectInitialGroup = true
}

private func openSource(_ item: NotificationHistoryItem) {
    Task { @MainActor in
        let opened = await SystemNotificationManager.shared.openHistoricalSource(item)
        if !opened { feedback = "Could not open \(item.sourceName)" }
    }
}
```

Import `SwiftUI`. Add `selectInitialGroup()` on appear and after the first group becomes available. Subsequent arrivals must not change `expanded`, `detailID`, or list identity. If filtering/removal hides the selected detail, return to the list; if an app filter no longer exists, reset it to All apps.

- [x] **Implement independent content and utility controls.** Reuse this complete row builder inside the grouped view; use the same row in detail with a separate Back button, without nesting one button inside another:

```swift
private func historyRow(_ item: NotificationHistoryItem) -> some View {
    HStack(alignment: .top, spacing: 10) {
        NotificationSourceIcon(notification: item.displayNotification, size: 28)
        VStack(alignment: .leading, spacing: 6) {
            Button { openSource(item) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title ?? item.sourceName).font(.headline)
                    Text(item.receivedAt, style: .relative)
                        .font(.caption).foregroundStyle(.secondary)
                    if let subtitle = item.displayNotification.secondaryText {
                        Text(subtitle).font(.subheadline)
                    }
                    Text(item.displayNotification.previewText).font(.body)
                }
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Open the source app")
            HStack {
                Button("Read") { detailID = item.id; feedback = nil }
                Button(item.isSaved ? "Saved" : "Save for later") {
                    store.toggleSaved(id: item.id)
                }
                .accessibilityValue(item.isSaved ? "Saved" : "Not saved")
            }
            .controlSize(.small)
        }
        Button { store.remove(id: item.id) } label: {
            Image(systemName: "xmark").frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove notification from history")
    }
}
```

- [x] **Compose the controls and grouped scroller.** Implement the view body with these builders; keep 8-point section spacing and symmetric 12-point internal horizontal insets. Display no reply or call controls:

```swift
private var filters: some View {
    HStack {
        Picker("Notifications", selection: $savedOnly) {
            Text("Recent").tag(false)
            Text("Saved for later").tag(true)
        }
        .pickerStyle(.segmented)
        Picker("App", selection: $source) {
            Text("All apps").tag(Optional<String>.none)
            ForEach(store.groups(savedOnly: false, source: nil)) { group in
                Text(group.name).tag(Optional(group.id))
            }
        }
        .labelsHidden()
    }
}

private var historyContents: some View {
    VStack(alignment: .leading, spacing: 8) {
        if let detailID, let item = store.item(id: detailID) {
            Button("Back to history") { self.detailID = nil; feedback = nil }
            historyRow(item)
        } else if groups.isEmpty {
            Text(savedOnly ? "No notifications saved for later." : "No notifications here.")
                .foregroundStyle(.secondary).padding(.vertical, 28)
        } else {
            ForEach(groups) { group in
                Button { toggleGroup(group.id) } label: {
                    HStack {
                        if let first = group.items.first {
                            NotificationSourceIcon(notification: first.displayNotification, size: 24)
                        }
                        Text(group.name)
                        Spacer()
                        Text("\(group.items.count)").foregroundStyle(.secondary)
                        Image(systemName: expanded.contains(group.id) ? "chevron.down" : "chevron.right")
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(expanded.contains(group.id) ? "Expanded" : "Collapsed")
                if expanded.contains(group.id) {
                    ForEach(group.items) { item in
                        historyRow(item)
                        Divider()
                    }
                }
            }
        }
    }
}

private struct HistoryHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct HistoryChromeHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value += nextValue() }
}

private var chromeMeasurement: some View {
    GeometryReader { proxy in
        Color.clear.preference(key: HistoryChromeHeightKey.self, value: proxy.size.height)
    }
}

var body: some View {
    VStack(alignment: .leading, spacing: 8) {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Notifications").font(.headline)
                Text("\(store.items.count)").foregroundStyle(.secondary)
                Spacer()
                Button("Clear history") { store.clear() }.disabled(store.items.isEmpty)
            }
            if detailID == nil { filters }
        }
        .background(chromeMeasurement)
        ScrollView(.vertical) {
            historyContents
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: HistoryHeightKey.self, value: proxy.size.height)
                })
        }
        .frame(height: min(measuredHeight > 0 ? measuredHeight : 64,
                           max(44, maximumHeight - chromeHeight - 32)))
        .onPreferenceChange(HistoryHeightKey.self) { measuredHeight = $0 }
        VStack(alignment: .leading, spacing: 8) {
            if let feedback { Text(feedback).font(.caption).foregroundStyle(.orange) }
            HStack {
                Text("This session only · up to 200 notifications").font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if !store.undoItems.isEmpty { Button("Undo") { store.undo() } }
            }
        }
        .background(chromeMeasurement)
    }
    .onPreferenceChange(HistoryChromeHeightKey.self) { chromeHeight = $0 }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(GeometryReader { proxy in
        Color.clear.onChange(of: proxy.size.height, initial: true) { _, height in
            onHeightChange(height)
        }
    })
    .onAppear(perform: selectInitialGroup)
    .onChange(of: store.items) { _, _ in
        if let detailID, store.item(id: detailID) == nil { self.detailID = nil }
        if let source, !store.items.contains(where: { $0.sourceKey == source }) { self.source = nil }
        selectInitialGroup()
    }
    .onExitCommand {
        if detailID != nil { detailID = nil } else { vm.close() }
    }
}
```

The 32 points reserve two outer 8-point VStack gaps plus 16 points of vertical padding. Header/filter/footer heights are measured independently, including error feedback; the scroller receives the remainder. No text line cap or second scroll view is needed.

### Task 4: Manual Navigation and Native Panel Geometry

- [x] **Add navigation availability.** In `boringNotch/enums/generic.swift`, add `.notificationHistory` to `NotchViews`. In `BoringViewCoordinator.normalizeCurrentViewIfNeeded()`, return to `.home` when this view is selected and notifications are disabled. Observe `.notificationsEnabled` alongside the existing tab-availability publishers:

```swift
case .notificationHistory:
    if !Defaults[.notificationsEnabled] { currentView = .home }
```

```swift
Defaults.publisher(.notificationsEnabled)
    .sink { [weak self] _ in
        Task { @MainActor in self?.normalizeCurrentViewIfNeeded() }
    }
    .store(in: &tabAvailabilityCancellables)
```

Add `@Default(.notificationsEnabled) var notificationsEnabled` to `TabSelectionView`, then append `TabModel(label: "Notifications", icon: "bell.badge", view: .notificationHistory)` only when enabled. Add `.help(label)` and `.accessibilityLabel(label)` to `TabButton`.

- [x] **Make the tab wing fit.** `TabButton` currently uses 15-point horizontal padding per icon. Add a `horizontalPadding: CGFloat = 15` parameter, use it in the existing padding modifier, and pass 8 from `TabSelectionView` when `tabs.count >= 5`; retain 15 for fewer tabs. Verify all five controls fit the measured left wing without intruding on the camera; retain the existing physical exclusion rather than centering the new tab under the camera.

- [x] **Route menu and live-card access through one request.** Add the event in the existing `Notification.Name` extension in `SystemNotificationManager.swift`:

```swift
static let notificationHistoryRequested = Notification.Name("notificationHistoryRequested")
```

Use this action for the menu entry in `boringNotchApp.swift`, an accessible History button beside the expanded notification header, and the settings button:

```swift
Button("Notification History", systemImage: "clock.arrow.circlepath") {
    NotificationCenter.default.post(name: .notificationHistoryRequested, object: nil)
}
```

Disable the menu/settings entry while notifications are disabled. In `ContentView`, consume the event only on the selected display and invoke this local method:

```swift
private func openNotificationHistory() {
    guard Defaults[.notificationsEnabled],
          vm.screenUUID == nil || vm.screenUUID == coordinator.selectedScreenUUID
    else { return }
    hoverTask?.cancel()
    automaticNotificationPanelToken = nil
    notificationPresentationWasOpen = nil
    notificationPresentationView = nil
    coordinator.currentView = .notificationHistory
    if vm.notchState == .closed { doOpen() }
}
```

Selecting the history tab while already open must also clear those automatic-presentation restore flags. Do not allow an old expiry event to close or navigate away from explicitly opened history.

- [x] **Give history priority only while manually selected and open.** Add these computed properties to `ContentView` and handle the history branch before the live expanded notification in `NotchLayout`:

```swift
private var historyActive: Bool {
    vm.notchState == .open && coordinator.currentView == .notificationHistory
}

private var historyMaximumHeight: CGFloat {
    min(390, max(190, (vm.currentScreen?.frame.height ?? 900) - shadowPadding))
}

private var historyHeaderHeight: CGFloat {
    max(24, vm.effectiveClosedNotchHeight, vm.physicalNotchExclusionHeight)
}

@State private var historyPanelHeight: CGFloat = 190

private func updateHistoryHeight(_ contentHeight: CGFloat) {
    let total = min(historyMaximumHeight, historyHeaderHeight + 8 + contentHeight + 12)
    historyPanelHeight = total
    if historyActive { vm.setOpenContentHeight(total) }
}
```

Pass `historyMaximumHeight - historyHeaderHeight - 8 - 12` as `maximumHeight` and `updateHistoryHeight` as `onHeightChange`. Use `BoringHeader` with the camera-safe height for history, not the live notification's blank spacer. Add `.notificationHistory` to the remaining exhaustive view switch without altering Home/Shelf/Clipboard/Pomodoro.

In `BoringViewModel`, add:

```swift
func setOpenContentHeight(_ height: CGFloat) {
    guard notchState == .open else { return }
    notchSize = CGSize(width: openNotchSize.width, height: height)
}
```

Use `historyPanelHeight` for `openLayoutHeight` only in history mode, and set the root canvas maxHeight to `historyPanelHeight + shadowPadding` there, otherwise `windowSize.height`. When leaving history, restore `vm.setOpenContentHeight(openNotchSize.height)`. Reset `.notificationHistory` to `.home` when closing the notch, even when `openLastTabByDefault` is enabled: an automatic live banner must not reopen the history tab.

- [x] **Separate keyboard ownership from live reply focus.** In `BoringNotchSkyLightWindow.swift`, replace the existing text-input flag's observer and `canBecomeKey` implementation with this shared computation. Keep `canBecomeMain` unchanged:

```swift
var wantsKeyForTextInput = false { didSet { updateKeyboardOwnership() } }
var wantsKeyForHistory = false { didSet { updateKeyboardOwnership() } }

private func updateKeyboardOwnership() {
    if wantsKeyForTextInput || wantsKeyForHistory {
        if !isKeyWindow { makeKey() }
    } else if isKeyWindow {
        resignKey()
    }
}

override var canBecomeKey: Bool { wantsKeyForTextInput || wantsKeyForHistory }
```

- [x] **Resize the existing window, not a second panel.** Implement `NotificationHistoryPanelHost.swift` as a zero-sized view mounted on ContentView's persistent root background. It must stay mounted through history exit so it can restore the native frame:

```swift
import AppKit
import SwiftUI

struct NotificationHistoryPanelHost: NSViewRepresentable {
    let height: CGFloat?

    final class HostView: NSView {
        var requestedHeight: CGFloat?
        private var normalHeight: CGFloat?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
        }

        func apply() {
            guard let panel = window as? BoringNotchSkyLightWindow else { return }
            if let requestedHeight {
                if normalHeight == nil {
                    normalHeight = panel.frame.height
                }
                resize(panel, height: requestedHeight)
                panel.wantsKeyForHistory = true
            } else if let original = normalHeight {
                resize(panel, height: original)
                panel.wantsKeyForHistory = false
                normalHeight = nil
            }
        }

        func restore() {
            requestedHeight = nil
            apply()
        }

        private func resize(_ panel: NSWindow, height: CGFloat) {
            var frame = panel.frame
            guard abs(frame.height - height) > 0.5 else { return }
            frame.origin.y = frame.maxY - height
            frame.size.height = height
            panel.setFrame(frame, display: true)
        }
    }

    func makeNSView(context: Context) -> HostView { HostView() }

    func updateNSView(_ view: HostView, context: Context) {
        view.requestedHeight = height
        DispatchQueue.main.async { [weak view] in view?.apply() }
    }

    static func dismantleNSView(_ view: HostView, coordinator: ()) { view.restore() }
}
```

Attach with `height: historyActive ? historyPanelHeight + shadowPadding : nil` and `.frame(width: 0, height: 0)`. Preserve top anchoring and normal width, level, signing, sharing policy and panel instance. On display changes, recompute the history maximum and camera reservation before updating geometry. The host releases only `wantsKeyForHistory`; it never writes the reply view's `wantsKeyForTextInput` flag.

- [x] **Prevent live events/gestures from hijacking browsing.** Add `guard !historyActive else { return }` at the start of `handleAutomaticNotificationOpening()` and `restoreAfterAutomaticNotification()`. Gate the parent content-open tap and up/down `panGesture` modifiers with `!historyActive`; retain the existing expanded-notification guard and closed swipe behavior. Guard automatic restore reactions while history is selected. Normal pointer exit still follows existing close behavior, but new captures must not trigger navigation or reconstruct the history view.

### Task 5: Privacy Copy and Native Manual Verification

- [x] **Replace obsolete settings text.** In `NotificationSettingsView.swift`, replace the footer that claims all content is discarded after presentation with:

```swift
Text("Only visible banners are mirrored. The latest 200 notifications, including Saved for later, stay in memory for this session. Quitting the app or disabling notifications clears the history. Nothing is saved to disk.")
```

Add the Notification History button from Task 4 in a Session history section with the same help text. In `docs/notifications.md`, document grouping, save-for-later as a bookmark rather than a reminder, the shared 200-item limit, manual opening, deletion/undo only affecting notch history, source-opening limitations and absence of history reply/call controls.

- [x] **Self-review source and project registration.** Run:

```bash
git diff --check
plutil -lint boringNotch.xcodeproj/project.pbxproj
rg -n 'notificationHistory|historyActive|NotificationHistory' boringNotch
```

Expected: no whitespace errors; project plist reports OK; new source files are assigned only to the app target. Check every `switch` on `NotchViews` for exhaustiveness and all privacy copy for the old discarded-after-presentation claim.

- [x] **Build/install with the sole approved script.** Run from the repository root:

```bash
./scripts/install-local.sh > /tmp/notch-history-install.log 2>&1
```

Expected: exit 0, successful app/helper signature and entitlement verification, followed by `Installed boringNotch ...`. Inspect failures in this log; fix and rerun the same script, never manually replace the app.

- [ ] **Exercise the installed app with synthetic fixtures or user-triggered real notifications.** Do not send external messages or initiate calls. If a temporary diagnostic entry is required to populate fixtures, keep it out of the committed release and remove it before the final scripted build. Check:

  1. Capture two apps and several texts; dismiss the transient card and find all accepted items grouped in history.
  2. Expand two groups, scroll a long text, Read/Back, and trigger another incoming item without losing the selected detail.
  3. Save, filter, remove, undo; clear then receive a new item and undo without losing the new arrival.
  4. Delete an item whose native banner is still alive; an AX update must not recreate it. A late update to a retained historical item may enrich text but cannot show a new live card.
  5. Clicking history content opens only its source; Save/Read/Remove never opens it. A failed open keeps the item and shows an inline error.
  6. Old call/message history has no call buttons or reply editor. Live notifications retain the prior capability behavior.
  7. Hide an app/category and confirm its history and undo records disappear. Disable/relaunch and confirm history, bookmarks and undo are empty.
  8. Verify the 200-item limit through a bounded fixture loop, including saved entries sharing the limit; do not log fixture message bodies.
  9. On physical-notch and notchless displays, inspect equal insets, all tabs outside the camera, full-text scrolling, correct hit area, and normal dimensions after exit.
  10. Verify the media progress border, live closed-card click, closed swipe-to-open, default-off automatic opening and unchanged Focus rules outside history.

### Task 6: Review, Publish and Verify Installation

- [x] **Request focused code review.** Use the requesting-code-review skill, giving the reviewer this approved spec and the diff. Ask specifically about removed-item resurrection, hidden-source undo, stale native actions, history/live priority, key ownership and camera-safe native panel resizing. Resolve important findings; rerun the script if source changed.

- [x] **Confirm the installed binary matches the scripted product.** Run:

```bash
shasum -a 256 .build/local-install/Build/Products/Release/boringNotch.app/Contents/MacOS/boringNotch /Applications/boringNotch.app/Contents/MacOS/boringNotch
```

Expected: identical hashes. Report any unverified real-banner/device interaction honestly; do not present a synthetic preview as native validation.

- [x] **Commit only feature files and publish to the fork.** Stage the exact paths in this file map, including this completed plan and the notification documentation; do not stage `.superpowers/` or local signing configuration. Use:

```bash
git diff --cached --check
git commit -m "feat: add grouped session notification history"
git push origin main
git rev-list --left-right --count HEAD...origin/main
git status --short
```

Expected: `0 0` divergence and no pending feature changes. Mark completed plan checkboxes truthfully, summarize installed behavior, then return to the separately approved next feature: clipboard search and favorites.

## Execution notes — 2026-09-09

- Feature commit `85954662` published to the fork's `main`; local and remote were synchronized after the push. Only the pre-existing `.superpowers/` folder remains untracked.
- Final installation succeeded through `./scripts/install-local.sh`; app/helper signatures and entitlements passed the script checks. Built and installed executable SHA-256: `161bd8a7d0afd2ea8056ba6f00d3d851276133dc5a9939223a660728256ab865`.
- Implemented and reviewed the store, capture integration, grouped reading view, navigation, panel restoration and privacy guidance. No test target or new dependency was added.
- Native checks used four temporary, value-only snapshots from three app identities, not real incoming banners. Confirmed multiple expanded groups, app/saved filters, Save, Remove/Undo, Clear/Undo, full-text scrolling, Read/Back, Escape detail→list→closed, source opening through Finder, and absence of reply/call actions in historical records.
- Native screenshots exposed a content-height preference being replaced by zero. Direct geometry measurement fixed the fallback-height viewport: the panel now grows to the 390-point silhouette limit and shrinks for shorter filtered content. Read starts at the top of a long detail. Closing restores the original 210-point window. Rendered outer insets are symmetric.
- Temporary sample data and numeric layout controls were removed before the delivery build. No fixture hook remains in production.
- Remaining manual coverage: real capture/late updates and arrivals during reading, hidden-source/disable transitions, runtime 200-item eviction, physical-camera confirmation on both display types, and media/Focus regression checks. Those paths received source review but are not claimed as fully runtime-verified; the comprehensive manual-verification checkbox remains open.

## Follow-up — history closes on selection

- Temporary, content-free runtime diagnostics confirmed two delayed hover closures while history was open and the physical pointer was still inside the notch. Changing the gesture branches and resizing the panel can invalidate SwiftUI's tracking region without a real pointer exit.
- Replaced the conditional gesture branches with persistent gesture modifiers that enable/disable in place. This preserves the whole notch's visual identity rather than remounting it on history selection. Disabled gestures leave child interactions enabled and reset pending native scroll callbacks.
- Hover observation also stays mounted. The delayed history exit rechecks the pointer until it actually leaves; hover entry and navigation cancel that check. Screen bounds include the upper edge so a monitor above the notch is not counted as inside.
- The shortcut's three-second preview timer no longer closes manually selected history. Live-notification expiration does not cancel history's exit handling. Escape, the close button, and normal pointer-exit dismissal remain enabled.
- Focused code review covered tracking identity, cancellation and expiry interactions. Temporary diagnostics were removed, and no notification content was logged. Post-fix physical-pointer confirmation remains a manual check.
- The canonical install script passed with the final stable-gesture/header implementation. Built and installed executable SHA-256 both equal `e323c8788ebfce5a7c96c32fe4eb4a005f80636aa9962167a433574f84f7dace`. Native menu entry opened history, and History → Home retained the same accessible header controls; concurrent user interaction interrupted the reverse-navigation check.

## Follow-up — fixed-size tab presentation

- The earlier up-to-390-point history geometry in this implementation plan is superseded by the user's fixed-size requirement. History now uses the ordinary 640 × 190-point open silhouette and the existing 640 × 210-point panel canvas.
- Removed all history-specific native panel resizing and dynamic `notchSize` updates. The AppKit host now owns only keyboard focus for Escape handling.
- Moved History into the same `currentView` switch as Home, Shelf, Clipboard and Pomodoro. Its one-row controls remain fixed while the notification list and full-text detail scroll within the remaining height.
- The canonical install script passed. Built and installed executable SHA-256 both equal `7e5cba89294f6cd7e25ec4ea4adeb25d41e002ab3a292669f432ebb07c264f31`. Native Home → History → Home switching kept the same panel height; the settled History frame contained no previous-tab content.

## Follow-up — tab animation isolation

- Removed the broad `withAnimation` transaction from tab navigation. It animated the history view's focus teardown and the replacement Home content together, producing a history-only top-to-bottom movement.
- The smooth animation is now scoped to the tab selector subtree, so the selection capsule and colors still animate while the main module changes immediately. The selector also respects the macOS Reduce Motion preference.
- Focused review found no changes to navigation, geometry, hover, gestures or keyboard behavior. The canonical install script passed, and the built and installed executable SHA-256 values both equal `106adcb53560b4d651582cd140127eba5f2cfb21002dec51032502cea1c307d0`.
- The automation session could inspect the installed process but could not synthesize the physical-notch hover needed to replay History → Home, so final motion confirmation remains a physical-pointer check.
