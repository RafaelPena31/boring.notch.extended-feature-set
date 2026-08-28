import AppKit
import Defaults
import SwiftUI

enum NotificationCompactLayout {
    static let spacing: CGFloat = 8
    static let preferredWingWidth: CGFloat = 205

    static func centerGapWidth(for notchWidth: CGFloat) -> CGFloat {
        max(0, notchWidth - cornerRadiusInsets.closed.top)
    }

    static func wingWidth(for notchWidth: CGFloat) -> CGFloat {
        let availableContentWidth = windowSize.width
            - (2 * cornerRadiusInsets.closed.bottom)
            - centerGapWidth(for: notchWidth)
            - (2 * spacing)

        return min(preferredWingWidth, max(0, availableContentWidth / 2))
    }

    static func silhouetteWidth(for notchWidth: CGFloat) -> CGFloat {
        let contentWidth = (2 * wingWidth(for: notchWidth))
            + centerGapWidth(for: notchWidth)
            + (2 * spacing)

        return min(
            windowSize.width,
            contentWidth + (2 * cornerRadiusInsets.closed.bottom)
        )
    }
}

/// Closed-state presentation. The notch itself grows horizontally and all
/// notification content remains inside the same black silhouette.
struct NotificationCompactLiveActivity: View {
    @EnvironmentObject private var vm: BoringViewModel
    @ObservedObject private var manager = SystemNotificationManager.shared

    let notification: SystemNotification

    private var iconSize: CGFloat {
        max(20, vm.effectiveClosedNotchHeight - 12)
    }

    private var wingWidth: CGFloat {
        NotificationCompactLayout.wingWidth(for: vm.closedNotchSize.width)
    }

    private var centerGapWidth: CGFloat {
        NotificationCompactLayout.centerGapWidth(for: vm.closedNotchSize.width)
    }

    private var leadingTitle: String {
        notification.sender
            ?? notification.appName
            ?? notification.category.label
    }

    private var leadingSubtitle: String? {
        let subtitle = notification.appName ?? notification.category.label
        return subtitle == leadingTitle ? nil : subtitle
    }

    private var summary: String {
        notification.body
            ?? notification.subtitle
            ?? notification.category.label
    }

    private var summaryContext: String? {
        if let subtitle = notification.subtitle,
           subtitle != summary,
           subtitle != notification.sender
        {
            return subtitle
        }

        return notification.category.label == summary
            ? nil
            : notification.category.label
    }

    var body: some View {
        HStack(spacing: NotificationCompactLayout.spacing) {
            leadingWing
                .frame(width: wingWidth, alignment: .leading)

            Rectangle()
                .fill(.black)
                .frame(width: centerGapWidth)

            trailingWing
                .frame(width: wingWidth, alignment: .trailing)
        }
        .frame(height: vm.effectiveClosedNotchHeight, alignment: .center)
        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
    }

    private var leadingWing: some View {
        HStack(spacing: 8) {
            NotificationSourceIcon(notification: notification, size: iconSize)

            VStack(alignment: .leading, spacing: 1) {
                Text(leadingTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let leadingSubtitle {
                    Text(leadingSubtitle)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var trailingWing: some View {
        HStack(spacing: 8) {
            if let code = notification.detectedCode {
                Text(code)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .kerning(1.2)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Button {
                    manager.copyCode(from: notification)
                } label: {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: iconSize, height: iconSize)
                        .background(Color.effectiveAccent, in: Circle())
                }
                .buttonStyle(NotificationScaleButtonStyle())
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(summary)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if let summaryContext {
                        Text(summaryContext)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: notification.category.symbolName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(notification.isLive ? Color.effectiveAccent : .secondary)
            }

            if !manager.queued.isEmpty {
                Text("+\(manager.queued.count)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.14), in: Capsule())
            }
        }
    }
}

/// Open-state presentation. It replaces the normal notch interior while the
/// notification is active; no card or window is placed below the notch box.
struct NotificationExpandedView: View {
    private enum ContentSizing {
        case intrinsic
        case constrained
        case flexible
    }

    @ObservedObject private var manager = SystemNotificationManager.shared

    let notification: SystemNotification
    let compactPresentation: Bool

    init(notification: SystemNotification, compactPresentation: Bool = false) {
        self.notification = notification
        self.compactPresentation = compactPresentation
    }

    @State private var replyText = ""
    @State private var isSending = false
    @State private var handoffFeedback = false
    @State private var suggestions: [String] = []
    @State private var hostWindow: BoringNotchSkyLightWindow?
    @State private var interactionHeld = false
    @FocusState private var replyFocused: Bool

    private var userFacingActions: [String] {
        notification.actions.filter { action in
            SystemNotificationActionClassifier.kind(of: action) == nil
                && action != "AXPress"
        }
    }

    private var contentInsets: EdgeInsets {
        EdgeInsets(
            top: compactPresentation ? 10 : 14,
            leading: compactPresentation ? 12 : 18,
            bottom: compactPresentation ? 8 : 14,
            trailing: compactPresentation ? 12 : 18
        )
    }

    private let compactContentColumnWidth: CGFloat = 260

    var body: some View {
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
        .overlay(alignment: .topTrailing) {
            dismissButton
                .padding(.top, contentInsets.top)
                .padding(.trailing, contentInsets.trailing)
        }
        .id(notification.id)
        .background(NotificationWindowAccessor { window in
            hostWindow = window as? BoringNotchSkyLightWindow
        })
        .onAppear {
            manager.holdActive()
            replyText = manager.draft(for: notification.id)
        }
        .onDisappear {
            hostWindow?.wantsKeyForTextInput = false
            manager.isComposingReply = false
            manager.resumeExpiry(after: 3)
            endInteraction()
        }
        .onChange(of: hostWindow) { _, window in
            if replyFocused { window?.wantsKeyForTextInput = true }
        }
        .onChange(of: replyFocused) { _, focused in
            guard focused else { return }
            hostWindow?.wantsKeyForTextInput = true
            manager.isComposingReply = true
            manager.holdActive()
            beginInteraction()
        }
        .onChange(of: replyText) { _, text in
            manager.setDraft(text, for: notification.id)
            if replyFocused { manager.holdActive() }
        }
    }

    @ViewBuilder
    private func contentGroup(sizing: ContentSizing) -> some View {
        HStack(alignment: .top, spacing: 14) {
            avatar

            switch sizing {
            case .intrinsic:
                notificationDetails
                    .fixedSize(horizontal: true, vertical: false)
            case .constrained:
                notificationDetails
                    .frame(width: compactContentColumnWidth, alignment: .leading)
            case .flexible:
                notificationDetails
                    .frame(maxWidth: 430, alignment: .leading)
            }
        }
    }

    private var notificationDetails: some View {
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
    }

    @ViewBuilder
    private var avatar: some View {
        if let sender = notification.sender, notification.category == .message
            || notification.category == .call || notification.category == .mail {
            ZStack(alignment: .bottomTrailing) {
                NotificationPersonAvatar(name: sender, size: 48)
                NotificationSourceIcon(notification: notification, size: 20)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5).stroke(.black, lineWidth: 1.5)
                    }
                    .offset(x: 3, y: 3)
            }
        } else {
            NotificationSourceIcon(notification: notification, size: 48)
        }
    }

    private var header: some View {
        HStack(spacing: 7) {
            Text(notification.sender ?? notification.appName ?? "Notification")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(notification.appName ?? notification.category.label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .lineLimit(1)

            if !manager.queued.isEmpty {
                Button {
                    manager.cycleToNext()
                } label: {
                    Text("+\(manager.queued.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.white.opacity(0.14), in: Capsule())
                }
                .buttonStyle(NotificationScaleButtonStyle())
                .help("Show next notification")
            }
        }
        .padding(.trailing, 28)
    }

    @ViewBuilder
    private var message: some View {
        if let subtitle = notification.subtitle, subtitle != notification.sender {
            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        if let body = notification.body {
            Text(body)
                .font(.system(size: 13))
                .foregroundStyle(.secondary.opacity(0.95))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var actionArea: some View {
        if let code = notification.detectedCode {
            codeRow(code)
        } else if notification.category == .call {
            callActions
        } else if notification.canReply {
            replyArea
        } else if !userFacingActions.isEmpty {
            genericActions
        } else {
            openButton
        }
    }

    private func codeRow(_ code: String) -> some View {
        HStack(spacing: 10) {
            Text(code)
                .font(.system(size: 21, weight: .semibold, design: .monospaced))
                .kerning(2)
                .foregroundStyle(.white)

            Button {
                manager.copyCode(from: notification)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 11)
                    .frame(height: 28)
                    .background(Color.effectiveAccent, in: Capsule())
            }
            .buttonStyle(NotificationScaleButtonStyle())
        }
    }

    @ViewBuilder
    private var callActions: some View {
        HStack(spacing: 12) {
            if let decline = notification.actions.first(where: {
                SystemNotificationActionClassifier.kind(of: $0) == .decline
            }) {
                circleAction(symbol: "phone.down.fill", color: .red) {
                    Task { _ = await manager.perform(decline, on: notification) }
                }
            }
            if let accept = notification.actions.first(where: { action in
                SystemNotificationActionClassifier.kind(of: action) == .accept
            }) {
                circleAction(symbol: "phone.fill", color: .green) {
                    Task { _ = await manager.perform(accept, on: notification) }
                }
            }
        }
    }

    private func circleAction(
        symbol: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(color, in: Circle())
        }
        .buttonStyle(NotificationScaleButtonStyle())
    }

    private var replyArea: some View {
        VStack(alignment: .leading, spacing: 7) {
            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(suggestions.enumerated()), id: \.offset) { _, suggestion in
                            Button {
                                replyText = suggestion
                                replyFocused = true
                            } label: {
                                Text(suggestion)
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(.white.opacity(0.1), in: Capsule())
                            }
                            .buttonStyle(NotificationScaleButtonStyle())
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Reply", text: $replyText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($replyFocused)
                    .onSubmit(send)
                    .padding(.horizontal, 11)
                    .frame(height: 30)
                    .background(.white.opacity(0.08), in: Capsule())
                    .overlay {
                        Capsule().stroke(.white.opacity(replyFocused ? 0.2 : 0), lineWidth: 1)
                    }

                Button(action: send) {
                    Group {
                        if isSending {
                            ProgressView().controlSize(.small)
                        } else if handoffFeedback {
                            Image(systemName: "doc.on.clipboard")
                        } else {
                            Image(systemName: "arrow.up")
                        }
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(canSend ? Color.effectiveAccent : .white.opacity(0.1), in: Circle())
                }
                .buttonStyle(NotificationScaleButtonStyle())
                .disabled(!canSend)
            }
        }
        .task(id: notification.id) {
            guard let body = notification.body else { return }
            suggestions = await SmartReplyManager.suggestReplies(
                sender: notification.sender,
                body: body
            )
        }
    }

    private var canSend: Bool {
        !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    private func send() {
        guard canSend else { return }
        let text = replyText
        isSending = true
        Task {
            let outcome = await manager.reply(to: notification, text: text)
            isSending = false
            if outcome == .draftedInApp || outcome == .copiedAndOpened {
                handoffFeedback = true
                try? await Task.sleep(for: .milliseconds(1200))
                manager.dismissActive(token: notification.id)
            }
            if outcome == .failed { manager.resumeExpiry(after: 3) }
        }
    }

    private var genericActions: some View {
        HStack(spacing: 8) {
            ForEach(Array(userFacingActions.prefix(2)), id: \.self) { action in
                Button(action) {
                    Task { _ = await manager.perform(action, on: notification) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var openButton: some View {
        Button {
            Task { _ = await manager.open(notification) }
        } label: {
            Label("Open in \(notification.appName ?? "app")", systemImage: "arrow.up.forward.app.fill")
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(.white.opacity(0.08), in: Capsule())
        }
        .buttonStyle(NotificationScaleButtonStyle())
    }

    private var dismissButton: some View {
        Button {
            manager.dismissActive(token: notification.id)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
                .background(.white.opacity(0.1), in: Circle())
        }
        .buttonStyle(NotificationScaleButtonStyle())
    }

    private func beginInteraction() {
        guard !interactionHeld else { return }
        interactionHeld = true
        SharingStateManager.shared.beginInteraction()
    }

    private func endInteraction() {
        guard interactionHeld else { return }
        interactionHeld = false
        SharingStateManager.shared.endInteraction()
    }
}

private struct NotificationSourceIcon: View {
    let notification: SystemNotification
    let size: CGFloat

    var body: some View {
        Group {
            if let icon = notification.appIcon {
                Image(nsImage: icon).resizable()
            } else {
                Image(systemName: notification.category.symbolName)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.22)
                    .foregroundStyle(.secondary)
            }
        }
        .aspectRatio(contentMode: .fit)
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
    }
}

private struct NotificationPersonAvatar: View {
    @ObservedObject private var contacts = ContactAvatarManager.shared

    let name: String
    let size: CGFloat

    var body: some View {
        Group {
            if let photo = contacts.photo(forSenderNamed: name) {
                Image(nsImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    monogramColor
                    Text(initials)
                        .font(.system(size: size * 0.38, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init)
        return letters.isEmpty ? "?" : letters.joined().uppercased()
    }

    private var monogramColor: Color {
        var hasher = Hasher()
        hasher.combine(name)
        return Color(
            hue: Double(abs(hasher.finalize()) % 360) / 360,
            saturation: 0.55,
            brightness: 0.75
        )
    }
}

private struct NotificationScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.smooth(duration: 0.14), value: configuration.isPressed)
    }
}

private struct NotificationWindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { onResolve(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { onResolve(nsView.window) }
    }
}
