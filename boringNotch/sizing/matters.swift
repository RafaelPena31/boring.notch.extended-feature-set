//
//  sizeMatters.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 05/08/24.
//

import Defaults
import Foundation
import SwiftUI

let downloadSneakSize: CGSize = .init(width: 65, height: 1)
let batterySneakSize: CGSize = .init(width: 160, height: 1)

let shadowPadding: CGFloat = 20
let openNotchSize: CGSize = .init(width: 640, height: 190)
let windowSize: CGSize = .init(width: openNotchSize.width, height: openNotchSize.height + shadowPadding)
let notificationHistoryNotchHeight: CGFloat = 340
let notificationHistoryWindowHeight: CGFloat = notificationHistoryNotchHeight + shadowPadding
let cornerRadiusInsets: (opened: (top: CGFloat, bottom: CGFloat), closed: (top: CGFloat, bottom: CGFloat)) = (opened: (top: 19, bottom: 24), closed: (top: 6, bottom: 14))

enum MusicPlayerImageSizes {
    static let cornerRadiusInset: (opened: CGFloat, closed: CGFloat) = (opened: 13.0, closed: 4.0)
    static let size = (opened: CGSize(width: 90, height: 90), closed: CGSize(width: 20, height: 20))
}

enum NotchSafeLayoutMetrics {
    static func wingWidth(leading: CGFloat, trailing: CGFloat) -> CGFloat {
        max(0, max(leading, trailing))
    }

    static func contentWidth(
        exclusionWidth: CGFloat,
        leading: CGFloat,
        trailing: CGFloat,
        spacing: CGFloat
    ) -> CGFloat {
        (2 * wingWidth(leading: leading, trailing: trailing))
            + max(0, exclusionWidth)
            + (2 * max(0, spacing))
    }

    static func silhouetteWidth(
        exclusionWidth: CGFloat,
        leading: CGFloat,
        trailing: CGFloat,
        spacing: CGFloat
    ) -> CGFloat {
        min(
            windowSize.width,
            contentWidth(
                exclusionWidth: exclusionWidth,
                leading: leading,
                trailing: trailing,
                spacing: spacing
            ) + (2 * cornerRadiusInsets.closed.bottom)
        )
    }
}

struct NotchSafeHorizontalLayout<Leading: View, Trailing: View, Legacy: View>: View {
    @EnvironmentObject private var vm: BoringViewModel

    let leadingWidth: CGFloat
    let trailingWidth: CGFloat
    let spacing: CGFloat
    private let leading: Leading
    private let trailing: Trailing
    private let legacy: Legacy

    init(
        leadingWidth: CGFloat,
        trailingWidth: CGFloat,
        spacing: CGFloat,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder legacy: () -> Legacy
    ) {
        self.leadingWidth = leadingWidth
        self.trailingWidth = trailingWidth
        self.spacing = spacing
        self.leading = leading()
        self.trailing = trailing()
        self.legacy = legacy()
    }

    private var wingWidth: CGFloat {
        NotchSafeLayoutMetrics.wingWidth(
            leading: leadingWidth,
            trailing: trailingWidth
        )
    }

    @ViewBuilder
    var body: some View {
        if vm.hasPhysicalNotch {
            HStack(spacing: spacing) {
                leading
                    .frame(width: wingWidth, alignment: .trailing)

                Rectangle()
                    .fill(.black)
                    .frame(width: vm.physicalNotchExclusionWidth)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                trailing
                    .frame(width: wingWidth, alignment: .leading)
            }
        } else {
            legacy
        }
    }
}

struct NotchSafeInteractionShape: Shape {
    let exclusionWidth: CGFloat
    let exclusionHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        let safeWidth = min(max(0, exclusionWidth), rect.width)
        let safeHeight = min(max(0, exclusionHeight), rect.height)

        guard safeWidth > 0, safeHeight > 0 else {
            return Path(rect)
        }

        let exclusionMinX = rect.midX - (safeWidth / 2)
        let exclusionMaxX = rect.midX + (safeWidth / 2)
        var path = Path()

        path.addRect(
            CGRect(
                x: rect.minX,
                y: rect.minY,
                width: max(0, exclusionMinX - rect.minX),
                height: safeHeight
            )
        )
        path.addRect(
            CGRect(
                x: exclusionMaxX,
                y: rect.minY,
                width: max(0, rect.maxX - exclusionMaxX),
                height: safeHeight
            )
        )

        if rect.height > safeHeight {
            path.addRect(
                CGRect(
                    x: rect.minX,
                    y: rect.minY + safeHeight,
                    width: rect.width,
                    height: rect.height - safeHeight
                )
            )
        }

        return path
    }
}

@MainActor func getScreenFrame(_ screenUUID: String? = nil) -> CGRect? {
    var selectedScreen = NSScreen.main

    if let uuid = screenUUID {
        selectedScreen = NSScreen.screen(withUUID: uuid)
    }
    
    if let screen = selectedScreen {
        return screen.frame
    }
    
    return nil
}

@MainActor func getClosedNotchSize(screenUUID: String? = nil) -> CGSize {
    // Default notch size, to avoid using optionals
    var notchHeight: CGFloat = Defaults[.nonNotchHeight]
    var notchWidth: CGFloat = 185

    var selectedScreen = NSScreen.main

    if let uuid = screenUUID {
        selectedScreen = NSScreen.screen(withUUID: uuid)
    }

    // Check if the screen is available
    if let screen = selectedScreen {
        // Calculate and set the exact width of the notch
        if let topLeftNotchpadding: CGFloat = screen.auxiliaryTopLeftArea?.width,
           let topRightNotchpadding: CGFloat = screen.auxiliaryTopRightArea?.width
        {
            notchWidth = screen.frame.width - topLeftNotchpadding - topRightNotchpadding + 4
        }

        // Check if the Mac has a notch
        if screen.safeAreaInsets.top > 0 {
            // This is a display WITH a notch - use notch height settings
            notchHeight = Defaults[.notchHeight]
            if Defaults[.notchHeightMode] == .matchRealNotchSize {
                notchHeight = screen.safeAreaInsets.top
            } else if Defaults[.notchHeightMode] == .matchMenuBar {
                notchHeight = screen.frame.maxY - screen.visibleFrame.maxY
            }
        } else {
            // This is a display WITHOUT a notch - use non-notch height settings
            notchHeight = Defaults[.nonNotchHeight]
            if Defaults[.nonNotchHeightMode] == .matchMenuBar {
                notchHeight = screen.frame.maxY - screen.visibleFrame.maxY
            }
        }
    }

    return .init(width: notchWidth, height: notchHeight)
}
