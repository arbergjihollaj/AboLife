import Charts
import SwiftUI

struct MiniTrendChart: View {
    let values: [Double]
    let tint: Color

    private var points: [Double] { values.filter(\.isFinite) }

    var body: some View {
        let points = points
        let minimum = points.min() ?? 0
        let maximum = points.max() ?? 1
        let padding = max((maximum - minimum) * 0.1, 0.5)
        Chart {
            ForEach(points.indices, id: \.self) { index in
                LineMark(x: .value("Zeitpunkt", index), y: .value("Wert", points[index]))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(tint)
            }
            if let last = points.last {
                PointMark(x: .value("Zeitpunkt", points.count - 1), y: .value("Wert", last))
                    .symbolSize(18)
                    .foregroundStyle(tint)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartYScale(domain: (minimum - padding)...(maximum + padding))
        .frame(height: 36)
        .aboLifeMotion(value: values)
        .accessibilityHidden(true)
    }
}
