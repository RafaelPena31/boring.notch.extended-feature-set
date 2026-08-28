# Feature-Focused README Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the inherited upstream README with a concise English page that presents the implemented capabilities of Boring Notch Extended first.

**Architecture:** This is a documentation-only change. `README.md` becomes the product landing page for the fork, while `BUILDING.md` remains the single source for local signing setup and `scripts/install-local.sh` remains the sole supported build-and-install entry point.

**Tech Stack:** GitHub Flavored Markdown, local repository documentation, Git.

---

### Task 1: Replace the Upstream README

**Files:**
- Modify: `README.md`
- Reference: `BUILDING.md`
- Reference: `THIRD_PARTY_LICENSES.md`

- [ ] **Step 1: Replace `README.md` with the feature-first page**

Use the following complete content:

```markdown
<h1 align="center">Boring Notch Extended</h1>

<p align="center">
  A community fork that turns the MacBook notch into a private notification hub, productivity workspace, calendar companion, and media controller.
</p>

> [!NOTE]
> This repository is an extended fork of [Boring Notch](https://github.com/TheBoredTeam/boring.notch). It focuses on additional features integrated directly into the existing notch experience.

## Extended Features

### Notifications inside the notch

- Mirrors visible macOS notification banners from any observed app directly inside the notch.
- Classifies OTP and security codes, calls, permissions, decisions, messages, mail, and general notifications.
- Lets you enable or disable individual apps and notification categories.
- Controls automatic notch opening per category with **Never**, **Only outside Focus**, and **Always** policies.
- Supports macOS Focus status and per-Focus category filters.
- Keeps multiple notifications in a temporary stack without creating a separate floating window.
- Exposes available notification actions, one-click OTP copying, contact avatars, and supported reply flows.
- Can suggest short replies using on-device Apple Intelligence when the Mac supports it and the feature is enabled.

Notification content, reply drafts, contact avatars, and generated suggestions remain in memory and are discarded after presentation.

### Private clipboard history

- Stores a local history of copied text, links, images, and file references.
- Recopy an item, open a link, reveal a file in Finder, remove individual entries, or clear the complete history.
- Monitoring is optional and can be disabled at any time.

### Calendar Live Activity and meeting actions

- Shows the next relevant calendar event around the closed notch.
- Adds direct meeting actions to calendar events and the Calendar Live Activity.
- Opens supported Zoom, Google Meet, Microsoft Teams, Webex, Whereby, and Jitsi meetings in their native apps when available, with browser fallback.

### Pomodoro in the notch

- Runs focus, short-break, and long-break sessions without leaving the notch.
- Supports start, pause, resume, skip, and reset actions.
- Keeps the active timer visible in the closed-notch presentation.
- Includes configurable durations, cycle behavior, sounds, and notifications.

### Keep Awake / Caffeine

- Prevents display or system sleep through native macOS power assertions.
- Provides quick controls in the notch and complete settings in the app.
- Supports low-battery protection and a safety timeout.

### Enhanced media experience

- Draws optional playback progress around the closed-notch contour.
- Offers a compact expanded-player layout.
- Switches the current audio output without leaving the player.
- Retains the original artwork, visualizer, transport controls, seeking, shuffle, and media-app integration.

### Shelf image conversion

- Converts images directly from the Shelf to supported PNG, JPEG, HEIC, and WebP formats.
- Keeps the source file and adds the converted result as a new Shelf item.
- Avoids overwriting existing files by generating a unique output name.

## Core Experience

The extended feature set builds on the original Boring Notch experience, including:

- Music controls, artwork, visualizer, and customizable gestures.
- Calendar and Reminders integration.
- File Shelf with drag and drop and AirDrop support.
- Native-style volume, brightness, and keyboard-backlight HUD replacements.
- Battery status, charging activity, and mirror mode.
- Notch sizing, multi-display support, and appearance customization.

## Privacy and Permissions

Features request only the permissions they need:

- **Accessibility:** observes visible Notification Center banners and invokes actions selected by the user.
- **Calendar:** reads events for calendar views, Live Activity, and meeting actions.
- **Contacts:** optionally resolves contact photos for notification avatars.
- **Focus status:** optionally adjusts automatic notification opening while a Focus is active.
- **Apple Intelligence:** optionally generates on-device reply suggestions when supported.

Notification contents are not read from Notification Center databases and are not persisted to disk. Clipboard history is local and can be disabled or cleared from Settings.

## Requirements

- macOS 15.6 or later.
- Xcode 26 or later.
- A local Apple Development Team configured in Xcode.

## Build and Install Locally

This fork uses one supported local build-and-install process:

```sh
./scripts/install-local.sh
```

Before running it, follow [BUILDING.md](BUILDING.md) to select your Xcode Team and create the ignored `.local-signing.env` file. Personal Team information remains local and must not be committed.

## Credits

Boring Notch Extended is based on the open-source [Boring Notch](https://github.com/TheBoredTeam/boring.notch) project by TheBoredTeam and its contributors.

See [Third-Party Licenses](THIRD_PARTY_LICENSES.md) for dependency licenses and attributions.
```

- [ ] **Step 2: Validate the documentation-only diff**

Run:

```bash
git diff --check
test -f BUILDING.md
test -f THIRD_PARTY_LICENSES.md
test -x scripts/install-local.sh
```

Expected: every command exits with status `0` and produces no error output.

- [ ] **Step 3: Confirm that stale upstream distribution content is gone**

Run:

```bash
rg -n "releases/latest|brew install|discord.gg|ko-fi|Star History|Roadmap|under consideration" README.md
```

Expected: exit status `1` because none of these strings remain.

- [ ] **Step 4: Confirm all implemented feature groups are represented**

Run:

```bash
rg -n "Notifications inside the notch|Private clipboard history|Calendar Live Activity|Pomodoro in the notch|Keep Awake / Caffeine|Enhanced media experience|Shelf image conversion" README.md
```

Expected: seven matching section headings.

- [ ] **Step 5: Review the final diff**

Run:

```bash
git diff -- README.md
git status --short
```

Expected: `README.md` is the only new tracked modification; `.superpowers/` may remain untracked and must not be added.

- [ ] **Step 6: Commit the README**

Run:

```bash
git add README.md
git commit -m "docs: highlight extended feature set"
```

Expected: one documentation commit containing only `README.md`.

- [ ] **Step 7: Publish the approved documentation**

Run:

```bash
git push origin main
```

Expected: `origin/main` advances to the README commit.
