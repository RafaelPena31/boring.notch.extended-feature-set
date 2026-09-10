# Notifications

Configure the feature in **Settings → Notifications**. Accessibility access is required to mirror visible macOS notification banners.

- **Apps → Open notch automatically:** Never (default), use the category setting, open only outside Focus, or always open. Every app starts with automatic opening off, including newly discovered apps. Categories also default to Never. Select “Use category setting” explicitly to inherit category rules. New apps appear after their first captured banner.
- Hidden apps and hidden categories stay hidden. An active Boring Notch Focus Filter takes priority over app and category opening rules. Without a filter, “Only outside Focus” requires Focus to be confirmed inactive.
- The closed notch prioritizes the message in a two-line preview where height allows. The open notch wraps the full title, subtitle and message without adding ellipses; long notifications scroll within the available space below the physical camera cutout. Scrolling a notification does not close the notch.
- Click the closed notification, or the icon, title or message in the open notch, to open its source. The app first invokes the original banner, preserving its destination when available, then falls back to opening the local app. Reply, Copy, Answer/Decline, Next and Dismiss controls retain their own actions.
- **Dismiss:** click the always-visible ×, even while the notch is closed. Hovering over the compact action buttons does not expand the notch. An optional global shortcut is available in **Quick dismiss** and **Shortcuts → Notifications**.
- Reply controls and Apple Intelligence suggestions appear only when the live banner exposes a Reply action or text-input field. “Show details” alone is not a reply capability. Other notifications show their available actions or an Open button.
- FaceTime notifications use the call presentation even when the app's bundle identifier cannot be resolved. Calls never show a text-reply editor. Live Answer/Decline controls appear only if macOS exposes those actions; otherwise the notification offers Open in the source app.

Content and drafts remain in memory. Only app identities and notification preferences are saved. The app cannot reveal content that macOS or the originating app withholds from its notification banner.

## Session history

Open **Notifications** in the notch tabs, **Notification History** in the app menu, or **Settings → Notifications → Session history**. The expanded live notification also has a history button. History opens manually inside the existing notch, below the physical camera area; new banners do not take over while you are browsing it.

- Notifications are grouped by app, newest first. Expand several groups at once, filter by app, or use **Read** for the complete captured text. Long text scrolls without added ellipses. Escape returns from detail to the list, then closes the notch.
- **Save for later** bookmarks a notification for this session. It does not schedule a reminder. Recent and Saved share a limit of **200 notifications**; the oldest records are removed when the limit is reached.
- Dismissing or opening a live notification does not remove its history. The visible remove button and **Clear history** affect only notch history, not macOS Notification Center. **Undo** restores the last removal or clear while preserving newer arrivals.
- Clicking the content opens its source. A still-live banner can preserve its original destination; otherwise the app falls back to opening the local application. Old conversations and iPhone-only apps may not be reopenable. Failures appear inline without deleting the record.
- Historical items have no reply composer or call controls. Reading history does not retain native notification actions or keep banners alive.

History, saved marks and undo data stay **in memory only**. Quitting the app or disabling notifications clears them. Hiding an app or category also removes its retained records, including undo data. A temporary capture-helper disconnection does not erase already captured text. History does not import older macOS Notification Center entries, and no notification text or thumbnails are written to disk, logs or cloud services.
