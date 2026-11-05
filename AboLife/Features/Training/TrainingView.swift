import SwiftUI

struct TrainingView: View {
    @Environment(\.aboLifeStyle) private var designStyle
    @StateObject private var store: TrainingStore
    @State private var checklistState = HomeWorkoutChecklistState()
    @State private var detailedDraft: DetailedWorkoutDraft?

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
                    goalsSection
                    weeklyOverview
                    weekStrip
                    sessionsSection
                }
                .aboLifePage()
            }
        }
        .navigationTitle("")
        .onAppear {
            store.reload()
        }
        .sheet(item: $detailedDraft) { draft in
            DetailedWorkoutSheet(draft: draft) { completedDraft in
                guard store.completeDetailedHomeWorkout(
                    intensity: completedDraft.intensity,
                    exercises: completedDraft.exercises,
                    note: completedDraft.note,
                    painReported: completedDraft.painReported
                ) else { return false }
                checklistState.resetCompletedExercises()
                detailedDraft = nil
                return true
            } cancel: {
                detailedDraft = nil
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Training")
                    .font(AboLifeTypography.dashboardTitle)
                    .foregroundStyle(designStyle.colors.primaryText)

                Text("Diese Woche · \(store.weekSubtitle)")
                    .font(AboLifeTypography.body)
                    .foregroundStyle(designStyle.colors.secondaryText)
            }

            Spacer()

            Button {
                store.selectCurrentWeek()
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(.bordered)
            .help("Diese Woche").accessibilityLabel("Diese Woche")
            .disabled(store.isCurrentWeek)

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
                            .foregroundStyle(designStyle.colors.primaryText)

                        Text("Körpergewicht + Klimmzugstange")
                            .font(AboLifeTypography.caption)
                            .foregroundStyle(designStyle.colors.secondaryText)
                    }

                    Spacer()

                    AboLifeGlassCapsule {
                        Text(checklistState.selectedIntensity.timeRange)
                            .font(AboLifeTypography.micro)
                            .foregroundStyle(designStyle.colors.training)
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
                    .foregroundStyle(designStyle.colors.secondaryText)
                    .textCase(.uppercase)

                Text(scheduledWorkout.day.name)
                    .font(AboLifeTypography.heroMessage)
                    .foregroundStyle(designStyle.colors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(scheduleText(for: scheduledWorkout))
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(designStyle.colors.secondaryText)
            }

            Text(scheduledWorkout.day.focusText)
                .font(AboLifeTypography.body)
                .foregroundStyle(designStyle.colors.secondaryText)
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
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(designStyle.colors.action)
                .disabled(store.isSavingPlanWorkout)

                Button {
                    detailedDraft = DetailedWorkoutDraft(
                        intensity: checklistState.selectedIntensity,
                        workoutName: scheduledWorkout.day.name,
                        exercises: store.makeDetailedHomeWorkoutExercises(intensity: checklistState.selectedIntensity)
                    )
                } label: {
                    Label("Mit Details", systemImage: "list.bullet.clipboard")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(store.isSavingPlanWorkout)

                if let completionMessage = store.completionMessage {
                    Label(completionMessage, systemImage: "checkmark.circle")
                        .font(AboLifeTypography.caption)
                        .foregroundStyle(designStyle.colors.review)
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
                    .foregroundStyle(designStyle.colors.primaryText)

                Spacer()

                Text("\(checklistState.checkedExerciseCount) / \(exercises.count)")
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(designStyle.colors.secondaryText)
                    .monospacedDigit()
            }

            VStack(spacing: 8) {
                ForEach(exercises) { exercise in
                    Toggle(isOn: exerciseBinding(for: exercise.id)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name)
                                .font(AboLifeTypography.caption.weight(.semibold))
                                .foregroundStyle(designStyle.colors.primaryText)

                            Text(exercise.prescription)
                                .font(AboLifeTypography.micro)
                                .foregroundStyle(designStyle.colors.secondaryText)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(designStyle.colors.quietFill)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(designStyle.colors.glassStrokeMuted, lineWidth: 0.6)
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
                    if store.exerciseProgressStatuses.isEmpty {
                        Text("Noch nicht genug Satzdaten für echte Übungstrends. Ein paar detaillierte Trainings reichen, dann wird es hier konkreter.")
                            .font(AboLifeTypography.caption)
                            .foregroundStyle(designStyle.colors.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 11)
                            .background(rowBackground)
                    }

                    ForEach(store.exerciseProgressStatuses.prefix(4)) { status in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: status.hasEnoughData ? "chart.line.uptrend.xyaxis.circle.fill" : "circle.dashed")
                                .foregroundStyle(status.hasEnoughData ? designStyle.colors.training : designStyle.colors.secondaryText)
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(status.exerciseName)
                                    .font(AboLifeTypography.body.weight(.semibold))
                                    .foregroundStyle(designStyle.colors.primaryText)

                                Text(progressDetail(status))
                                    .font(AboLifeTypography.caption)
                                    .foregroundStyle(designStyle.colors.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(status.recommendation)
                                    .font(AboLifeTypography.micro)
                                    .foregroundStyle(designStyle.colors.tertiaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 11)
                        .background(rowBackground)
                    }

                    ForEach(store.recommendations, id: \.id) { recommendation in
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: icon(for: recommendation.outcomeRawValue))
                                .foregroundStyle(color(for: recommendation.outcomeRawValue))
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(recommendation.exerciseName)
                                    .font(AboLifeTypography.body.weight(.semibold))
                                    .foregroundStyle(designStyle.colors.primaryText)

                                Text(recommendation.message)
                                    .font(AboLifeTypography.caption)
                                    .foregroundStyle(designStyle.colors.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 3) {
                                Text("Level \(recommendation.nextLevel)")
                                    .font(AboLifeTypography.caption.weight(.semibold))
                                    .foregroundStyle(designStyle.colors.primaryText)

                                Text("\(recommendation.nextTargetSets) x \(recommendation.nextTargetMinReps)-\(recommendation.nextTargetMaxReps)")
                                    .font(AboLifeTypography.micro)
                                    .foregroundStyle(designStyle.colors.tertiaryText)
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
                sectionHeader(title: "Körperentwicklung", systemImage: "figure.arms.open", value: "Letzte 30 Tage")
                Text(store.bodyTrend.latestWeightKg.map(WeightStore.formatWeight) ?? "Noch keine Gewichtsdaten in diesem Zeitraum.")
                    .font(AboLifeTypography.metric)
                    .foregroundStyle(designStyle.colors.primaryText)
                Text(store.bodyTrend.weightChangeKg.map { "Veränderung im Zeitraum: \(WeightStore.formatChange($0))" }
                     ?? "Für einen Vergleich werden mindestens zwei gespeicherte Gewichtswerte benötigt.")
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(designStyle.colors.secondaryText)
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
                    statTile("Dauer", "\(store.trainingStatistics.totalVolume)", "Minuten")
                    statTile("Ø Sätze", String(format: "%.1f", store.trainingStatistics.averageSetsPerTraining), "pro Training")
                    statTile("Push", "\(store.trainingStatistics.pushVolume)", "Min. Fokus")
                    statTile("Pull", "\(store.trainingStatistics.pullVolume)", "Min. Fokus")
                    statTile("Beine", "\(store.trainingStatistics.legVolume)", "Min. Fokus")
                    statTile("Minimum", "\(store.trainingStatistics.minimumWorkouts)", "Einheiten")
                }
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
                                .foregroundStyle(designStyle.colors.training)

                            Text(card.title)
                                .font(AboLifeTypography.caption.weight(.semibold))
                                .foregroundStyle(designStyle.colors.primaryText)

                            Text(card.detail)
                                .font(AboLifeTypography.micro)
                                .foregroundStyle(designStyle.colors.secondaryText)
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
            tint: designStyle.colors.training,
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
                    .foregroundStyle(designStyle.colors.primaryText)

                AboLifeGlassCapsule {
                    Text("\(Int(store.progress * 100))%")
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(designStyle.colors.training)
                        .monospacedDigit()
                }
            }

            Text("\(store.completedWorkoutsThisWeek) / \(store.weeklyWorkoutTarget) Workouts")
                .font(AboLifeTypography.heroMessage)
                .foregroundStyle(designStyle.colors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            HStack(spacing: 10) {
                summaryPill(
                    title: "Dauer",
                    value: "\(store.totalDurationThisWeek) Min.",
                    systemImage: "clock",
                    tint: designStyle.colors.training
                )

                summaryPill(
                    title: "Letzte Einheit",
                    value: store.lastWorkout?.workoutType ?? "Noch keine",
                    systemImage: "checkmark.circle",
                    tint: designStyle.colors.review
                )
            }

            Text(store.statusMessage)
                .font(AboLifeTypography.body)
                .foregroundStyle(designStyle.colors.secondaryText)
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
                            .foregroundStyle(designStyle.colors.secondaryText)
                            .textCase(.uppercase)

                        Capsule()
                            .fill(day.hasWorkout ? designStyle.colors.training : designStyle.colors.quietFill)
                            .frame(width: 34, height: 8)
                            .overlay {
                                Capsule()
                                    .strokeBorder(designStyle.colors.glassStrokeMuted, lineWidth: 0.6)
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
                        .foregroundStyle(designStyle.colors.primaryText)

                    Spacer()

                    AboLifeGlassCapsule {
                        Text("\(store.sessions.count) Sessions")
                            .font(AboLifeTypography.micro)
                            .foregroundStyle(designStyle.colors.secondaryText)
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
                .foregroundStyle(designStyle.colors.primaryText)

            Text("Nutze Quick Add, um ein Training einzutragen.")
                .font(AboLifeTypography.caption)
                .foregroundStyle(designStyle.colors.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
    }

    private func errorState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Trainingsdaten konnten nicht geladen werden.")
                .font(AboLifeTypography.body.weight(.semibold))
                .foregroundStyle(designStyle.colors.primaryText)

            Text(message)
                .font(AboLifeTypography.caption)
                .foregroundStyle(designStyle.colors.secondaryText)

            Button {
                store.reload()
            } label: {
                Label("Erneut versuchen", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .tint(designStyle.colors.action)
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
                    .foregroundStyle(designStyle.colors.secondaryText)

                Text(value)
                    .font(AboLifeTypography.caption.weight(.semibold))
                    .foregroundStyle(designStyle.colors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: 170, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(designStyle.colors.quietFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(designStyle.colors.glassStrokeMuted, lineWidth: 0.6)
                }
        }
    }

    private func sectionHeader(title: String, systemImage: String, value: String) -> some View {
        HStack(spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(AboLifeTypography.cardTitle)
                .foregroundStyle(designStyle.colors.primaryText)

            Spacer()

            AboLifeGlassCapsule {
                Text(value)
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(designStyle.colors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private func statTile(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AboLifeTypography.micro)
                .foregroundStyle(designStyle.colors.secondaryText)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(AboLifeTypography.metric)
                    .foregroundStyle(designStyle.colors.primaryText)
                    .monospacedDigit()

                Text(unit)
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(designStyle.colors.tertiaryText)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(designStyle.colors.quietFill)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(designStyle.colors.glassStrokeMuted, lineWidth: 0.6)
            }
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
            return designStyle.colors.training
        case ExerciseProgressionOutcome.reduceTarget.rawValue:
            return designStyle.colors.habits
        case ExerciseProgressionOutcome.recover.rawValue:
            return designStyle.colors.review
        default:
            return designStyle.colors.positive
        }
    }

    private func progressDetail(_ status: ExerciseProgressStatus) -> String {
        let last = status.lastSetsText.map { "Letztes Mal: \($0) Wiederholungen." } ?? "Letztes Mal: erledigt."
        let best = status.bestSetReps.map { " Bester Satz: \($0)." } ?? ""
        return last + best
    }
}

struct TrainingView_Previews: PreviewProvider {
    static var previews: some View {
        TrainingView(database: nil)
            .frame(width: 1000, height: 720)
    }
}
