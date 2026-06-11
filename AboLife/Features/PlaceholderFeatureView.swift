import SwiftUI

struct PlaceholderFeatureView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack {
            Spacer()

            AboLifeCard {
                VStack(spacing: 16) {
                    Image(systemName: systemImage)
                        .font(.system(size: 42, weight: .regular))
                        .foregroundStyle(.secondary)

                    Text(title)
                        .font(AboLifeTypography.dashboardTitle)

                    Text(message)
                        .font(AboLifeTypography.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: 440)

            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AboLifeColors.pageBackground)
        .navigationTitle(title)
    }
}
