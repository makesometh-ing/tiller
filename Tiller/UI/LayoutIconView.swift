//
//  LayoutIconView.swift
//  Tiller
//

import SwiftUI

struct LayoutIconView: View {
    let layout: LayoutID
    let isActive: Bool
    var size: CGSize = CGSize(width: 28, height: 18)

    // Geometry is defined in a 48×32 viewBox (matching Paper mockup SVGs),
    // then scaled to the actual display size.
    private static let viewBoxWidth: CGFloat = 48
    private static let viewBoxHeight: CGFloat = 32

    var body: some View {
        Canvas { context, canvasSize in
            let scaleX = canvasSize.width / Self.viewBoxWidth
            let scaleY = canvasSize.height / Self.viewBoxHeight
            let scale = min(scaleX, scaleY)
            let strokeColor: Color = isActive ? .white : .white.opacity(0.4)
            let lineWidth: CGFloat = 2.5 * scale

            for pane in paneRects {
                let scaledRect = CGRect(
                    x: pane.rect.origin.x * scaleX,
                    y: pane.rect.origin.y * scaleY,
                    width: pane.rect.size.width * scaleX,
                    height: pane.rect.size.height * scaleY
                )
                let path = RoundedRectangle(cornerRadius: pane.cornerRadius * scale)
                    .path(in: scaledRect)
                context.stroke(path, with: .color(strokeColor), lineWidth: lineWidth)
            }
        }
        .frame(width: size.width, height: size.height)
        .accessibilityLabel(layout.displayName)
    }

    // MARK: - Pane Geometry (in viewBox coordinates)

    private var paneRects: [PaneRect] {
        switch layout {
        case .monocle:
            return [
                PaneRect(rect: CGRect(x: 2, y: 2, width: 44, height: 28), cornerRadius: 5),
            ]
        case .splitHalves:
            return [
                PaneRect(rect: CGRect(x: 2, y: 2, width: 20.5, height: 28), cornerRadius: 4),
                PaneRect(rect: CGRect(x: 25.5, y: 2, width: 20.5, height: 28), cornerRadius: 4),
            ]
        }
    }
}

private struct PaneRect {
    let rect: CGRect
    let cornerRadius: CGFloat
}
