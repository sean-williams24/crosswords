//  Triangle.swift

import SwiftUI

struct Triangle: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()

        let topMiddle = CGPoint(x: rect.midX, y: rect.minY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)

        path.move(to: bottomLeft)
        path.addLine(to: bottomRight)

        path.addArc(
            center: CGPoint(x: topMiddle.x, y: topMiddle.y),
            radius: 0,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: true
        )

        path.addLine(to: bottomLeft)

        return path
    }
}
