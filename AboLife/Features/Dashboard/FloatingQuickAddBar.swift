import SwiftUI

struct FloatingQuickAddBar: View {
    let actions: [QuickAddAction]
    let onActivate: (QuickAddKind) -> Void

    private var leadingActions: [QuickAddAction] {
        orderedActions(for: [.workout])
    }

    private var trailingActions: [QuickAddAction] {
        orderedActions(for: [.expense, .habit])
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            dockContent(isCompact: false)
                .frame(maxWidth: 520)

            ScrollView(.horizontal, showsIndicators: false) {
                dockContent(isCompact: true)
                    .padding(.horizontal, 3)
            }
            .frame(maxWidth: 372)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background {
            AboLifeLiquidGlassSurface(
                shape: Capsule(),
                tint: AboLifeColors.review.opacity(0.035),
                isProminent: true,
                isInteractive: true
            )
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(height: 1)
                .padding(.horizontal, 36)
                .blendMode(.screen)
        }
        .overlay(alignment: .bottom) {
            Capsule()
                .fill(Color.white.opacity(0.035))
                .frame(height: 1)
                .padding(.horizontal, 44)
                .blendMode(.screen)
        }
        .clipShape(Capsule())
        .shadow(color: AboLifeColors.shadow.opacity(0.18), radius: 13, x: 0, y: 9)
    }

    private func dockContent(isCompact: Bool) -> some View {
        HStack(spacing: isCompact ? 7 : 9) {
            actionGroup(leadingActions, isCompact: isCompact)

            separator

            primaryButton

            separator

            actionGroup(trailingActions, isCompact: isCompact)
        }
    }

    private func orderedActions(for kinds: [QuickAddKind]) -> [QuickAddAction] {
        kinds.compactMap { kind in
            actions.first { $0.kind == kind }
        }
    }

    private func actionGroup(_ actions: [QuickAddAction], isCompact: Bool) -> some View {
        HStack(spacing: isCompact ? 3 : 5) {
            ForEach(actions) { action in
                actionButton(action, isCompact: isCompact)
            }
        }
    }

    private var primaryButton: some View {
        Button {
            onActivate(.general)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(AboLifeColors.primaryText)
                .frame(width: 52, height: 52)
                .background {
                    Circle()
                        .fill(AboLifeColors.review.opacity(0.18))
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(alignment: .topLeading) {
                            Circle()
                                .fill(AboLifeColors.glassHighlightGradient)
                                .opacity(0.66)
                                .blendMode(.screen)
                        }
                        .overlay {
                            Circle()
                                .strokeBorder(AboLifeColors.liquidGlassEdgeGradient, lineWidth: 0.85)
                        }
                }
                .shadow(color: AboLifeColors.review.opacity(0.12), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Quick Add")
    }

    private func actionButton(_ action: QuickAddAction, isCompact: Bool) -> some View {
        Button {
            onActivate(action.kind)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: action.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(action.tint)
                    .frame(width: 25, height: 25)
                    .background(action.tint.opacity(0.075), in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(AboLifeColors.glassStrokeMuted.opacity(0.72), lineWidth: 0.6)
                    }

                Text(action.title)
                    .font(AboLifeTypography.micro.weight(.medium))
                    .foregroundStyle(AboLifeColors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(width: isCompact ? 62 : 70, height: 47)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var separator: some View {
        Capsule()
            .fill(AboLifeColors.glassStrokeMuted.opacity(0.82))
            .frame(width: 1, height: 28)
            .overlay {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1, height: 14)
                    .offset(y: -6)
            }
            .padding(.horizontal, 1)
    }
}

struct FloatingQuickAddBar_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            AboLifePremiumBackground()
            FloatingQuickAddBar(actions: QuickAddAction.bottomDockActions) { _ in }
                .padding()
        }
        .frame(width: 720, height: 180)
    }
}
