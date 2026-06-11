import SwiftUI

struct MetricProgressView: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AboLifeColors.subtleFill)

                Capsule()
                    .fill(tint)
                    .frame(width: max(8, proxy.size.width * min(max(progress, 0), 1)))
            }
        }
        .frame(height: 7)
    }
}

struct WeeklyStatusStrip: View {
    let days: [DashboardDayStatus]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(days) { day in
                VStack(spacing: 8) {
                    Text(day.shortName)
                        .font(AboLifeTypography.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 28)

                    ZStack {
                        Circle()
                            .fill(AboLifeColors.subtleFill)
                            .frame(width: 28, height: 28)

                        Circle()
                            .trim(from: 0, to: day.completion)
                            .stroke(day.tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 28, height: 28)
                    }
                }
            }
        }
    }
}
