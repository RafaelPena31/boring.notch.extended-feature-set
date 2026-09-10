import AppKit
import SwiftUI

/// Resizes the existing notch panel for manual browsing, then restores its frame.
struct NotificationHistoryPanelHost: NSViewRepresentable {
    let height: CGFloat?

    final class HostView: NSView {
        var requestedHeight: CGFloat?
        private var normalHeight: CGFloat?
        private weak var ownedPanel: BoringNotchSkyLightWindow?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if ownedPanel !== window { restore() }
            apply()
        }

        func apply() {
            guard let panel = window as? BoringNotchSkyLightWindow else { return }
            if let requestedHeight {
                if normalHeight == nil {
                    normalHeight = panel.frame.height
                    ownedPanel = panel
                }
                resize(panel, height: requestedHeight)
                panel.wantsKeyForHistory = true
            } else {
                restore()
            }
        }

        func restore() {
            if let panel = ownedPanel, let normalHeight {
                resize(panel, height: normalHeight)
                panel.wantsKeyForHistory = false
            }
            normalHeight = nil
            ownedPanel = nil
        }

        private func resize(_ panel: NSWindow, height: CGFloat) {
            var frame = panel.frame
            guard abs(frame.height - height) > 0.5 else { return }
            frame.origin.y = frame.maxY - height
            frame.size.height = height
            panel.setFrame(frame, display: true)
        }
    }

    func makeNSView(context: Context) -> HostView { HostView() }

    func updateNSView(_ view: HostView, context: Context) {
        view.requestedHeight = height
        DispatchQueue.main.async { [weak view] in view?.apply() }
    }

    static func dismantleNSView(_ view: HostView, coordinator: ()) {
        view.requestedHeight = nil
        view.restore()
    }
}
