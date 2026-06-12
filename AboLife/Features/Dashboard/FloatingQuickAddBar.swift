import SwiftUI

struct FloatingQuickAddBar: View {
    let actions: [QuickAddAction]
    let onActivate: (QuickAddKind) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            dockContent(isCompact: false)
                .frame(maxWidth: 620)

            ScrollView(.horizontal, showsIndicators: false) {
                dockContent(isCompact: true)
                    .padding(.horizontal, 2)
            }
            .frame(maxWidth: 430)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background {
            AboLifeLiquidGlassSurface(
                shape: Capsule(),
                tint: AboLifeColors.review.opacity(0.10),
                isProminent: true,
                isInteractive: true
            )
        }
        .clipShape(Capsule())
        .shadow(color: AboLifeColors.shadow.opacity(0.28), radius: 20, x: 0, y: 13)
    }

    private func dockContent(isCompact: Bool) -> some View {
        HStack(spacing: isCompact ? 8 : 12) {
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                if index == 2 {
                    primaryButton
                }

                actionButton(action, isCompact: isCompact)
            }
        }
    }

    private var primaryButton: some View {
        Button {
            onActivate(.meal)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundStyle(AboLifeColors.primaryText)
                .frame(width: 52, height: 52)
                .background {
                    Circle()
                        .fill(AboLifeColors.sidebarSelectionGradient.opacity(0.82))
                        .overlay(alignment: .topLeading) {
                            Circle()
                                .fill(AboLifeColors.glassHighlightGradient)
                                .blendMode(.screen)
                        }
                        .overlay {
                            Circle()
                                .strokeBorder(AboLifeColors.glassStroke, lineWidth: 0.9)
                        }
                }
                .shadow(color: AboLifeColors.review.opacity(0.22), radius: 12, x: 0, y: 6)
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
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(action.tint)
                    .frame(width: 28, height: 28)
                    .background(action.tint.opacity(0.10), in: Circle())

                Text(action.title)
                    .font(AboLifeTypography.micro.weight(.medium))
                    .foregroundStyle(AboLifeColors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(width: isCompact ? 68 : 76, height: 52)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
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
