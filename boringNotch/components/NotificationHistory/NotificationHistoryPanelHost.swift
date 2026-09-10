import AppKit
import SwiftUI

/// Gives history keyboard ownership without changing the shared notch window.
struct NotificationHistoryPanelHost: NSViewRepresentable {
    let isActive: Bool

    final class HostView: NSView {
        var isActive = false
        private weak var panel: BoringNotchSkyLightWindow?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if panel !== window { releaseKeyboard() }
            apply()
        }

        func apply() {
            guard let panel = window as? BoringNotchSkyLightWindow else { return }
            self.panel = panel
            panel.wantsKeyForHistory = isActive
        }

        func releaseKeyboard() {
            if let panel {
                panel.wantsKeyForHistory = false
            }
            panel = nil
        }
    }

    func makeNSView(context: Context) -> HostView { HostView() }

    func updateNSView(_ view: HostView, context: Context) {
        view.isActive = isActive
        DispatchQueue.main.async { [weak view] in view?.apply() }
    }

    static func dismantleNSView(_ view: HostView, coordinator: ()) {
        view.isActive = false
        view.releaseKeyboard()
    }
}
