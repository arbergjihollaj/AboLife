import SwiftUI

struct DetailedWorkoutDraft: Identifiable, Equatable {
    let id = UUID()
    var intensity: HomeWorkoutIntensity
    var workoutName: String
    var exercises: [WorkoutExerciseInput]
    var note = ""
    var painReported = false
}

struct DetailedWorkoutSheet: View {
    @Environment(\.aboLifeStyle) private var designStyle
    @State private var draft: DetailedWorkoutDraft
    @State private var saveFailed = false
    let save: (DetailedWorkoutDraft) -> Bool
    let cancel: () -> Void

    init(draft: DetailedWorkoutDraft, save: @escaping (DetailedWorkoutDraft) -> Bool, cancel: @escaping () -> Void) {
        _draft = State(initialValue: draft)
        self.save = save
        self.cancel = cancel
    }

    var body: some View {
        ZStack {
            AboLifePremiumBackground()

            VStack(alignment: .leading, spacing: 14) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        recoveryNote
                        ForEach(draft.exercises.indices, id: \.self) { index in
                            exerciseEditor(index: index)
                        }
                        sessionNote
                    }
                    .padding(.vertical, 2)
                }

                if saveFailed {
                    AboLifeNotice(
                        title: "Training nicht gespeichert",
                        message: "Deine Eingaben bleiben erhalten. Bitte versuche es erneut.")
                }
                footer
            }
            .padding(18)
            .frame(minWidth: 560, idealWidth: 640, minHeight: 420, idealHeight: 620, maxHeight: 680)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(draft.workoutName)
                    .font(AboLifeTypography.cardTitle)
                    .foregroundStyle(designStyle.colors.primaryText)
                Text("\(draft.intensity.rawValue) · Sätze schnell anpassen")
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(designStyle.colors.secondaryText)
            }

            Spacer()

            Picker("Intensität", selection: $draft.intensity) {
                ForEach(HomeWorkoutIntensity.allCases) { intensity in
                    Text(intensity.rawValue).tag(intensity)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 260)
        }
    }

    private var recoveryNote: some View {
        Toggle(isOn: $draft.painReported) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Schmerz oder Erholung beachten")
                    .font(AboLifeTypography.caption.weight(.semibold))
                    .foregroundStyle(designStyle.colors.primaryText)
                Text(
                    draft.painReported
                        ? "Minimum ist heute völlig okay." : "Wenn sich etwas nicht gut anfühlt, lieber reduzieren."
                )
                .font(AboLifeTypography.micro)
                .foregroundStyle(designStyle.colors.secondaryText)
            }
        }
        .toggleStyle(.checkbox)
        .padding(12)
        .background(designStyle.colors.quietFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func exerciseEditor(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Toggle(isOn: $draft.exercises[index].isCompleted) {
                    Text(draft.exercises[index].exerciseName)
                        .font(AboLifeTypography.body.weight(.semibold))
                        .foregroundStyle(designStyle.colors.primaryText)
                }
                .toggleStyle(.checkbox)

                Spacer()

                Button {
                    draft.exercises[index].sets.append(
                        WorkoutSetInput(setNumber: draft.exercises[index].sets.count + 1, reps: 0))
                } label: {
                    Label("Satz", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            VStack(spacing: 7) {
                ForEach(draft.exercises[index].sets.indices, id: \.self) { setIndex in
                    HStack(spacing: 8) {
                        Text("Satz \(setIndex + 1)")
                            .font(AboLifeTypography.micro)
                            .foregroundStyle(designStyle.colors.secondaryText)
                            .frame(width: 54, alignment: .leading)

                        Stepper(value: repsBinding(exerciseIndex: index, setIndex: setIndex), in: 0...200) {
                            Text("\(draft.exercises[index].sets[setIndex].reps ?? 0) Wdh.")
                                .font(AboLifeTypography.caption.weight(.semibold))
                                .foregroundStyle(designStyle.colors.primaryText)
                                .monospacedDigit()
                        }

                        if let seconds = draft.exercises[index].sets[setIndex].durationSec {
                            Text("\(seconds)s")
                                .font(AboLifeTypography.micro)
                                .foregroundStyle(designStyle.colors.tertiaryText)
                                .monospacedDigit()
                        }

                        Button(role: .destructive) {
                            draft.exercises[index].sets.remove(at: setIndex)
                            renumberSets(exerciseIndex: index)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            TextField("Notiz zur Übung", text: noteBinding(exerciseIndex: index))
                .textFieldStyle(.roundedBorder)
        }
        .padding(12)
        .background(designStyle.colors.quietFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(designStyle.colors.glassStrokeMuted, lineWidth: 0.7)
        }
    }

    private var sessionNote: some View {
        TextField("Notiz zur Session", text: $draft.note)
            .textFieldStyle(.roundedBorder)
            .padding(.top, 2)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: AboLifeSpacing.medium) {
            Text("Pause ist okay. Speichern soll helfen, nicht stressen.")
                .font(AboLifeTypography.micro)
                .foregroundStyle(designStyle.colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Abbrechen", action: cancel)
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    saveFailed = !save(normalizedDraft)
                } label: {
                    Label("Training speichern", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(designStyle.colors.action)
            }
        }
    }

    private var normalizedDraft: DetailedWorkoutDraft {
        var copy = draft
        for exerciseIndex in copy.exercises.indices {
            copy.exercises[exerciseIndex].sets = copy.exercises[exerciseIndex].sets.enumerated().map { index, set in
                var updated = set
                updated.setNumber = index + 1
                return updated
            }
        }
        return copy
    }

    private func repsBinding(exerciseIndex: Int, setIndex: Int) -> Binding<Int> {
        Binding(
            get: { draft.exercises[exerciseIndex].sets[setIndex].reps ?? 0 },
            set: { draft.exercises[exerciseIndex].sets[setIndex].reps = $0 }
        )
    }

    private func noteBinding(exerciseIndex: Int) -> Binding<String> {
        Binding(
            get: { draft.exercises[exerciseIndex].note ?? "" },
            set: {
                draft.exercises[exerciseIndex].note =
                    $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0
            }
        )
    }

    private func renumberSets(exerciseIndex: Int) {
        for index in draft.exercises[exerciseIndex].sets.indices {
            draft.exercises[exerciseIndex].sets[index].setNumber = index + 1
        }
    }
}
