//
//  TabSelectionView.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-25.
//

import Defaults
import SwiftUI

struct TabModel: Identifiable {
    let label: String
    let icon: String
    let view: NotchViews
    var id: NotchViews { view }
}

struct TabSelectionView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @Default(.boringShelf) var shelfEnabled
    @Default(.clipboardHistoryEnabled) var clipboardEnabled
    @Default(.notificationsEnabled) var notificationsEnabled
    @Namespace var animation

    private var tabs: [TabModel] {
        var result = [TabModel(label: "Home", icon: "house.fill", view: .home)]
        if shelfEnabled {
            result.append(TabModel(label: "Shelf", icon: "tray.fill", view: .shelf))
        }
        if clipboardEnabled {
            result.append(TabModel(label: "Clipboard", icon: "clipboard.fill", view: .clipboard))
        }
        result.append(TabModel(label: "Pomodoro", icon: "timer", view: .pomodoro))
        if notificationsEnabled {
            result.append(TabModel(label: "Notifications", icon: "bell.badge", view: .notificationHistory))
        }
        return result
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                    TabButton(label: tab.label, icon: tab.icon, selected: coordinator.currentView == tab.view,
                              horizontalPadding: tabs.count >= 5 ? 8 : 15) {
                        coordinator.currentView = tab.view
                    }
                    .frame(height: 26)
                    .foregroundStyle(tab.view == coordinator.currentView ? .white : .gray)
                    .background {
                        if tab.view == coordinator.currentView {
                            Capsule()
                                .fill(Color(nsColor: .secondarySystemFill))
                                .matchedGeometryEffect(id: "capsule", in: animation)
                        }
                    }
            }
        }
        .clipShape(Capsule())
        .animation(reduceMotion ? nil : .smooth, value: coordinator.currentView)
    }
}

#Preview {
    BoringHeader().environmentObject(BoringViewModel())
}
