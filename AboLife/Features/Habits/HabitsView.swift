import SwiftUI

struct HabitsView: View {
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
                .padding(22)
            }
        }
        .navigationTitle("")
        .onAppear {
            store.reload()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Gewohnheiten")
                    .font(AboLifeTypography.dashboardTitle)
                    .foregroundStyle(AboLifeColors.primaryText)

                Text(store.dateSubtitle)
                    .font(AboLifeTypography.body)
                    .foregroundStyle(AboLifeColors.secondaryText)
            }

            Spacer()

            AboLifeGlassCapsule {
                Text("\(store.completedHabits) / \(store.totalHabits) heute")
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(AboLifeColors.habits)
                    .monospacedDigit()
            }

            DatePicker("", selection: $store.selectedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .frame(width: 132)

            Button {
                store.selectToday()
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .help("Heute")
            .disabled(store.isToday)

            Button {
                store.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .help("Neu laden")
        }
    }

    private var dailyOverview: some View {
        AboLifeCard(isProminent: true) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 28) {
                    habitRing(size: 176, lineWidth: 15)
                    overviewCopy
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 18) {
                    habitRing(size: 154, lineWidth: 13)
                    overviewCopy
                }
            }
        }
    }

    private func habitRing(size: CGFloat, lineWidth: CGFloat) -> some View {
        CoreRingView(
            progress: store.dailyProgressPercent,
            lineWidth: lineWidth,
            tint: AboLifeColors.habits,
            valueText: "\(Int((store.dailyProgressPercent * 100).rounded()))%",
            labelText: "Heute"
        )
        .frame(width: size, height: size)
    }

    private var overviewCopy: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                Label("Tagesring", systemImage: "circle.hexagongrid.fill")
                    .font(AboLifeTypography.cardTitle)
                    .foregroundStyle(AboLifeColors.primaryText)

                AboLifeGlassCapsule {
                    Text("\(store.completedHabits) / \(store.totalHabits) Ziele erreicht")
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(AboLifeColors.habits)
                        .monospacedDigit()
                }
            }

            Text("Gewohnheiten im Fluss")
                .font(AboLifeTypography.heroMessage)
                .foregroundStyle(AboLifeColors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            PremiumProgressBar(progress: store.dailyProgressPercent, tint: AboLifeColors.habits, height: 8)
                .frame(maxWidth: 430)

            Text(store.statusMessage)
                .font(AboLifeTypography.body)
                .foregroundStyle(AboLifeColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if !store.focusHabits.isEmpty {
                HStack(spacing: 8) {
                    ForEach(store.focusHabits) { habit in
                        AboLifeGlassCapsule {
                            Label(habit.title, systemImage: habit.systemImage)
                                .font(AboLifeTypography.micro)
                                .foregroundStyle(habit.accent)
                        }
                    }
                }
            }

            Text("\(store.weeklyCompletedScore) / \(store.weeklyTotalScore) diese Woche")
                .font(AboLifeTypography.caption)
                .foregroundStyle(AboLifeColors.secondaryText)
                .monospacedDigit()
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    private var habitGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Heute", systemImage: "square.grid.2x2.fill")
                    .font(AboLifeTypography.sectionTitle)
                    .foregroundStyle(AboLifeColors.primaryText)

                Spacer()

                if let errorMessage = store.errorMessage {
                    Text(errorMessage)
                        .font(AboLifeTypography.caption)
                        .foregroundStyle(AboLifeColors.habits)
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
                .foregroundStyle(AboLifeColors.primaryText)

            Text("\(Int((store.weeklyProgressPercent * 100).rounded()))%")
                .font(AboLifeTypography.heroMessage)
                .foregroundStyle(AboLifeColors.primaryText)
                .monospacedDigit()

            Text("Wochendurchschnitt")
                .font(AboLifeTypography.caption)
                .foregroundStyle(AboLifeColors.secondaryText)
        }
        .frame(minWidth: 150, alignment: .leading)
    }

    private var goalsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ziele")
                .font(AboLifeTypography.cardTitle)
                .foregroundStyle(AboLifeColors.primaryText)

            ForEach(store.habits) { habit in
                Text(goalText(for: habit))
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(AboLifeColors.secondaryText)
                    .lineLimit(1)
            }
        }
        .frame(minWidth: 180, alignment: .leading)
    }

    private func goalText(for habit: FixedHabit) -> String {
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
                                .strokeBorder(AboLifeColors.glassStrokeMuted, lineWidth: 0.7)
                        }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(habit.title)
                            .font(AboLifeTypography.body.weight(.semibold))
                            .foregroundStyle(AboLifeColors.primaryText)
                            .lineLimit(1)

                        Text("\(Int((progress * 100).rounded()))%")
                            .font(AboLifeTypography.caption)
                            .foregroundStyle(habit.accent)
                            .monospacedDigit()
                    }

                    Spacer()
                }

                Text(habit.isBoolean ? (progress >= 1 ? "1 / 1" : "0 / 1") : habit.displayValue(value))
                    .font(AboLifeTypography.metric)
                    .foregroundStyle(AboLifeColors.primaryText)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                PremiumProgressBar(progress: progress, tint: habit.accent, height: 7)

                HabitWeekDots(days: weekHistory, tint: habit.accent)

                if habit.isBoolean {
                    Button {
                        toggle()
                    } label: {
                        Label(progress >= 1 ? "Offen" : "Erledigt", systemImage: progress >= 1 ? "circle" : "checkmark.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(habit.accent)
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
    let days: [HabitDayProgress]
    let tint: Color

    var body: some View {
        HStack(spacing: 7) {
            ForEach(days) { day in
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .strokeBorder(AboLifeColors.glassStrokeMuted, lineWidth: 1)
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

                    Text(day.label.prefix(2).uppercased())
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(day.isToday ? tint : AboLifeColors.tertiaryText)
                        .frame(width: 24)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct WeeklyHabitBars: View {
    let days: [HabitDayProgress]

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(days) { day in
                VStack(spacing: 6) {
                    GeometryReader { proxy in
                        let height = max(proxy.size.height * CGFloat(day.progress), 3)
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(AboLifeColors.quietFill)
                            .overlay(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(AboLifeColors.premiumGradient(for: AboLifeColors.habits))
                                    .frame(height: height)
                            }
                    }
                    .frame(height: 72)

                    Text(day.label.prefix(2).uppercased())
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(day.isToday ? AboLifeColors.habits : AboLifeColors.tertiaryText)
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
