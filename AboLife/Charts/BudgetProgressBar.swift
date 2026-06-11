import SwiftUI

struct BudgetProgressBar: View {
    let spent: Double
    let budget: Double

    private var progress: Double {
        guard budget > 0 else { return 0 }
        return min(max(spent / budget, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MetricProgressView(progress: progress, tint: AboLifeColors.finance)

            HStack {
                Text("Ausgegeben")
                Spacer()
                Text("\(Int(spent)) EUR / \(Int(budget)) EUR")
                    .monospacedDigit()
            }
            .font(AboLifeTypography.caption)
            .foregroundStyle(.secondary)
        }
    }
}
