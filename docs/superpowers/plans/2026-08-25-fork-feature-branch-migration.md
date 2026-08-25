# Fork Feature Branch Migration Implementation Plan

> **For agentic workers:** Execute inline in this session. Preserve the existing commit SHAs, never add `.superpowers/`, and validate the remote after every merge.

**Goal:** Publish every local boringNotch change to `RafaelPena31/boring.notch.extended-feature-set` through separately named feature branches, then merge those branches into the fork's `main` in dependency order.

**Architecture:** Treat the existing linear `feat/productivity-features` history as an immutable stack. Create one remote branch at each cohesive feature checkpoint, open and merge one PR at a time against `main`, and retain every feature branch after merge so the fork exposes both the final integrated product and its reviewable slices.

**Tech Stack:** Git, GitHub CLI, Swift/Xcode project history.

---

### Task 1: Register and verify the fork

**Files:**
- Modify: `.git/config` through `git remote add extended`

- [ ] Verify GitHub authentication and admin access to `RafaelPena31/boring.notch.extended-feature-set`.
- [ ] Add remote `extended` with fetch/push URL `https://github.com/RafaelPena31/boring.notch.extended-feature-set.git`.
- [ ] Fetch `extended/main` and verify its merge base with local `main`.

### Task 2: Publish cohesive history checkpoints

**Files:**
- Create remote branches only; source files remain byte-for-byte identical to their existing commits.

- [ ] Publish `docs/productivity-features` at `4eb23732`.
- [ ] Publish `feat/clipboard-history` at `61173b6b`.
- [ ] Publish `feat/calendar-live-activity` at `af94a8a9`.
- [ ] Publish `feat/pomodoro` at `3b451965`.
- [ ] Publish `feat/keep-awake` at `e7be329b`.
- [ ] Publish `fix/productivity-integration` at `9a81dc7c`.
- [ ] Publish `docs/next-features` at `9b7284f1`.
- [ ] Publish `feat/shelf-image-conversion` at `c28e0332`.
- [ ] Publish `feat/calendar-meeting-actions` at `1305de29`.
- [ ] Publish `feat/media-progress` at `26eb0667`.
- [ ] Publish `feat/notifications-and-focus` at `a2ab17e8`.
- [ ] Publish `feat/compact-player-audio-output` at `3421d7e1`.
- [ ] Publish `fix/notification-reliability` at `8c3d1644`.
- [ ] Publish `feat/calendar-native-meeting-launch` at `41362854`.

### Task 3: Merge every branch separately

**Files:**
- Modify remote `main` history only through GitHub pull-request merges.

- [ ] For each branch in Task 2 order, create a PR against `main`, inspect the changed commit range, merge with a merge commit, and fetch the updated `extended/main` before continuing.
- [ ] Do not delete merged branches.
- [ ] Stop if a PR contains commits beyond its declared checkpoint or if GitHub reports an unexpected conflict.

### Task 4: Validate the final fork

**Files:**
- No source edits.

- [ ] Confirm all fourteen feature/documentation/fix branches exist on `extended`.
- [ ] Confirm every local commit from `e5684b6b` through `41362854` is an ancestor of `extended/main`.
- [ ] Confirm `git diff 41362854..extended/main -- boringNotch BoringNotchXPCHelper boringNotch.xcodeproj docs/superpowers` contains no lost local implementation.
- [ ] Build `extended/main` for macOS with a fresh DerivedData directory and report any pre-existing versus migration-introduced failures.
- [ ] Leave the local checkout on a branch tracking `extended/main` for subsequent work.
