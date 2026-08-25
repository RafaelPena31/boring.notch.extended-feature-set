//
//  MediaProgressBar.swift
//  boringNotch
//

import Defaults
import SwiftUI

struct MediaProgressBar: View {
    @ObservedObject private var musicManager = MusicManager.shared
    @Default(.mediaProgressBarThickness) private var thickness
    @Default(.mediaProgressBarColor) private var colorSource

    let topCornerRadius: CGFloat
    let bottomCornerRadius: CGFloat
    var isVisible: Bool = true

    private var tint: Color {
        switch colorSource {
        case .albumArt:
            Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.6)
        case .white:
            .white
        case .accent:
            .effectiveAccent
        }
    }

    var body: some View {
        if isVisible {
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                progressRibbon(at: context.date)
            }
        } else {
            progressRibbon(at: .now)
        }
    }

    private func progressRibbon(at date: Date) -> some View {
        let duration = musicManager.songDuration
        let position = musicManager.estimatedPlaybackPosition(at: date)
        let fraction = duration.isFinite && duration > 0
            ? min(max(position / duration, 0), 1)
            : 0

        return TaperedNotchProgress(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: bottomCornerRadius,
            thickness: CGFloat(thickness),
            fraction: CGFloat(fraction)
        )
        .fill(tint)
    }
}

struct TaperedNotchProgress: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat
    var thickness: CGFloat
    var fraction: CGFloat

    func path(in rect: CGRect) -> Path {
        let normalizedFraction = min(max(fraction, 0), 1)
        guard normalizedFraction > 0, thickness > 0 else { return Path() }

        let start = CGPoint(
            x: rect.minX + topCornerRadius,
            y: rect.maxY - bottomCornerRadius
        )
        let bottomLeft = CGPoint(
            x: rect.minX + topCornerRadius + bottomCornerRadius,
            y: rect.maxY
        )
        let bottomLeftControl = CGPoint(
            x: rect.minX + topCornerRadius,
            y: rect.maxY
        )
        let bottomRight = CGPoint(
            x: rect.maxX - topCornerRadius - bottomCornerRadius,
            y: rect.maxY
        )
        let end = CGPoint(
            x: rect.maxX - topCornerRadius,
            y: rect.maxY - bottomCornerRadius
        )
        let bottomRightControl = CGPoint(
            x: rect.maxX - topCornerRadius,
            y: rect.maxY
        )

        var contour: [CGPoint] = []
        appendQuadraticCurve(
            from: start,
            control: bottomLeftControl,
            to: bottomLeft,
            steps: 12,
            includeFirst: true,
            points: &contour
        )
        appendLine(from: bottomLeft, to: bottomRight, steps: 16, points: &contour)
        appendQuadraticCurve(
            from: bottomRight,
            control: bottomRightControl,
            to: end,
            steps: 12,
            includeFirst: false,
            points: &contour
        )

        var cumulativeLength: [CGFloat] = [0]
        for index in 1..<contour.count {
            cumulativeLength.append(
                cumulativeLength[index - 1]
                    + hypot(
                        contour[index].x - contour[index - 1].x,
                        contour[index].y - contour[index - 1].y
                    )
            )
        }
        guard let totalLength = cumulativeLength.last, totalLength > 0 else { return Path() }

        let targetLength = normalizedFraction * totalLength
        let partial = partialContour(
            contour,
            cumulativeLength: cumulativeLength,
            targetLength: targetLength
        )
        guard partial.points.count >= 2 else { return Path() }

        let maximumHalfWidth = thickness / 2
        let taperLength = min(14, totalLength / 2)
        var firstEdge: [CGPoint] = []
        var secondEdge: [CGPoint] = []

        for index in partial.points.indices {
            let previous = partial.points[max(0, index - 1)]
            let next = partial.points[min(partial.points.count - 1, index + 1)]
            var tangentX = next.x - previous.x
            var tangentY = next.y - previous.y
            let tangentLength = hypot(tangentX, tangentY)
            if tangentLength > 0 {
                tangentX /= tangentLength
                tangentY /= tangentLength
            }

            let arcLength = partial.arcLengths[index]
            let rampIn = min(arcLength / taperLength, 1)
            let rampOut = min((totalLength - arcLength) / taperLength, 1)
            let halfWidth = maximumHalfWidth * max(0, min(rampIn, rampOut))

            firstEdge.append(
                CGPoint(
                    x: partial.points[index].x - tangentY * halfWidth,
                    y: partial.points[index].y + tangentX * halfWidth
                )
            )
            secondEdge.append(
                CGPoint(
                    x: partial.points[index].x + tangentY * halfWidth,
                    y: partial.points[index].y - tangentX * halfWidth
                )
            )
        }

        var path = Path()
        path.move(to: firstEdge[0])
        for point in firstEdge.dropFirst() { path.addLine(to: point) }
        for point in secondEdge.reversed() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }

    private func partialContour(
        _ contour: [CGPoint],
        cumulativeLength: [CGFloat],
        targetLength: CGFloat
    ) -> (points: [CGPoint], arcLengths: [CGFloat]) {
        var points: [CGPoint] = []
        var arcLengths: [CGFloat] = []

        for index in contour.indices {
            if cumulativeLength[index] <= targetLength {
                points.append(contour[index])
                arcLengths.append(cumulativeLength[index])
                continue
            }

            let previousIndex = index - 1
            let segmentLength = cumulativeLength[index] - cumulativeLength[previousIndex]
            let progress = segmentLength > 0
                ? (targetLength - cumulativeLength[previousIndex]) / segmentLength
                : 0
            points.append(
                CGPoint(
                    x: contour[previousIndex].x
                        + (contour[index].x - contour[previousIndex].x) * progress,
                    y: contour[previousIndex].y
                        + (contour[index].y - contour[previousIndex].y) * progress
                )
            )
            arcLengths.append(targetLength)
            break
        }
        return (points, arcLengths)
    }

    private func appendQuadraticCurve(
        from start: CGPoint,
        control: CGPoint,
        to end: CGPoint,
        steps: Int,
        includeFirst: Bool,
        points: inout [CGPoint]
    ) {
        for index in (includeFirst ? 0 : 1)...steps {
            let progress = CGFloat(index) / CGFloat(steps)
            let inverse = 1 - progress
            points.append(
                CGPoint(
                    x: inverse * inverse * start.x
                        + 2 * inverse * progress * control.x
                        + progress * progress * end.x,
                    y: inverse * inverse * start.y
                        + 2 * inverse * progress * control.y
                        + progress * progress * end.y
                )
            )
        }
    }

    private func appendLine(
        from start: CGPoint,
        to end: CGPoint,
        steps: Int,
        points: inout [CGPoint]
    ) {
        for index in 1...steps {
            let progress = CGFloat(index) / CGFloat(steps)
            points.append(
                CGPoint(
                    x: start.x + (end.x - start.x) * progress,
                    y: start.y + (end.y - start.y) * progress
                )
            )
        }
    }
}
