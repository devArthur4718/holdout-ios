import SwiftUI

struct WelcomeView: View {
    let viewModel: WelcomeViewModel

    @ScaledMetric(relativeTo: .largeTitle) private var tileSize: CGFloat = 64
    @ScaledMetric(relativeTo: .largeTitle) private var tileIconSize: CGFloat = 30
    @ScaledMetric(relativeTo: .subheadline) private var benefitIconWidth: CGFloat = 22

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                iconTile

                Text("One counter.\nThat's the whole idea.")
                    .font(.largeTitle)
                    .foregroundStyle(Palette.onSurface)
                    .accessibilityAddTraits(.isHeader)

                Text("Quitter counts the time since you last did the thing — and turns it into money kept and hours back. No account. Your data stays on the device.")
                    .font(.body)
                    .foregroundStyle(Palette.onSurfaceVariant)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(viewModel.benefits) { benefit in
                        Label {
                            Text(benefit.text)
                                .foregroundStyle(Palette.onSurface)
                        } icon: {
                            Image(systemName: benefit.symbol)
                                .foregroundStyle(Palette.primary)
                                .frame(width: benefitIconWidth)
                        }
                        .font(.subheadline)
                    }
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            Button(action: viewModel.addHabitTapped) {
                Text("Add my first habit")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: Radius.button))
            .tint(Palette.primary)
            .foregroundStyle(Palette.onPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Palette.background)
        }
        .background(Palette.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var iconTile: some View {
        Image(systemName: "timer")
            .font(.system(size: tileIconSize, weight: .medium))
            .foregroundStyle(Palette.onPrimaryContainer)
            .frame(width: tileSize, height: tileSize)
            .background(Palette.primaryContainer, in: .rect(cornerRadius: Radius.iconTile))
            .accessibilityHidden(true)
    }
}

#Preview("Light") {
    WelcomeView(viewModel: WelcomeViewModel())
}

#Preview("Dark") {
    WelcomeView(viewModel: WelcomeViewModel())
        .preferredColorScheme(.dark)
}

#Preview("Largest text") {
    WelcomeView(viewModel: WelcomeViewModel())
        .dynamicTypeSize(.accessibility3)
}
