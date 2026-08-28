# Notifications From All Apps Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow visible banners from every application by default, learn source-only metadata from captured banners, and let the user ignore or re-enable individual sources in Notifications settings.

**Architecture:** Replace the fixed app allowlist with an empty-by-default ignored-source key. Represent each source with a stable bundle-ID key and a normalized-name fallback, record only that source metadata before policy filtering, and merge the existing suggestions with observed sources in the current settings section. Keep category visibility, Focus behavior, queueing, presentation, actions, and expiry unchanged.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Defaults, macOS Accessibility/XPC, existing `scripts/install-local.sh` workflow

---

The user explicitly requested implementation-first validation without TDD for this project. Do not add or run a test suite for this change; use the repository checks, the single local installer, and real notification banners described below.

### Task 1: Define persistent source identity and invert the source policy

**Files:**
- Modify: `boringNotch/models/SystemNotification.swift`
- Modify: `boringNotch/models/Constants.swift`
- Modify: `boringNotch/managers/NotificationPolicyManager.swift`

- [ ] Replace `NotificationSourceApp` with a serializable source model that supports a missing bundle identifier and generates one stable key:

```swift
struct NotificationSourceApp: Identifiable, Hashable, Codable, Defaults.Serializable {
    let name: String
    let bundleID: String?

    var id: String { sourceKey }

    var sourceKey: String {
        if let bundleID {
            return "bundle:\(bundleID)"
        }
        return "name:\(Self.normalizedName(name))"
    }

    static func make(bundleID: String?, appName: String?) -> NotificationSourceApp? {
        let cleanBundleID = cleaned(bundleID)
        let cleanName = cleaned(appName)

        if let cleanBundleID {
            return .init(name: cleanName ?? cleanBundleID, bundleID: cleanBundleID)
        }
        guard let cleanName else { return nil }
        return .init(name: cleanName, bundleID: nil)
    }

    static func sourceKey(bundleID: String?, appName: String?) -> String? {
        make(bundleID: bundleID, appName: appName)?.sourceKey
    }

    private static func normalizedName(_ value: String) -> String {
        value
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .lowercased()
    }

    private static func cleaned(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else { return nil }
        return value
    }

    static let suggested: [NotificationSourceApp] = [
        .init(name: "Messages", bundleID: "com.apple.MobileSMS"),
        .init(name: "FaceTime", bundleID: "com.apple.FaceTime"),
        .init(name: "Mail", bundleID: "com.apple.mail"),
        .init(name: "Outlook", bundleID: "com.microsoft.Outlook"),
        .init(name: "WhatsApp", bundleID: "net.whatsapp.WhatsApp"),
        .init(name: "Telegram", bundleID: "ru.keepcoder.Telegram"),
        .init(name: "Telegram Desktop", bundleID: "org.telegram.desktop"),
        .init(name: "Discord", bundleID: "com.hnc.Discord"),
        .init(name: "Claude", bundleID: "com.anthropic.claudefordesktop")
    ]
}
```

- [ ] Keep source cleanup self-contained in `NotificationSourceApp`; do not add a project-wide `String` extension for this feature.

- [ ] Retire `notificationAllowedApps` in `Constants.swift` and add the two new defaults. Do not migrate old allowlist values:

```swift
static let notificationIgnoredSources = Key<[String]>(
    "notificationIgnoredSources",
    default: []
)
static let notificationObservedSources = Key<[NotificationSourceApp]>(
    "notificationObservedSources",
    default: []
)
```

- [ ] Replace `NotificationPolicyManager.isAllowed` so known sources are rejected only when their stable key is ignored, while unknown sources fail open:

```swift
private static func isAllowed(_ notification: SystemNotification) -> Bool {
    guard let sourceKey = NotificationSourceApp.sourceKey(
        bundleID: notification.bundleID,
        appName: notification.appName
    ) else {
        return true
    }
    return !Set(Defaults[.notificationIgnoredSources]).contains(sourceKey)
}
```

- [ ] Confirm that `decision(for:)` still evaluates the source policy before the existing category and Focus rules, with no changes to those rules.

- [ ] Run static repository checks:

```bash
git diff --check
rg -n "notificationAllowedApps" boringNotch --glob '*.swift'
```

Expected: `git diff --check` exits successfully and the `rg` command prints no matches.

- [ ] Commit this coherent policy change:

```bash
git add boringNotch/models/SystemNotification.swift boringNotch/models/Constants.swift boringNotch/managers/NotificationPolicyManager.swift
git commit -m "feat: allow notifications from every source"
```

### Task 2: Learn source metadata from every captured banner

**Files:**
- Modify: `boringNotch/managers/SystemNotificationManager.swift`

- [ ] In `receive(_:)`, read `bundleID` and `appName` once, before category classification, and pass those local values into both `category(...)` and `SystemNotification(...)`:

```swift
let bundleID = value("bundleID")
let appName = value("appName")
let actions = (value("actions") ?? "")
    .components(separatedBy: "\n")
    .filter { !$0.isEmpty }

recordSource(bundleID: bundleID, appName: appName)

let category = NotificationPolicyManager.category(
    bundleID: bundleID,
    appName: appName,
    title: value("title"),
    subtitle: value("subtitle"),
    body: value("body"),
    actions: actions
)
```

- [ ] Add a private metadata-only recorder to `SystemNotificationManager`. It must append new sources, update a changed display name for an existing key, and avoid writing Defaults when nothing changed:

```swift
private func recordSource(bundleID: String?, appName: String?) {
    guard let source = NotificationSourceApp.make(
        bundleID: bundleID,
        appName: appName
    ) else { return }

    var sources = Defaults[.notificationObservedSources]
    if let index = sources.firstIndex(where: { $0.id == source.id }) {
        guard sources[index] != source else { return }
        sources[index] = source
    } else {
        sources.append(source)
    }
    Defaults[.notificationObservedSources] = sources
}
```

- [ ] Keep `recordSource(...)` before duplicate and policy guards so an ignored source remains visible in settings and can be re-enabled later.

- [ ] Verify by inspection that only `name` and `bundleID` reach `notificationObservedSources`; never persist title, subtitle, body, actions, token, reply text, or notification content.

- [ ] Run `git diff --check` and commit:

```bash
git diff --check
git add boringNotch/managers/SystemNotificationManager.swift
git commit -m "feat: remember observed notification sources"
```

### Task 3: Show suggested and observed sources in Notifications settings

**Files:**
- Modify: `boringNotch/components/Settings/NotificationSettingsView.swift`

- [ ] Replace the allowlist property with reactive access to ignored and observed sources:

```swift
@Default(.notificationIgnoredSources) private var ignoredSources
@Default(.notificationObservedSources) private var observedSources
```

- [ ] Merge suggestions first and observed sources afterward, preserving their stored order and removing duplicate source keys:

```swift
private var configurableSources: [NotificationSourceApp] {
    var seen = Set<String>()
    return (NotificationSourceApp.suggested + observedSources).filter {
        seen.insert($0.id).inserted
    }
}
```

- [ ] Render `ForEach(configurableSources)` instead of only `suggested`. Resolve the icon only when the source has a bundle identifier:

```swift
ForEach(configurableSources) { app in
    Toggle(isOn: appBinding(app)) {
        HStack(spacing: 8) {
            if let bundleID = app.bundleID,
               let url = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: bundleID
               ) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "app")
                    .frame(width: 20, height: 20)
            }
            Text(app.name)
        }
    }
}
```

- [ ] Replace `appBinding(_ bundleID:)` with inverted ignored-list behavior. A source absent from the list is enabled by default:

```swift
private func appBinding(_ app: NotificationSourceApp) -> Binding<Bool> {
    Binding(
        get: { !ignoredSources.contains(app.sourceKey) },
        set: { enabled in
            if enabled {
                ignoredSources.removeAll { $0 == app.sourceKey }
            } else if !ignoredSources.contains(app.sourceKey) {
                ignoredSources.append(app.sourceKey)
            }
        }
    )
}
```

- [ ] Change the Apps footer to: `Notifications from every app are shown by default. Turn off an app to ignore future banners from it.`

- [ ] Change “Restore recommended notification settings” so it clears `ignoredSources` and restores category recommendations, but keeps observed source metadata:

```swift
ignoredSources = []
categoryPreferences = NotificationCategoryPreference.recommended
```

- [ ] Run source consistency checks:

```bash
git diff --check
rg -n "allowedApps|notificationAllowedApps" boringNotch --glob '*.swift'
rg -n "notificationIgnoredSources|notificationObservedSources" boringNotch --glob '*.swift'
```

Expected: no matches for either legacy allowlist name; both new defaults are used by model flow, policy, and settings.

- [ ] Commit the settings change:

```bash
git add boringNotch/components/Settings/NotificationSettingsView.swift
git commit -m "feat: manage notifications from observed apps"
```

### Task 4: Build, install, and validate real notifications

**Files:**
- No source changes expected.

- [ ] Confirm `.local-signing.env` exists and the working tree contains only the intended commits plus the pre-existing untracked `.superpowers/` directory:

```bash
test -f .local-signing.env
git status --short --branch
```

Expected: the signing-file check exits successfully; `.local-signing.env` is not shown because it is ignored.

- [ ] Build and install only through the project workflow:

```bash
./scripts/install-local.sh
```

Expected final line: `Installed boringNotch <revision> (with local changes) with the configured development team.` The existing untracked `.superpowers/` directory makes the checkout non-clean; the script must also validate the main app and XPC helper signatures and sandbox entitlements.

- [ ] In boringNotch Settings > Notifications, confirm Capture reports `Active` after installation. Do not reset Accessibility unless macOS actually reports the permission as missing.

- [ ] Trigger a banner from a source outside the original suggested list:

```bash
osascript -e 'display notification "Boring Notch source test" with title "All-app capture"'
```

Expected: the banner is mirrored in the notch, and its source subsequently appears in the Apps section.

- [ ] Turn that newly observed source off in the Apps section, run the same `osascript` command again, and confirm the macOS banner still appears while boringNotch does not mirror it.

- [ ] Turn the source back on, run the command again, and confirm boringNotch resumes mirroring it.

- [ ] Trigger one notification from an existing suggested app and confirm it remains enabled by default.

- [ ] Spot-check one category configured as `Never`, one as `Only outside Focus`, and one as `Always`; confirm the existing notch-opening behavior and Focus override behavior are unchanged.

- [ ] Quit and relaunch boringNotch, then confirm the observed source remains listed and its current ignored/enabled state persists.

- [ ] Run final repository checks and push the completed commits:

```bash
git diff --check
git status --short --branch
git log --oneline -4
git push origin main
```

Expected: no tracked changes remain, the three feature commits appear above the plan commit, and `main` is synchronized with `origin/main`. The pre-existing untracked `.superpowers/` directory may remain and must not be added.
