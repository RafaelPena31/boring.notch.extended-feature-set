# Notifications

Configure the feature in **Settings → Notifications**. Accessibility access is required to mirror visible macOS notification banners.

- **Apps → Open notch automatically:** Never (default), use the category setting, open only outside Focus, or always open. Every app starts with automatic opening off, including newly discovered apps. Categories also default to Never. Select “Use category setting” explicitly to inherit category rules. New apps appear after their first captured banner.
- Hidden apps and hidden categories stay hidden. An active Boring Notch Focus Filter takes priority over app and category opening rules. Without a filter, “Only outside Focus” requires Focus to be confirmed inactive.
- The closed notch prioritizes the message in a two-line preview where height allows. Selected apps open the existing notch to show more content, below the physical camera cutout. Long messages can be scrolled.
- **Dismiss:** click the always-visible ×, even while the notch is closed. Hovering over the compact action buttons does not expand the notch. An optional global shortcut is available in **Quick dismiss** and **Shortcuts → Notifications**.
- Reply controls and Apple Intelligence suggestions appear only when the live banner exposes a Reply action or text-input field. “Show details” alone is not a reply capability. Other notifications show their available actions or an Open button.
- FaceTime notifications use the call presentation even when the app's bundle identifier cannot be resolved. Calls never show a text-reply editor. Live Answer/Decline controls appear only if macOS exposes those actions; otherwise the notification offers Open in the source app.

Content and drafts remain in memory. Only app identities and notification preferences are saved. The app cannot reveal content that macOS or the originating app withholds from its notification banner.
