import SwiftUI

struct TrainingDoubleProgressRing: View {
    @Environment(\.aboLifeStyle) private var designStyle
    let weeklyProgress: Double
    let dailyProgress: Double
    let checkedExercises: Int
    let totalExercises: Int
    let completedWorkouts: Int
    let weeklyWorkoutTarget: Int

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                ringTrack(lineWidth: 16, diameter: 176)
                ringProgress(weeklyProgress, lineWidth: 16, diameter: 176, tint: designStyle.colors.training)

                ringTrack(lineWidth: 10, diameter: 124)
                ringProgress(dailyProgress, lineWidth: 10, diameter: 124, tint: designStyle.colors.review)

                VStack(spacing: 2) {
                    Text("\(checkedExercises) / \(totalExercises)")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(designStyle.colors.primaryText)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text("Übungen")
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(designStyle.colors.secondaryText)
                }
                .frame(width: 92)
            }
            .frame(width: 190, height: 190)

            Text("Woche: \(completedWorkouts) / \(weeklyWorkoutTarget) Workouts")
                .font(AboLifeTypography.caption.weight(.semibold))
                .foregroundStyle(designStyle.colors.secondaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Trainingsfortschritt")
        .accessibilityValue("\(checkedExercises) von \(totalExercises) Übungen, Woche \(completedWorkouts) von \(weeklyWorkoutTarget) Workouts")
    }

    static func progress(current: Int, target: Int) -> Double {
        guard target > 0 else { return 0 }
        return min(max(Double(current) / Double(target), 0), 1)
    }

    private func ringTrack(lineWidth: CGFloat, diameter: CGFloat) -> some View {
        Circle()
            .stroke(designStyle.colors.quietFill, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: diameter, height: diameter)
    }

    private func ringProgress(_ progress: Double, lineWidth: CGFloat, diameter: CGFloat, tint: Color) -> some View {
        Circle()
            .trim(from: 0, to: min(max(progress, 0), 1))
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .opacity(progress > 0 ? 1 : 0)
            .rotationEffect(.degrees(-90))
            .frame(width: diameter, height: diameter)
            .aboLifeMotion(value: progress)
    }
}

struct TrainingDoubleProgressRing_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            AboLifePremiumBackground()
            TrainingDoubleProgressRing(
                weeklyProgress: 2.0 / 3.0,
                dailyProgress: 3.0 / 5.0,
                checkedExercises: 3,
                totalExercises: 5,
                completedWorkouts: 2,
                weeklyWorkoutTarget: 3
            )
            .padding(40)
        }
        .frame(width: 420, height: 360)
    }
}
