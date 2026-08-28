# Expanded Notification Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Center the visible expanded-notification content and balance its lateral clearances without changing panel sizing or notification behavior.

**Architecture:** Keep `NotificationExpandedView` as the single owner of expanded notification layout. In automatic compact presentation, size the avatar/content `HStack` from its intrinsic width before centering it in the available panel; keep the dismiss control in an independent overlay whose inset matches the content inset.

**Tech Stack:** Swift, SwiftUI, macOS, Xcode

---

### Task 1: Center the visible notification group

**Files:**
- Modify: `boringNotch/components/Notch/NotificationLiveActivity.swift:180-245`

- [ ] **Step 1: Add the compact text-column limit**

Add a focused layout value next to `contentInsets`:

```swift
private var contentColumnMaxWidth: CGFloat {
    compactPresentation ? 260 : 430
}
```

- [ ] **Step 2: Make short automatic content intrinsic before centering**

Use the new maximum for the text/action column, then apply intrinsic horizontal sizing to the complete `HStack` only during automatic compact presentation:

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
.fixedSize(horizontal: compactPresentation, vertical: false)
.padding(contentInsets)
.frame(maxWidth: .infinity, alignment: .center)
```

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

Inject a short FaceTime-style call notification, open it automatically, and capture the installed app window.

Expected: the avatar/text/actions group is visually centered, the left and right clearances look balanced, the dismiss button remains independent, and no controls overlap.

- [ ] **Step 3: Commit and publish**

Run:

```bash
git add boringNotch/components/Notch/NotificationLiveActivity.swift docs/superpowers/plans/2026-08-28-expanded-notification-alignment.md
git commit -m "fix: center expanded notification content"
git push origin main
```

Expected: `main` and `origin/main` resolve to the same commit. The local untracked `.superpowers/` directory remains excluded.
