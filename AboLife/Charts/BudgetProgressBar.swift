import SwiftUI

struct BudgetProgressBar: View {
    let spent: Double
    let budget: Double

    private var progress: Double {
        guard budget > 0 else { return 0 }
        return min(max(spent / budget, 0), 1)
    }

    private var isOverBudget: Bool {
        budget > 0 && spent > budget
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            PremiumProgressBar(
                progress: progress,
                tint: isOverBudget ? AboLifeColors.habits : AboLifeColors.finance,
                height: 8
            )

            HStack {
                Text("Ausgegeben")
                    .foregroundStyle(AboLifeColors.secondaryText)
                Spacer()
                Text("\(Int(spent)) EUR / \(Int(budget)) EUR")
                    .monospacedDigit()
                    .foregroundStyle(isOverBudget ? AboLifeColors.habits.opacity(0.76) : AboLifeColors.secondaryText)
            }
            .font(AboLifeTypography.caption)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Budget \(Int(progress * 100)) Prozent ausgeschöpft")
    }
}
