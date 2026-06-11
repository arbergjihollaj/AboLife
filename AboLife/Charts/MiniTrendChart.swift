import SwiftUI

struct MiniTrendChart: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let points = normalizedPoints(in: proxy.size)

            Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                Circle()
                    .fill(tint)
                    .frame(width: 5, height: 5)
                    .position(point)
            }
        }
        .frame(height: 42)
        .accessibilityHidden(true)
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
            let y = size.height - CGFloat(normalized) * size.height
            return CGPoint(x: x, y: y)
        }
    }
}
