# README Redesign Design

**Date:** 2026-08-28

**Status:** Approved for specification review

## Goal

Replace the inherited upstream README with an English, product-focused page for this fork. The new README must explain what this extended version delivers today, place the fork's implemented features at the center of the page, and keep upstream-project information to a concise attribution.

## Audience and Positioning

The primary audience is a GitHub visitor deciding whether to build and use this fork. The page will present the repository as an extended Boring Notch experience while stating clearly that it is derived from the original open-source project.

The README will not imply that this fork owns upstream releases, distribution channels, community links, funding links, or future plans.

## Page Structure

1. **Hero**
   - Use the name `Boring Notch Extended`.
   - Describe the fork in one concise paragraph as a macOS notch workspace for notifications, productivity, calendar, media, and quick actions.
   - Identify it as a community fork near the opening instead of hiding that fact.

2. **Extended Features**
   - Make this the most prominent section.
   - Group related capabilities so the list remains scannable.
   - Describe only behavior implemented in the current branch.

3. **Core Experience**
   - Summarize inherited capabilities that remain important to the complete app experience.
   - Avoid reproducing the upstream roadmap or marketing copy.

4. **Privacy and Permissions**
   - Explain why Accessibility, Calendar, Contacts, Focus status, and optional Apple Intelligence capabilities may be requested.
   - State that mirrored notification contents, reply drafts, avatars, and suggestions are held in memory rather than persisted.

5. **Requirements and Local Installation**
   - State the current macOS and Xcode prerequisites already documented by the repository.
   - Make `./scripts/install-local.sh` the sole supported local build-and-install workflow.
   - Link to `BUILDING.md` for the local Team ID and signing configuration.

6. **Credits**
   - Link to the original Boring Notch repository.
   - Credit TheBoredTeam and relevant upstream contributors concisely.
   - Preserve the link to `THIRD_PARTY_LICENSES.md`.

## Implemented Feature Coverage

The README will emphasize these shipped feature groups:

- Notification Live Activity inside the notch for notifications observed from any app.
- Per-app and per-category notification controls, automatic-opening policies, and macOS Focus integration.
- Notification classification for OTP codes, calls, permissions, decisions, messages, mail, and other content.
- Notification stacking, native actions, OTP copying, contact avatars, replies, and optional on-device Apple Intelligence suggestions.
- Complete private clipboard history for text, links, images, and files.
- Calendar event Live Activity and native-client meeting joining with browser fallback.
- Pomodoro sessions integrated with the open and closed notch.
- Keep Awake / Caffeine controls with safety options.
- Playback progress around the closed-notch contour.
- Optional compact music player and audio-output switching.
- Shelf image conversion to supported PNG, JPEG, HEIC, and WebP formats.

## Inherited Core Capabilities

The compact Core Experience section will mention the retained media controls and visualizer, Calendar and Reminders integration, file Shelf and AirDrop, system HUD replacements, battery status, mirror, gestures, and multi-display customization.

## Content Removed from the Upstream README

- Upstream release-download and Homebrew installation instructions.
- Upstream security-warning instructions tied to its unsigned releases.
- Upstream roadmap and statements that implemented fork features are still planned.
- Upstream Discord, Ko-fi, website, star-history, and contributor-marketing sections.
- Upstream-specific build commands that bypass this fork's local installation process.

## Presentation Rules

- Keep the README entirely in English.
- Prefer short paragraphs and grouped bullet lists over a large comparison table.
- Use restrained emoji and badges; clarity takes priority over decoration.
- Do not add claims, screenshots, release links, or installation methods that cannot be verified from this repository.
- Do not expose the maintainer's local Team ID, signing identity, or `.local-signing.env` values.

## Verification

- Confirm every highlighted capability exists in the current source or committed feature history.
- Confirm all local Markdown links resolve.
- Scan the README for stale upstream URLs and unsupported installation commands.
- Review the rendered Markdown hierarchy for a clear feature-first reading order.

## Out of Scope

- Creating new screenshots, release artifacts, Homebrew casks, or downloadable builds.
- Changing source code or application behavior.
- Rewriting `BUILDING.md` beyond linking to it.
- Maintaining a detailed upstream-versus-fork comparison or changelog.
