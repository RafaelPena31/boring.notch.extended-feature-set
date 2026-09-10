//
//  NotificationHistoryView.swift
//  boringNotch
//

import SwiftUI

@MainActor
struct NotificationHistoryView: View {
    @EnvironmentObject private var vm: BoringViewModel
    @ObservedObject private var store = NotificationHistoryStore.shared

    let maximumHeight: CGFloat
    let onHeightChange: (CGFloat) -> Void

    @State private var filter: HistoryFilter = .recent
    @State private var sourceFilter: String?
    @State private var expandedGroups = Set<String>()
    @State private var initializedExpansion = false
    @State private var selectedID: String?
    @State private var listPosition: HistoryScrollTarget?
    @State private var detailPosition: HistoryScrollTarget?
    @State private var contentHeight: CGFloat = 0
    @State private var chromeHeight: CGFloat = 96
    @State private var openingID: String?
    @State private var openingTask: Task<Void, Never>?
    @State private var openFailure: OpenFailure?
    @FocusState private var isHistoryFocused: Bool

    private var visibleGroups: [NotificationHistoryGroup] {
        store.groups(savedOnly: filter == .saved, source: sourceFilter)
    }

    private var selectedItem: NotificationHistoryItem? {
        guard let selectedID, let item = store.item(id: selectedID), matchesFilters(item) else {
            return nil
        }
        return item
    }

    private var scrollPosition: Binding<HistoryScrollTarget?> {
        Binding(
            get: { selectedID == nil ? listPosition : detailPosition },
            set: { position in
                if selectedID == nil {
                    listPosition = position
                } else {
                    detailPosition = position
                }
            }
        )
    }

    private var scrollHeight: CGFloat {
        min(
            contentHeight > 0 ? contentHeight : 64,
            max(44, maximumHeight - chromeHeight - 32)
        )
    }

    var body: some View {
        let groups = visibleGroups

        VStack(spacing: 8) {
            header
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(key: HistoryChromeHeightKey.self, value: geometry.size.height)
                    }
                }

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 8) {
                    if let selectedItem {
                        notificationCard(selectedItem, isDetail: true)
                            .id(HistoryScrollTarget.detail(selectedItem.id))
                    } else if groups.isEmpty {
                        emptyState
                            .id(HistoryScrollTarget.empty)
                    } else {
                        ForEach(groups) { group in
                            groupHeader(group)
                                .id(HistoryScrollTarget.group(group.id))

                            if expandedGroups.contains(group.id) {
                                ForEach(group.items) { item in
                                    notificationCard(item, isDetail: false)
                                        .id(HistoryScrollTarget.item(item.id))
                                }
                            }
                        }
                    }
                }
                .scrollTargetLayout()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    GeometryReader { geometry in
                        Color.clear
                            .onChange(of: geometry.size.height, initial: true) { _, height in
                                contentHeight = height
                            }
                    }
                }
            }
            .scrollPosition(id: scrollPosition, anchor: selectedID == nil ? nil : .top)
            .frame(height: scrollHeight)

            footer
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(key: HistoryChromeHeightKey.self, value: geometry.size.height)
                    }
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            GeometryReader { geometry in
                Color.clear.onChange(of: geometry.size.height, initial: true) { _, height in
                    onHeightChange(height)
                }
            }
        }
        .onPreferenceChange(HistoryChromeHeightKey.self) { chromeHeight = $0 }
        .focusable()
        .focusEffectDisabled()
        .focused($isHistoryFocused)
        .onAppear {
            initializeExpansionIfNeeded()
            isHistoryFocused = true
        }
        .onDisappear {
            openingTask?.cancel()
            openingID = nil
        }
        .onExitCommand {
            if selectedID != nil {
                returnToList()
            } else {
                vm.close()
            }
        }
        .onChange(of: store.items) { _, _ in
            reconcileSelection()
            initializeExpansionIfNeeded()
        }
        .onChange(of: filter) { _, _ in
            reconcileSelection()
        }
        .onChange(of: sourceFilter) { _, _ in
            reconcileSelection()
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                if selectedID != nil {
                    HistoryActionButton("Back", symbol: "chevron.left", action: returnToList)
                }

                Text("Notifications")
                    .font(.headline)

                Spacer(minLength: 8)

                HistoryActionButton("Clear history", symbol: "trash") {
                    store.clear()
                }
                .disabled(store.items.isEmpty)
                .help("Clear this session’s notification history; use Undo to restore it")

                HistoryActionButton("Close history", symbol: "xmark", showsTitle: false) {
                    vm.close()
                }
            }

            HStack(spacing: 12) {
                Picker("Notifications", selection: $filter) {
                    Text("Recent").tag(HistoryFilter.recent)
                    Text("Saved for later").tag(HistoryFilter.saved)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 220)

                Spacer(minLength: 0)

                Picker("App", selection: $sourceFilter) {
                    Text("All apps").tag(String?.none)
                    ForEach(store.groups()) { group in
                        Text(group.name).tag(Optional(group.id))
                    }
                }
                .pickerStyle(.menu)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let openFailure {
                Text(openFailure.message)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(openFailure.message)
            }

            HStack(spacing: 8) {
                Text("This session only · up to 200 notifications")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                if !store.undoItems.isEmpty {
                    HistoryActionButton("Undo", symbol: "arrow.uturn.backward") {
                        store.undo()
                    }
                    .keyboardShortcut("z", modifiers: .command)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                store.items.isEmpty ? "No notifications captured" : "No matching notifications",
                systemImage: filter == .saved ? "bookmark" : "bell"
            )
            .font(.headline)

            Text(emptyExplanation)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
    }

    private var emptyExplanation: String {
        if store.items.isEmpty {
            return "Notifications captured during this session will appear here."
        }
        if filter == .saved {
            return sourceFilter == nil
                ? "Save a notification to keep it easy to find during this session."
                : "No saved notifications from this app. Try Recent or All apps."
        }
        return "Try another app or choose All apps."
    }

    private func groupHeader(_ group: NotificationHistoryGroup) -> some View {
        Button {
            if expandedGroups.contains(group.id) {
                expandedGroups.remove(group.id)
            } else {
                expandedGroups.insert(group.id)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: expandedGroups.contains(group.id) ? "chevron.down" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .frame(width: 12)

                if let first = group.items.first {
                    NotificationSourceIcon(notification: first.displayNotification, size: 22)
                        .accessibilityHidden(true)
                }

                Text(group.name)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Text(group.items.count, format: .number)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(HistorySurfaceButtonStyle())
        .accessibilityLabel("\(group.name), \(group.items.count) notifications")
        .accessibilityValue(expandedGroups.contains(group.id) ? "Expanded" : "Collapsed")
        .help(expandedGroups.contains(group.id) ? "Collapse \(group.name)" : "Expand \(group.name)")
    }

    private func notificationCard(_ item: NotificationHistoryItem, isDetail: Bool) -> some View {
        NotificationHistoryCard(
            item: item,
            isDetail: isDetail,
            isOpening: openingID == item.id,
            canOpen: openingID == nil,
            open: { openSource(item) },
            read: {
                detailPosition = .detail(item.id)
                selectedID = item.id
            },
            save: { store.toggleSaved(id: item.id) },
            remove: { store.remove(id: item.id) }
        )
    }

    private func initializeExpansionIfNeeded() {
        guard !initializedExpansion, let first = visibleGroups.first else { return }
        expandedGroups.insert(first.id)
        initializedExpansion = true
    }

    private func matchesFilters(_ item: NotificationHistoryItem) -> Bool {
        (filter != .saved || item.isSaved)
            && (sourceFilter == nil || item.sourceKey == sourceFilter)
    }

    private func reconcileSelection() {
        if let sourceFilter, !store.items.contains(where: { $0.sourceKey == sourceFilter }) {
            self.sourceFilter = nil
        }
        if selectedID != nil, selectedItem == nil {
            returnToList()
        }
        if let openFailure,
           store.item(id: openFailure.itemID).map(matchesFilters) != true {
            self.openFailure = nil
        }
    }

    private func returnToList() {
        selectedID = nil
        detailPosition = nil
        isHistoryFocused = true
    }

    private func openSource(_ item: NotificationHistoryItem) {
        guard openingID == nil else { return }
        openingID = item.id
        openFailure = nil
        openingTask = Task { @MainActor in
            let opened = await SystemNotificationManager.shared.openHistoricalSource(item)
            guard !Task.isCancelled else { return }
            openingID = nil
            if !opened, let current = store.item(id: item.id), matchesFilters(current) {
                openFailure = OpenFailure(itemID: item.id, message: "Couldn’t open \(item.sourceName).")
            }
        }
    }
}

private enum HistoryFilter: Hashable {
    case recent
    case saved
}

private enum HistoryScrollTarget: Hashable {
    case group(String)
    case item(String)
    case detail(String)
    case empty
}

private struct OpenFailure {
    let itemID: String
    let message: String
}

private struct NotificationHistoryCard: View {
    let item: NotificationHistoryItem
    let isDetail: Bool
    let isOpening: Bool
    let canOpen: Bool
    let open: () -> Void
    let read: () -> Void
    let save: () -> Void
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                if isDetail {
                    NotificationSourceIcon(notification: item.displayNotification, size: 28)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 2) {
                    if isDetail {
                        Text(item.sourceName)
                            .font(.subheadline.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(item.receivedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help(item.receivedAt.formatted(date: .abbreviated, time: .shortened))
                }

                Spacer(minLength: 0)

                HistoryActionButton("Remove", symbol: "trash", action: remove)
                    .help("Remove from history; use Undo to restore")
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            Button(action: open) {
                capturedContent
                    .contentShape(Rectangle())
            }
            .buttonStyle(HistorySurfaceButtonStyle())
            .disabled(!canOpen)
            .accessibilityHint("Open in \(item.sourceName)")
            .help("Open in \(item.sourceName)")

            HStack(spacing: 8) {
                if isDetail {
                    HistoryActionButton("Open in app", symbol: "arrow.up.forward.app", action: open)
                        .disabled(!canOpen)
                        .help("Open \(item.sourceName)")
                } else {
                    HistoryActionButton("Read", symbol: "doc.text", action: read)
                }

                HistoryActionButton(
                    item.isSaved ? "Saved for later" : "Save for later",
                    symbol: item.isSaved ? "bookmark.fill" : "bookmark",
                    action: save
                )
                .accessibilityLabel(item.isSaved ? "Unsave notification" : "Save notification")
                .help(item.isSaved ? "Remove bookmark" : "Save for this session")

                Spacer(minLength: 0)

                if isOpening {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Opening \(item.sourceName)")
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
        .contextMenu {
            Button("Open in \(item.sourceName)", action: open)
                .disabled(!canOpen)
            if !isDetail {
                Button("Read notification", action: read)
            }
            Button(item.isSaved ? "Unsave" : "Save for this session", action: save)
            Button("Remove from history", role: .destructive, action: remove)
        }
    }

    private var capturedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = item.title, !title.isEmpty {
                Text(title)
                    .font(.headline)
            }
            if let subtitle = item.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline.weight(.medium))
            }
            if let body = item.body, !body.isEmpty {
                Text(body)
                    .font(.body)
            }
        }
        .lineLimit(nil)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
    }
}

private struct HistoryActionButton: View {
    let title: String
    let symbol: String
    var showsTitle: Bool = true
    let action: () -> Void

    init(_ title: String, symbol: String, showsTitle: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.showsTitle = showsTitle
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Group {
                if showsTitle {
                    Label(title, systemImage: symbol)
                } else {
                    Image(systemName: symbol)
                }
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, showsTitle ? 8 : 0)
            .frame(minWidth: 28, minHeight: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(HistorySurfaceButtonStyle(restingOpacity: 0.08))
        .accessibilityLabel(title)
        .help(title)
    }
}

private struct HistorySurfaceButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false
    var restingOpacity: Double = 0

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background(
                .primary.opacity(configuration.isPressed ? 0.18 : (isHovering ? 0.12 : restingOpacity)),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .opacity(isEnabled ? 1 : 0.45)
            .onHover { isHovering = $0 }
    }
}

private struct HistoryChromeHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}
