import SwiftUI

struct TrainingView: View {
    @StateObject private var store: TrainingStore
    @State private var checklistState = HomeWorkoutChecklistState()

    init(database: AppDatabase?) {
        _store = StateObject(wrappedValue: TrainingStore(database: database))
    }

    var body: some View {
        ZStack {
            AboLifePremiumBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    homeWorkoutPlanSection
                    progressionSection
                    bodyProgressSection
                    statisticsSection
                    nutritionSection
                    goalsSection
                    weeklyOverview
                    weekStrip
                    sessionsSection
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
                Text("Training")
                    .font(AboLifeTypography.dashboardTitle)
                    .foregroundStyle(AboLifeColors.primaryText)

                Text("Diese Woche · \(store.weekSubtitle)")
                    .font(AboLifeTypography.body)
                    .foregroundStyle(AboLifeColors.secondaryText)
            }

            Spacer()

            Button {
                store.selectCurrentWeek()
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .help("Diese Woche")
            .disabled(store.isCurrentWeek)

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

    private var homeWorkoutPlanSection: some View {
        let scheduledWorkout = store.scheduledHomeWorkout
        let workout = scheduledWorkout.day
        let exercises = workout.exercises(for: checklistState.selectedIntensity)
        let checkedCount = checklistState.checkedExerciseCount

        return AboLifeCard(isProminent: true) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Home-Trainingsplan", systemImage: "house.and.flag")
                            .font(AboLifeTypography.cardTitle)
                            .foregroundStyle(AboLifeColors.primaryText)

                        Text("Körpergewicht + Klimmzugstange")
                            .font(AboLifeTypography.caption)
                            .foregroundStyle(AboLifeColors.secondaryText)
                    }

                    Spacer()

                    AboLifeGlassCapsule {
                        Text(checklistState.selectedIntensity.timeRange)
                            .font(AboLifeTypography.micro)
                            .foregroundStyle(AboLifeColors.training)
                            .monospacedDigit()
                    }
                }

                TrainingDoubleProgressRing(
                    weeklyProgress: store.progress,
                    dailyProgress: HomeWorkoutChecklistState.progress(
                        checkedExercises: checkedCount,
                        totalExercises: exercises.count
                    ),
                    checkedExercises: checkedCount,
                    totalExercises: exercises.count,
                    completedWorkouts: store.completedWorkoutsThisWeek,
                    weeklyWorkoutTarget: store.weeklyWorkoutTarget
                )
                .padding(.top, 4)
                .padding(.bottom, 2)

                VStack(alignment: .leading, spacing: 16) {
                    homeWorkoutSummary(scheduledWorkout)
                    exerciseChecklist(exercises)
                }
            }
        }
    }

    private func homeWorkoutSummary(_ scheduledWorkout: ScheduledHomeWorkout) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            VStack(alignment: .leading, spacing: 5) {
                Text(scheduledWorkout.headline)
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(AboLifeColors.secondaryText)
                    .textCase(.uppercase)

                Text(scheduledWorkout.day.name)
                    .font(AboLifeTypography.heroMessage)
                    .foregroundStyle(AboLifeColors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(scheduleText(for: scheduledWorkout))
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(AboLifeColors.secondaryText)
            }

            Text(scheduledWorkout.day.focusText)
                .font(AboLifeTypography.body)
                .foregroundStyle(AboLifeColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Intensität", selection: Binding(
                get: { checklistState.selectedIntensity },
                set: {
                    checklistState.setIntensity($0)
                    store.clearCompletionMessage()
                }
            )) {
                ForEach(HomeWorkoutIntensity.allCases) { intensity in
                    Text(intensity.rawValue).tag(intensity)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack(spacing: 10) {
                Button {
                    store.completeHomeWorkout(
                        intensity: checklistState.selectedIntensity,
                        completedExerciseIDs: checklistState.completedExerciseIDs
                    )
                    checklistState.resetCompletedExercises()
                } label: {
                    Label("Workout abschließen", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(AboLifeColors.training)
                .disabled(store.isSavingPlanWorkout)

                if let completionMessage = store.completionMessage {
                    Label(completionMessage, systemImage: "checkmark.circle")
                        .font(AboLifeTypography.caption)
                        .foregroundStyle(AboLifeColors.review)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func exerciseChecklist(_ exercises: [HomeWorkoutExercise]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Übungen")
                    .font(AboLifeTypography.caption.weight(.semibold))
                    .foregroundStyle(AboLifeColors.primaryText)

                Spacer()

                Text("\(checklistState.checkedExerciseCount) / \(exercises.count)")
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(AboLifeColors.secondaryText)
                    .monospacedDigit()
            }

            VStack(spacing: 8) {
                ForEach(exercises) { exercise in
                    Toggle(isOn: exerciseBinding(for: exercise.id)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name)
                                .font(AboLifeTypography.caption.weight(.semibold))
                                .foregroundStyle(AboLifeColors.primaryText)

                            Text(exercise.prescription)
                                .font(AboLifeTypography.micro)
                                .foregroundStyle(AboLifeColors.secondaryText)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AboLifeColors.quietFill)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(AboLifeColors.glassStrokeMuted, lineWidth: 0.6)
                            }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func exerciseBinding(for id: HomeWorkoutExercise.ID) -> Binding<Bool> {
        Binding(
            get: { checklistState.completedExerciseIDs.contains(id) },
            set: { isCompleted in
                checklistState.setExercise(id, isCompleted: isCompleted)
                store.clearCompletionMessage()
            }
        )
    }

    private func scheduleText(for scheduledWorkout: ScheduledHomeWorkout) -> String {
        if scheduledWorkout.isToday {
            return "Heute: \(scheduledWorkout.day.focusText)"
        }

        let dateText = scheduledWorkout.scheduledDate.formatted(.dateTime.day().month(.abbreviated))
        return "Nächstes Workout: \(scheduledWorkout.day.name) am \(scheduledWorkout.day.weekdayName), \(dateText)"
    }

    private var weeklyOverview: some View {
        AboLifeCard(isProminent: true) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 24) {
                    progressRing(size: 158, lineWidth: 14)
                    overviewCopy
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 18) {
                    progressRing(size: 142, lineWidth: 12)
                    overviewCopy
                }
            }
        }
    }

    private var progressionSection: some View {
        AboLifeCard(isProminent: true) {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(title: "Progression", systemImage: "chart.line.uptrend.xyaxis", value: "\(store.exerciseProgressions.count) Übungen")

                VStack(spacing: 10) {
                    ForEach(store.recommendations, id: \.id) { recommendation in
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: icon(for: recommendation.outcomeRawValue))
                                .foregroundStyle(color(for: recommendation.outcomeRawValue))
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(recommendation.exerciseName)
                                    .font(AboLifeTypography.body.weight(.semibold))
                                    .foregroundStyle(AboLifeColors.primaryText)

                                Text(recommendation.message)
                                    .font(AboLifeTypography.caption)
                                    .foregroundStyle(AboLifeColors.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 3) {
                                Text("Level \(recommendation.nextLevel)")
                                    .font(AboLifeTypography.caption.weight(.semibold))
                                    .foregroundStyle(AboLifeColors.primaryText)

                                Text("\(recommendation.nextTargetSets) x \(recommendation.nextTargetMinReps)-\(recommendation.nextTargetMaxReps)")
                                    .font(AboLifeTypography.micro)
                                    .foregroundStyle(AboLifeColors.tertiaryText)
                                    .monospacedDigit()
                            }
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 11)
                        .background(rowBackground)
                    }
                }
            }
        }
    }

    private var bodyProgressSection: some View {
        AboLifeCard {
            VStack(alignment: .leading, spacing: 13) {
                sectionHeader(title: "Körperentwicklung", systemImage: "figure.arms.open", value: store.bodyTrend.summary)

                HStack(spacing: 10) {
                    trendPill(title: "Bauch", value: centimeters(store.bodyTrend.waistChangeCm), tint: AboLifeColors.habits)
                    trendPill(title: "Brust", value: centimeters(store.bodyTrend.chestChangeCm), tint: AboLifeColors.training)
                    trendPill(title: "Arm", value: centimeters(store.bodyTrend.armChangeCm), tint: AboLifeColors.protein)
                    trendPill(title: "Max Pull", value: signedInt(store.bodyTrend.pullupChange), tint: AboLifeColors.review)
                }
            }
        }
    }

    private var statisticsSection: some View {
        AboLifeCard {
            VStack(alignment: .leading, spacing: 13) {
                sectionHeader(title: "Statistiken", systemImage: "gauge.with.dots.needle.bottom.50percent", value: "\(Int(store.trainingStatistics.trainingRate * 100))% Quote")

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 10)], spacing: 10) {
                    statTile("Diese Woche", "\(store.trainingStatistics.trainingsThisWeek)", "Workouts")
                    statTile("Streak", "\(store.trainingStatistics.currentStreak)", "Tage")
                    statTile("Gesamtvolumen", "\(store.trainingStatistics.totalVolume)", "Punkte")
                    statTile("Push", "\(store.trainingStatistics.pushVolume)", "Vol.")
                    statTile("Pull", "\(store.trainingStatistics.pullVolume)", "Vol.")
                    statTile("Beine", "\(store.trainingStatistics.legVolume)", "Vol.")
                    statTile("Stärkste Woche", "\(store.trainingStatistics.strongestWeek)", "Einheiten")
                }
            }
        }
    }

    private var nutritionSection: some View {
        AboLifeCard {
            VStack(alignment: .leading, spacing: 13) {
                sectionHeader(title: "Ernährung", systemImage: "fork.knife.circle", value: "Protein + Kalorien")

                HStack(spacing: 10) {
                    summaryPill(
                        title: "Protein",
                        value: "\(Int(store.nutritionStatus.currentProteinG.rounded())) / \(Int(store.nutritionStatus.proteinTargetG)) g",
                        systemImage: "bolt.heart",
                        tint: AboLifeColors.protein
                    )

                    summaryPill(
                        title: "Kalorien",
                        value: "\(store.nutritionStatus.currentCalories) kcal",
                        systemImage: "flame",
                        tint: AboLifeColors.nutrition
                    )
                }

                Text(store.nutritionStatus.message)
                    .font(AboLifeTypography.body)
                    .foregroundStyle(AboLifeColors.secondaryText)
            }
        }
    }

    private var goalsSection: some View {
        AboLifeCard {
            VStack(alignment: .leading, spacing: 13) {
                sectionHeader(title: "Ziele", systemImage: "target", value: "Muskelaufbau")

                HStack(spacing: 10) {
                    ForEach(store.motivationCards) { card in
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: card.systemImage)
                                .foregroundStyle(AboLifeColors.training)

                            Text(card.title)
                                .font(AboLifeTypography.caption.weight(.semibold))
                                .foregroundStyle(AboLifeColors.primaryText)

                            Text(card.detail)
                                .font(AboLifeTypography.micro)
                                .foregroundStyle(AboLifeColors.secondaryText)
                                .lineLimit(2)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 98, alignment: .leading)
                        .background(rowBackground)
                    }
                }
            }
        }
    }

    private func progressRing(size: CGFloat, lineWidth: CGFloat) -> some View {
        CoreRingView(
            progress: store.progress,
            lineWidth: lineWidth,
            tint: AboLifeColors.training,
            valueText: "\(Int(store.progress * 100))%",
            labelText: "Wochenziel"
        )
        .frame(width: size, height: size)
    }

    private var overviewCopy: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label("Wochenfokus", systemImage: "figure.strengthtraining.traditional")
                    .font(AboLifeTypography.cardTitle)
                    .foregroundStyle(AboLifeColors.primaryText)

                AboLifeGlassCapsule {
                    Text("\(Int(store.progress * 100))%")
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(AboLifeColors.training)
                        .monospacedDigit()
                }
            }

            Text("\(store.completedWorkoutsThisWeek) / \(store.weeklyWorkoutTarget) Workouts")
                .font(AboLifeTypography.heroMessage)
                .foregroundStyle(AboLifeColors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            HStack(spacing: 10) {
                summaryPill(
                    title: "Dauer",
                    value: "\(store.totalDurationThisWeek) Min.",
                    systemImage: "clock",
                    tint: AboLifeColors.training
                )

                summaryPill(
                    title: "Letzte Einheit",
                    value: store.lastWorkout?.workoutType ?? "Noch keine",
                    systemImage: "checkmark.circle",
                    tint: AboLifeColors.review
                )
            }

            Text(store.statusMessage)
                .font(AboLifeTypography.body)
                .foregroundStyle(AboLifeColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    private var weekStrip: some View {
        AboLifeCard {
            HStack(spacing: 10) {
                ForEach(store.dayStates) { day in
                    VStack(spacing: 8) {
                        Text(day.weekday)
                            .font(AboLifeTypography.micro)
                            .foregroundStyle(AboLifeColors.secondaryText)
                            .textCase(.uppercase)

                        Capsule()
                            .fill(day.hasWorkout ? AboLifeColors.training : AboLifeColors.quietFill)
                            .frame(width: 34, height: 8)
                            .overlay {
                                Capsule()
                                    .strokeBorder(AboLifeColors.glassStrokeMuted, lineWidth: 0.6)
                            }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var sessionsSection: some View {
        AboLifeCard(isProminent: true) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Label("Workouts diese Woche", systemImage: "list.bullet.rectangle")
                        .font(AboLifeTypography.cardTitle)
                        .foregroundStyle(AboLifeColors.primaryText)

                    Spacer()

                    AboLifeGlassCapsule {
                        Text("\(store.sessions.count) Sessions")
                            .font(AboLifeTypography.micro)
                            .foregroundStyle(AboLifeColors.secondaryText)
                            .monospacedDigit()
                    }
                }

                if let errorMessage = store.errorMessage {
                    errorState(errorMessage)
                } else if store.sessions.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 10) {
                        ForEach(store.sessions) { session in
                            WorkoutSessionRow(session: session) {
                                store.deleteSession(id: session.id)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Diese Woche noch kein Training abgeschlossen.")
                .font(AboLifeTypography.body.weight(.semibold))
                .foregroundStyle(AboLifeColors.primaryText)

            Text("Nutze Quick Add, um ein Training einzutragen.")
                .font(AboLifeTypography.caption)
                .foregroundStyle(AboLifeColors.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
    }

    private func errorState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Trainingsdaten konnten nicht geladen werden.")
                .font(AboLifeTypography.body.weight(.semibold))
                .foregroundStyle(AboLifeColors.primaryText)

            Text(message)
                .font(AboLifeTypography.caption)
                .foregroundStyle(AboLifeColors.secondaryText)

            Button {
                store.reload()
            } label: {
                Label("Erneut versuchen", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .tint(AboLifeColors.training)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
    }

    private func summaryPill(title: String, value: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(AboLifeColors.secondaryText)

                Text(value)
                    .font(AboLifeTypography.caption.weight(.semibold))
                    .foregroundStyle(AboLifeColors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: 170, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AboLifeColors.quietFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(AboLifeColors.glassStrokeMuted, lineWidth: 0.6)
                }
        }
    }

    private func sectionHeader(title: String, systemImage: String, value: String) -> some View {
        HStack(spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(AboLifeTypography.cardTitle)
                .foregroundStyle(AboLifeColors.primaryText)

            Spacer()

            AboLifeGlassCapsule {
                Text(value)
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(AboLifeColors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private func trendPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(AboLifeTypography.micro)
                .foregroundStyle(AboLifeColors.secondaryText)

            Text(value)
                .font(AboLifeTypography.caption.weight(.semibold))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground)
    }

    private func statTile(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AboLifeTypography.micro)
                .foregroundStyle(AboLifeColors.secondaryText)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(AboLifeTypography.metric)
                    .foregroundStyle(AboLifeColors.primaryText)
                    .monospacedDigit()

                Text(unit)
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(AboLifeColors.tertiaryText)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AboLifeColors.quietFill)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(AboLifeColors.glassStrokeMuted, lineWidth: 0.6)
            }
    }

    private func centimeters(_ value: Double?) -> String {
        guard let value else { return "neu" }
        return String(format: "%+.1f cm", value)
    }

    private func signedInt(_ value: Int?) -> String {
        guard let value else { return "neu" }
        return String(format: "%+d", value)
    }

    private func icon(for outcome: String) -> String {
        switch outcome {
        case ExerciseProgressionOutcome.increase.rawValue:
            return "arrow.up.circle.fill"
        case ExerciseProgressionOutcome.reduceTarget.rawValue:
            return "arrow.down.circle.fill"
        case ExerciseProgressionOutcome.recover.rawValue:
            return "cross.case.fill"
        default:
            return "repeat.circle.fill"
        }
    }

    private func color(for outcome: String) -> Color {
        switch outcome {
        case ExerciseProgressionOutcome.increase.rawValue:
            return AboLifeColors.training
        case ExerciseProgressionOutcome.reduceTarget.rawValue:
            return AboLifeColors.habits
        case ExerciseProgressionOutcome.recover.rawValue:
            return AboLifeColors.review
        default:
            return AboLifeColors.protein
        }
    }
}

private struct WorkoutSessionRow: View {
    let session: WorkoutSessionRecord
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(session.workoutType)
                        .font(AboLifeTypography.body.weight(.semibold))
                        .foregroundStyle(AboLifeColors.primaryText)
                        .lineLimit(1)

                    Text(session.occurredAt.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(AboLifeColors.tertiaryText)
                        .monospacedDigit()
                }

                if let note = session.note, !note.isEmpty {
                    Text(note)
                        .font(AboLifeTypography.caption)
                        .foregroundStyle(AboLifeColors.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(session.durationMin) Min.")
                    .font(AboLifeTypography.caption.weight(.semibold))
                    .foregroundStyle(AboLifeColors.primaryText)
                    .monospacedDigit()

                Text(session.status == "done" ? "Abgeschlossen" : session.status.capitalized)
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(session.status == "done" ? AboLifeColors.training : AboLifeColors.secondaryText)
            }

            Button(role: .destructive, action: delete) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .help("Löschen")
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AboLifeColors.quietFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(AboLifeColors.glassStrokeMuted, lineWidth: 0.6)
                }
        }
        .contextMenu {
            Button(role: .destructive, action: delete) {
                Label("Löschen", systemImage: "trash")
            }
        }
    }
}

struct TrainingView_Previews: PreviewProvider {
    static var previews: some View {
        TrainingView(database: nil)
            .frame(width: 1000, height: 720)
    }
}
