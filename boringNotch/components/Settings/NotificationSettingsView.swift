import AppKit
import Contacts
import Defaults
import Intents
import SwiftUI

struct NotificationSettingsView: View {
    @Default(.notificationsEnabled) private var notificationsEnabled
    @Default(.notificationSetupCompleted) private var setupCompleted
    @Default(.notificationIgnoredSources) private var ignoredSources
    @Default(.notificationObservedSources) private var observedSources
    @Default(.notificationCategoryPreferences) private var categoryPreferences
    @Default(.notificationContactsEnabled) private var contactsEnabled
    @Default(.notificationAppleIntelligenceEnabled) private var intelligenceEnabled

    @ObservedObject private var manager = SystemNotificationManager.shared
    @ObservedObject private var focus = FocusModeManager.shared
    @ObservedObject private var contacts = ContactAvatarManager.shared

    @State private var showingSetup = false
    @State private var smartReplyAvailability = SmartReplyManager.availability

    var body: some View {
        Form {
            Section {
                Toggle("Show notifications inside the notch", isOn: enabledBinding)
                    .tint(.effectiveAccent)

                if notificationsEnabled {
                    LabeledContent("Capture") {
                        Label(
                            manager.isWatching ? "Active" : "Not active",
                            systemImage: manager.isWatching ? "checkmark.circle.fill" : "exclamationmark.circle"
                        )
                        .foregroundStyle(manager.isWatching ? .green : .orange)
                    }

                    if !manager.accessibilityAuthorized {
                        HStack {
                            Text(manager.setupMessage ?? "Accessibility access is required.")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Open Accessibility Settings") {
                                openSystemSettings("Privacy_Accessibility")
                            }
                        }
                    }

                    if !manager.isWatching {
                        HStack {
                            Spacer()
                            Button("Try Again") {
                                Task { _ = await manager.start(promptIfNeeded: false) }
                            }
                        }
                    }
                }
            } header: {
                Text("Notification Live Activity")
            } footer: {
                Text("Only visible banners are mirrored. Notification content stays in memory and is discarded after presentation.")
            }

            Section {
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
            } header: {
                Text("Apps")
            } footer: {
                Text("Notifications from every app are shown by default. Turn off an app to ignore future banners from it.")
            }

            Section {
                ForEach(SystemNotificationCategory.allCases) { category in
                    VStack(alignment: .leading, spacing: 7) {
                        Toggle(isOn: categoryShownBinding(category)) {
                            Label(category.label, systemImage: category.symbolName)
                        }

                        Picker("Open notch automatically", selection: categoryOpeningBinding(category)) {
                            ForEach(NotificationAutomaticOpeningPolicy.allCases) { policy in
                                Text(policy.label).tag(policy)
                            }
                        }
                        .disabled(!preference(for: category).isShown)
                    }
                    .padding(.vertical, 3)
                }
            } header: {
                Text("Categories")
            } footer: {
                Text("Never keeps the notification in the closed notch. The other options reuse the app's normal notch-opening animation.")
            }

            Section {
                LabeledContent("Focus status") {
                    Text(focusStatusLabel)
                        .foregroundStyle(.secondary)
                }

                if focus.authorizationStatus == .notDetermined {
                    Button("Allow Focus status") {
                        Task { await focus.requestAuthorization() }
                    }
                }

                LabeledContent("Focus filter") {
                    Text(focus.hasActiveOverride ? "Active for this Focus" : "Using category defaults")
                        .foregroundStyle(.secondary)
                }

                if focus.hasActiveOverride {
                    Text(focusOverrideSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Open Focus Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Focus-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
            } header: {
                Text("Focus")
            } footer: {
                Text("Add the Boring Notch Focus Filter to each macOS Focus that needs its own automatic-opening categories. The app reads only whether Focus is active, never its name.")
            }

            Section {
                Toggle("Use contact photos and WhatsApp handoff", isOn: $contactsEnabled)
                    .onChange(of: contactsEnabled) {
                        contacts.refreshAuthorizationStatus()
                    }

                if contactsEnabled {
                    LabeledContent("Contacts access") {
                        Text(contactsStatusLabel)
                            .foregroundStyle(.secondary)
                    }
                    if contacts.authorizationStatus != .authorized {
                        Button("Allow Contacts") {
                            Task { _ = await contacts.requestAccess() }
                        }
                    }
                }

                Toggle("Suggest replies with Apple Intelligence", isOn: $intelligenceEnabled)

                LabeledContent("Apple Intelligence") {
                    Label(
                        smartReplyStatus.label,
                        systemImage: smartReplyStatus.systemImage
                    )
                    .foregroundStyle(smartReplyStatus.color)
                }

                if !smartRepliesAvailable {
                    Button("Open Apple Intelligence Settings") {
                        openAppleIntelligenceSettings()
                    }
                }
            } header: {
                Text("Optional enhancements")
            } footer: {
                Text(smartReplyDescription)
            }

            Section {
                Button("Restore recommended notification settings") {
                    ignoredSources = []
                    categoryPreferences = NotificationCategoryPreference.recommended
                }
            }
        }
        .navigationTitle("Notifications")
        .disabled(false)
        .sheet(isPresented: $showingSetup) {
            notificationSetupSheet
        }
        .task {
            focus.startMonitoring()
            await manager.refreshAccessibilityStatus()
            contacts.refreshAuthorizationStatus()
            refreshSmartReplyAvailability()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            refreshSmartReplyAvailability()
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { notificationsEnabled },
            set: { enabled in
                if enabled {
                    showingSetup = true
                } else {
                    notificationsEnabled = false
                    manager.stop()
                }
            }
        )
    }

    private var notificationSetupSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "bell.and.waves.left.and.right.fill")
                .font(.system(size: 34))
                .foregroundStyle(Color.effectiveAccent)
            Text("Show notifications in the notch?")
                .font(.title2.bold())
            Text("Boring Notch needs Accessibility access to observe visible Notification Center banners and perform actions you choose. Notification content is never saved to disk.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Cancel") { showingSetup = false }
                Spacer()
                Button("Continue") {
                    notificationsEnabled = true
                    setupCompleted = true
                    showingSetup = false
                    Task { _ = await manager.start(promptIfNeeded: true) }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private var configurableSources: [NotificationSourceApp] {
        var seen = Set<String>()
        return (NotificationSourceApp.suggested + observedSources).filter {
            seen.insert($0.id).inserted
        }
    }

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

    private func preference(for category: SystemNotificationCategory) -> NotificationCategoryPreference {
        categoryPreferences.first { $0.category == category }
            ?? NotificationCategoryPreference.recommended.first { $0.category == category }!
    }

    private func updatePreference(
        _ category: SystemNotificationCategory,
        mutate: (inout NotificationCategoryPreference) -> Void
    ) {
        var values = categoryPreferences
        if let index = values.firstIndex(where: { $0.category == category }) {
            mutate(&values[index])
        } else {
            var value = preference(for: category)
            mutate(&value)
            values.append(value)
        }
        categoryPreferences = values
    }

    private func categoryShownBinding(_ category: SystemNotificationCategory) -> Binding<Bool> {
        Binding(
            get: { preference(for: category).isShown },
            set: { value in
                updatePreference(category) { $0.isShown = value }
            }
        )
    }

    private func categoryOpeningBinding(
        _ category: SystemNotificationCategory
    ) -> Binding<NotificationAutomaticOpeningPolicy> {
        Binding(
            get: { preference(for: category).automaticOpening },
            set: { value in
                updatePreference(category) { $0.automaticOpening = value }
            }
        )
    }

    private var focusStatusLabel: String {
        switch focus.authorizationStatus {
        case .authorized:
            return focus.isFocused == true ? "Focus active" : "Focus inactive"
        case .denied:
            return "Access denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not configured"
        @unknown default:
            return "Unavailable"
        }
    }

    private var focusOverrideSummary: String {
        let labels = focus.overrideCategories.map(\.label).sorted()
        return labels.isEmpty ? "No category may open automatically." : labels.joined(separator: ", ")
    }

    private var contactsStatusLabel: String {
        switch contacts.authorizationStatus {
        case .authorized: "Allowed"
        case .denied: "Denied"
        case .restricted: "Restricted"
        case .notDetermined: "Not requested"
        case .limited: "Limited"
        @unknown default: "Unavailable"
        }
    }

    private var smartRepliesAvailable: Bool {
        if case .available = smartReplyAvailability { return true }
        return false
    }

    private var smartReplyDescription: String {
        switch smartReplyAvailability {
        case .available:
            return "Suggestions are drafted entirely on-device and are never sent automatically."
        case .setupRequired(let reason), .unavailable(let reason):
            if intelligenceEnabled {
                return "Reply suggestions will start automatically when the model becomes available. \(reason)"
            }
            return reason
        }
    }

    private var smartReplyStatus: (label: String, systemImage: String, color: Color) {
        switch smartReplyAvailability {
        case .available:
            return ("Ready", "checkmark.circle.fill", .green)
        case .setupRequired:
            return ("Waiting for setup", "clock.badge.exclamationmark", .orange)
        case .unavailable:
            return ("Unavailable", "xmark.circle", .red)
        }
    }

    private func refreshSmartReplyAvailability() {
        smartReplyAvailability = SmartReplyManager.availability
    }

    private func openAppleIntelligenceSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.Siri-Settings.extension"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private func openSystemSettings(_ pane: String) {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?\(pane)"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
