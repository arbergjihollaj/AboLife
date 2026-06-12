import SwiftUI

struct FloatingQuickAddBar: View {
    let actions: [QuickAddAction]
    let onActivate: (QuickAddKind) -> Void

    private var leadingActions: [QuickAddAction] {
        actions.filter { $0.kind == .meal || $0.kind == .workout }
    }

    private var trailingActions: [QuickAddAction] {
        actions.filter { $0.kind == .expense || $0.kind == .habit }
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            dockContent(isCompact: false)
                .frame(maxWidth: 560)

            ScrollView(.horizontal, showsIndicators: false) {
                dockContent(isCompact: true)
                    .padding(.horizontal, 2)
            }
            .frame(maxWidth: 390)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            AboLifeLiquidGlassSurface(
                shape: Capsule(),
                tint: AboLifeColors.review.opacity(0.045),
                isProminent: true,
                isInteractive: true
            )
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.white.opacity(0.16))
                .frame(height: 1)
                .padding(.horizontal, 34)
                .blendMode(.screen)
        }
        .clipShape(Capsule())
        .shadow(color: AboLifeColors.shadow.opacity(0.22), radius: 15, x: 0, y: 10)
    }

    private func dockContent(isCompact: Bool) -> some View {
        HStack(spacing: isCompact ? 8 : 10) {
            actionGroup(leadingActions, isCompact: isCompact)

            separator

            primaryButton

            separator

            actionGroup(trailingActions, isCompact: isCompact)
        }
    }

    private func actionGroup(_ actions: [QuickAddAction], isCompact: Bool) -> some View {
        HStack(spacing: isCompact ? 4 : 6) {
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
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .foregroundStyle(AboLifeColors.primaryText)
                .frame(width: 50, height: 50)
                .background {
                    Circle()
                        .fill(AboLifeColors.review.opacity(0.24))
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(alignment: .topLeading) {
                            Circle()
                                .fill(AboLifeColors.glassHighlightGradient)
                                .opacity(0.72)
                                .blendMode(.screen)
                        }
                        .overlay {
                            Circle()
                                .strokeBorder(AboLifeColors.liquidGlassEdgeGradient, lineWidth: 0.95)
                        }
                }
                .shadow(color: AboLifeColors.review.opacity(0.16), radius: 9, x: 0, y: 5)
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
                    .frame(width: 24, height: 24)
                    .background(action.tint.opacity(0.07), in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(AboLifeColors.glassStrokeMuted.opacity(0.65), lineWidth: 0.6)
                    }

                Text(action.title)
                    .font(AboLifeTypography.micro.weight(.medium))
                    .foregroundStyle(AboLifeColors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(width: isCompact ? 64 : 74, height: 48)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var separator: some View {
        Capsule()
            .fill(AboLifeColors.glassStrokeMuted.opacity(0.95))
            .frame(width: 1, height: 30)
            .overlay {
                Capsule()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 1, height: 14)
                    .offset(y: -6)
            }
            .padding(.horizontal, 2)
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
