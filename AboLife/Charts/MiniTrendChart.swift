import SwiftUI

struct MiniTrendChart: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let points = normalizedPoints(in: proxy.size)

            ZStack {
                Path { path in
                    let midY = proxy.size.height * 0.64
                    path.move(to: CGPoint(x: 0, y: midY))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: midY))
                }
                .stroke(AboLifeColors.glassStrokeMuted, style: StrokeStyle(lineWidth: 0.8, dash: [3, 8]))

                areaPath(points: points, size: proxy.size)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.16),
                                tint.opacity(0.05),
                                tint.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                linePath(points: points)
                    .stroke(AboLifeColors.premiumGradient(for: tint), style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round))

                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    if index == points.count - 1 {
                        Circle()
                            .fill(Color.white.opacity(0.72))
                            .frame(width: 4.5, height: 4.5)
                            .overlay {
                                Circle()
                                    .stroke(tint.opacity(0.72), lineWidth: 1.5)
                            }
                            .shadow(color: tint.opacity(0.14), radius: 4, x: 0, y: 0)
                            .position(point)
                    }
                }
            }
        }
        .frame(height: 34)
        .accessibilityHidden(true)
    }

    private func linePath(points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)

            for index in 1..<points.count {
                let previous = points[index - 1]
                let current = points[index]
                let midpoint = CGPoint(
                    x: (previous.x + current.x) / 2,
                    y: (previous.y + current.y) / 2
                )
                path.addQuadCurve(to: midpoint, control: previous)

                if index == points.count - 1 {
                    path.addQuadCurve(to: current, control: current)
                }
            }
        }
    }

    private func areaPath(points: [CGPoint], size: CGSize) -> Path {
        var path = linePath(points: points)

        if let last = points.last, let first = points.first {
            path.addLine(to: CGPoint(x: last.x, y: size.height))
            path.addLine(to: CGPoint(x: first.x, y: size.height))
            path.closeSubpath()
        }

        return path
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }

        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let range = max(maxValue - minValue, 1)
        let step = size.width / CGFloat(values.count - 1)

        return values.enumerated().map { index, value in
            let x = CGFloat(index) * step
            let normalized = (value - minValue) / range
            let y = size.height - CGFloat(normalized) * (size.height - 12) - 6
            return CGPoint(x: x, y: y)
        }
    }
}
