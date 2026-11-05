import SwiftUI

struct HabitsView: View {
    @Environment(\.aboLifeStyle) private var designStyle
    @StateObject private var store: HabitsStore

    init(database: AppDatabase?) {
        _store = StateObject(wrappedValue: HabitsStore(database: database))
    }

    var body: some View {
        ZStack {
            AboLifePremiumBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    dailyOverview
                    habitGrid
                    weeklyOverview
                }
                .aboLifePage()
            }
        }
        .navigationTitle("")
        .onAppear {
            store.reload()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Gewohnheiten")
                    .font(AboLifeTypography.dashboardTitle)
                    .foregroundStyle(designStyle.colors.primaryText)

                Text(store.dateSubtitle)
                    .font(AboLifeTypography.body)
                    .foregroundStyle(designStyle.colors.secondaryText)
            }

            Spacer()

            DatePicker("", selection: $store.selectedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .frame(width: 132)

            Button {
                store.selectToday()
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(.bordered)
            .help("Heute").accessibilityLabel("Heute")
            .disabled(store.isToday)

            Button {
                store.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(.bordered)
            .help("Neu laden").accessibilityLabel("Neu laden")
        }
    }

    private var dailyOverview: some View {
        AboLifeCard(isProminent: true) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 24) {
                    overviewCopy
                    Spacer(minLength: 0)
                    habitRing(size: 152, lineWidth: 8)
                }

                VStack(alignment: .leading, spacing: 16) {
                    overviewCopy
                    habitRing(size: 136, lineWidth: 8)
                }
            }
        }
    }

    private func habitRing(size: CGFloat, lineWidth: CGFloat) -> some View {
        CoreRingView(
            progress: store.dailyProgressPercent,
            lineWidth: lineWidth,
            tint: designStyle.colors.habits,
            valueText: "\(Int((store.dailyProgressPercent * 100).rounded()))%",
            labelText: "Heute"
        )
        .frame(width: size, height: size)
    }

    private var overviewCopy: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tagesziele")
                .font(AboLifeTypography.cardTitle)
                .foregroundStyle(designStyle.colors.secondaryText)

            Text("\(store.completedHabits) von \(store.totalHabits) erreicht")
                .font(AboLifeTypography.heroMessage)
                .foregroundStyle(designStyle.colors.primaryText)
                .monospacedDigit()

            Text(store.statusMessage)
                .font(AboLifeTypography.body)
                .foregroundStyle(designStyle.colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if !store.focusHabits.isEmpty {
                HStack(spacing: 8) {
                    ForEach(store.focusHabits) { habit in
                        Label(habit.title, systemImage: habit.systemImage)
                            .font(AboLifeTypography.caption)
                            .foregroundStyle(designStyle.colors.secondaryText)
                    }
                }
            }

            Text("\(store.weeklyCompletedScore) / \(store.weeklyTotalScore) diese Woche")
                .font(AboLifeTypography.caption)
                .foregroundStyle(designStyle.colors.secondaryText)
                .monospacedDigit()
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    private var habitGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Heute", systemImage: "square.grid.2x2.fill")
                    .font(AboLifeTypography.sectionTitle)
                    .foregroundStyle(designStyle.colors.primaryText)

                Spacer()

                if let errorMessage = store.errorMessage {
                    Text(errorMessage)
                        .font(AboLifeTypography.caption)
                        .foregroundStyle(designStyle.colors.habits)
                        .lineLimit(1)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
                ForEach(store.habits) { habit in
                    HabitMetricCard(
                        habit: habit,
                        value: store.value(for: habit),
                        progress: store.progress(for: habit),
                        weekHistory: store.weekHistory(for: habit),
                        increment: { store.incrementValue(for: habit) },
                        decrement: { store.decrementValue(for: habit) },
                        toggle: { store.toggleBooleanHabit(habit) }
                    )
                }
            }
        }
    }

    private var weeklyOverview: some View {
        AboLifeCard(isProminent: true) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 22) {
                    weeklySummaryCopy
                    WeeklyHabitBars(days: store.weeklyDayProgress)
                        .frame(maxWidth: 430)
                    goalsList
                }

                VStack(alignment: .leading, spacing: 16) {
                    weeklySummaryCopy
                    WeeklyHabitBars(days: store.weeklyDayProgress)
                    goalsList
                }
            }
        }
    }

    private var weeklySummaryCopy: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("Diese Woche", systemImage: "calendar.badge.clock")
                .font(AboLifeTypography.cardTitle)
                .foregroundStyle(designStyle.colors.primaryText)

            Text("\(Int((store.weeklyProgressPercent * 100).rounded()))%")
                .font(AboLifeTypography.heroMessage)
                .foregroundStyle(designStyle.colors.primaryText)
                .monospacedDigit()

            Text("Wochendurchschnitt")
                .font(AboLifeTypography.caption)
                .foregroundStyle(designStyle.colors.secondaryText)
        }
        .frame(minWidth: 150, alignment: .leading)
    }

    private var goalsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ziele")
                .font(AboLifeTypography.cardTitle)
                .foregroundStyle(designStyle.colors.primaryText)

            ForEach(store.habits) { habit in
                Text(goalText(for: habit))
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(designStyle.colors.secondaryText)
                    .lineLimit(1)
            }
        }
        .frame(minWidth: 180, alignment: .leading)
    }

    private func goalText(for habit: FixedHabit) -> String {
        if habit.isDerived {
            return "\(habit.title): Aus Workouts"
        }
        if habit.isBoolean {
            return "\(habit.title): Jeden Abend"
        }
        if habit.key == "water" {
            return "\(habit.title): 3,0 \(habit.unit)"
        }
        return "\(habit.title): \(Int(habit.targetValue.rounded())) \(habit.unit)"
    }
}

private struct HabitMetricCard: View {
    @Environment(\.aboLifeStyle) private var designStyle
    let habit: FixedHabit
    let value: Double
    let progress: Double
    let weekHistory: [HabitDayProgress]
    let increment: () -> Void
    let decrement: () -> Void
    let toggle: () -> Void

    var body: some View {
        AboLifeCard(minHeight: 214) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: habit.systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(habit.accent)
                        .frame(width: 36, height: 36)
                        .background(habit.accent.opacity(0.15), in: Circle())
                        .overlay {
                            Circle()
                                .strokeBorder(designStyle.colors.glassStrokeMuted, lineWidth: 0.7)
                        }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(habit.title)
                            .font(AboLifeTypography.body.weight(.semibold))
                            .foregroundStyle(designStyle.colors.primaryText)
                            .lineLimit(1)

                        Text("\(Int((progress * 100).rounded()))%")
                            .font(AboLifeTypography.caption)
                            .foregroundStyle(habit.accent)
                            .monospacedDigit()
                    }

                    Spacer()
                }

                Text(habit.isBoolean || habit.isDerived ? (progress >= 1 ? "1 / 1" : "0 / 1") : habit.displayValue(value))
                    .font(AboLifeTypography.metric)
                    .foregroundStyle(designStyle.colors.primaryText)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                PremiumProgressBar(progress: progress, tint: habit.accent, height: 7)

                HabitWeekDots(days: weekHistory, tint: habit.accent)

                if habit.isDerived {
                    AboLifeGlassCapsule {
                        Label(progress >= 1 ? "Training erledigt" : "Aus Workouts", systemImage: progress >= 1 ? "checkmark.circle" : "arrow.triangle.2.circlepath")
                            .font(AboLifeTypography.micro)
                            .foregroundStyle(habit.accent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else if habit.isBoolean {
                    Button {
                        toggle()
                    } label: {
                        Label(progress >= 1 ? "Offen" : "Erledigt", systemImage: progress >= 1 ? "circle" : "checkmark.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(designStyle.colors.action)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(spacing: 8) {
                        HabitStepButton(systemImage: "minus", label: stepLabel, action: decrement)
                            .disabled(value <= 0)

                        HabitStepButton(systemImage: "plus", label: stepLabel, action: increment)
                    }
                }
            }
        }
    }

    private var stepLabel: String {
        if habit.key == "water" {
            return "0,25 \(habit.unit)"
        }
        return "\(Int(habit.stepValue.rounded())) \(habit.unit)"
    }
}

private struct HabitStepButton: View {
    @Environment(\.aboLifeStyle) private var designStyle
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: systemImage)
                .font(AboLifeTypography.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }
}

private struct HabitWeekDots: View {
    @Environment(\.aboLifeStyle) private var designStyle
    let days: [HabitDayProgress]
    let tint: Color

    var body: some View {
        HStack(spacing: 7) {
            ForEach(days) { day in
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .strokeBorder(designStyle.colors.glassStrokeMuted, lineWidth: 1)
                            .frame(width: 15, height: 15)

                        Circle()
                            .trim(from: 0, to: day.progress)
                            .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 15, height: 15)

                        if day.progress >= 1 {
                            Circle()
                                .fill(tint.opacity(0.38))
                                .frame(width: 7, height: 7)
                        }
                    }
                    .overlay {
                        if day.isToday {
                            Circle()
                                .strokeBorder(tint.opacity(0.78), lineWidth: 1)
                                .frame(width: 20, height: 20)
                        }
                    }

                    Text(day.label.prefix(2))
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(day.isToday ? tint : designStyle.colors.tertiaryText)
                        .frame(width: 24)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct WeeklyHabitBars: View {
    @Environment(\.aboLifeStyle) private var designStyle
    let days: [HabitDayProgress]

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(days) { day in
                VStack(spacing: 6) {
                    GeometryReader { proxy in
                        let height = proxy.size.height * CGFloat(min(max(day.progress, 0), 1))
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(designStyle.colors.quietFill)
                            .overlay(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(day.isToday ? designStyle.colors.habits : designStyle.colors.secondaryText.opacity(0.48))
                                    .frame(height: height)
                            }
                    }
                    .frame(height: 72)

                    Text(day.label.prefix(2))
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(day.isToday ? designStyle.colors.habits : designStyle.colors.tertiaryText)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct HabitsView_Previews: PreviewProvider {
    static var previews: some View {
        HabitsView(database: nil)
            .frame(width: 1000, height: 760)
    }
}
