# Expanded Notification Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Center the visible expanded-notification content and balance its lateral clearances without changing panel sizing or notification behavior.

**Architecture:** Keep `NotificationExpandedView` as the single owner of expanded notification layout. In automatic compact presentation, use `ViewThatFits` to center intrinsic short content and fall back to a real 260-point text-column proposal for long wrapping content; keep the dismiss control in an independent overlay whose inset matches the content inset.

**Tech Stack:** Swift, SwiftUI, macOS, Xcode

---

### Task 1: Center the visible notification group

**Files:**
- Modify: `boringNotch/components/Notch/NotificationLiveActivity.swift:180-245`

- [ ] **Step 1: Add adaptive content sizing**

Add three explicit sizing modes and the compact fallback width:

```swift
private enum ContentSizing {
    case intrinsic
    case constrained
    case flexible
}

private let compactContentColumnWidth: CGFloat = 260
```

- [ ] **Step 2: Center short content and preserve long-message wrapping**

Use `ViewThatFits` to try the intrinsic group first and use a constrained fallback when that group cannot fit horizontally:

```swift
Group {
    if compactPresentation {
        ViewThatFits(in: .horizontal) {
            contentGroup(sizing: .intrinsic)
            contentGroup(sizing: .constrained)
        }
    } else {
        contentGroup(sizing: .flexible)
    }
}
.padding(contentInsets)
.frame(maxWidth: .infinity, alignment: .center)
```

Inside `contentGroup`, use intrinsic sizing without a maximum for the first candidate, an exact 260-point width for the compact fallback, and the existing flexible 430-point maximum for manual presentation. This lets `ViewThatFits` reject long single-line ideals and preserves their existing three-line wrapping in the fallback.

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
