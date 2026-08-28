# Expanded Notification Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the expanded notification exactly equal left and right edge clearances without changing panel sizing or notification behavior.

**Architecture:** Keep `NotificationExpandedView` as the single owner of expanded notification layout. Make the avatar/content row fill the notification area and align it to the leading edge, while the dismiss control remains trailing-aligned; both consume the same horizontal `contentInsets`, so their outer clearances are equal by construction. The text column retains a compact maximum width and wraps long messages normally.

**Tech Stack:** Swift, SwiftUI, macOS, Xcode

---

### Task 1: Anchor both notification edges symmetrically

**Files:**
- Modify: `boringNotch/components/Notch/NotificationLiveActivity.swift:180-245`

- [ ] **Step 1: Keep one bounded content row**

Remove `ContentSizing`, `ViewThatFits`, and the intrinsic/constrained variants. Keep a single maximum for the text/action column:

```swift
private var contentColumnMaxWidth: CGFloat {
    compactPresentation ? 260 : 430
}
```

- [ ] **Step 2: Anchor the avatar to the leading inset**

Render one content row, retain the text-column limit for wrapping, and align the padded row to the leading edge:

```swift
HStack(alignment: .top, spacing: 14) {
    avatar

    VStack(alignment: .leading, spacing: 8) {
        header
        message
        actionArea
        if let status = notification.statusMessage {
            Text(status)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.orange)
                .transition(.opacity)
        }
    }
    .frame(maxWidth: contentColumnMaxWidth, alignment: .leading)
}
.padding(contentInsets)
.frame(maxWidth: .infinity, alignment: .leading)
```

The leading edge of `avatar` is now exactly `contentInsets.leading` from the notification area. Long content receives a bounded width proposal and keeps its existing three-line wrapping.

- [ ] **Step 3: Balance the dismiss-control inset**

Replace its fixed inset with the same effective inset used by the content:

```swift
.overlay(alignment: .topTrailing) {
    dismissButton
        .padding(.top, contentInsets.top)
        .padding(.trailing, contentInsets.trailing)
}
```

- [ ] **Step 4: Check the focused diff**

Run:

```bash
git diff --check -- boringNotch/components/Notch/NotificationLiveActivity.swift
git diff -- boringNotch/components/Notch/NotificationLiveActivity.swift
```

Expected: no whitespace errors and only the alignment-related changes above.

### Task 2: Build, install, and visually validate

**Files:**
- Verify: `scripts/install-local.sh`

- [ ] **Step 1: Build and install with the project-only workflow**

Run:

```bash
./scripts/install-local.sh
```

Expected: Release build succeeds, code-signing validation succeeds, and `/Applications/boringNotch.app` is relaunched.

- [ ] **Step 2: Validate on the installed app**

Inject short and long notifications, open each automatically, and capture the installed app window.

Expected: the clearance before the avatar equals the clearance after the dismiss button in both captures; long content wraps and no controls overlap.

- [ ] **Step 3: Commit and publish**

Run:

```bash
git add boringNotch/components/Notch/NotificationLiveActivity.swift docs/superpowers/plans/2026-08-28-expanded-notification-alignment.md
git commit -m "fix: align notification edge insets"
git push origin main
```

Expected: `main` and `origin/main` resolve to the same commit. The local untracked `.superpowers/` directory remains excluded.
