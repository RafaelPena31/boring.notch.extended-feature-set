import AppKit
import QuartzCore
import SwiftUI

/// Expands the shared notch window for history and gives it keyboard ownership.
struct NotificationHistoryPanelHost: NSViewRepresentable {
    let isActive: Bool
    let reduceMotion: Bool

    final class HostView: NSView {
        var isActive = false
        var reduceMotion = false
        private weak var panel: BoringNotchSkyLightWindow?
        private var targetHeight: CGFloat?
        private var lastReduceMotion = false
        private var resizeGeneration: UInt = 0

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if panel !== window { releasePanel() }
            apply()
        }

        func apply() {
            guard let currentPanel = window as? BoringNotchSkyLightWindow else {
                releasePanel()
                return
            }
            if panel !== currentPanel {
                releasePanel()
                panel = currentPanel
            }

            let requestedHeight = isActive ? notificationHistoryWindowHeight : windowSize.height
            if targetHeight != requestedHeight || (reduceMotion && !lastReduceMotion) {
                targetHeight = requestedHeight
                resize(currentPanel, height: requestedHeight, animated: !reduceMotion)
            }
            lastReduceMotion = reduceMotion
            currentPanel.wantsKeyForHistory = isActive
        }

        func releasePanel() {
            if let panel {
                resize(panel, height: windowSize.height, animated: false)
                panel.wantsKeyForHistory = false
            }
            targetHeight = nil
            panel = nil
        }

        private func resize(_ panel: NSWindow, height: CGFloat, animated: Bool) {
            resizeGeneration &+= 1
            let generation = resizeGeneration
            var target = panel.frame
            target.origin.y = target.maxY - height
            target.size.height = height

            guard animated else {
                panel.setFrame(target, display: true)
                return
            }

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.24
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(target, display: true)
            } completionHandler: { [weak self, weak panel] in
                guard let self, let panel else { return }
                guard self.resizeGeneration == generation else { return }
                let settledHeight = self.panel === panel
                    ? (self.targetHeight ?? windowSize.height)
                    : windowSize.height
                guard abs(panel.frame.height - settledHeight) > 0.5 else { return }
                self.resize(panel, height: settledHeight, animated: false)
            }
        }
    }

    func makeNSView(context: Context) -> HostView { HostView() }

    func updateNSView(_ view: HostView, context: Context) {
        view.isActive = isActive
        view.reduceMotion = reduceMotion
        DispatchQueue.main.async { [weak view] in view?.apply() }
    }

    static func dismantleNSView(_ view: HostView, coordinator: ()) {
        view.isActive = false
        view.releasePanel()
    }
}
