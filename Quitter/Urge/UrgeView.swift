import SwiftUI

/// The urge screen is dark in both appearances. These come from the design's palette, with
/// the lighter tones used for text so it stays readable on the deep purple.
private enum UrgeColors {
    static let background = Color(red: 0x21 / 255, green: 0x00 / 255, blue: 0x5D / 255)
    static let accent = Color(red: 0xEA / 255, green: 0xDD / 255, blue: 0xFF / 255)
    static let ring = Color(red: 0xD0 / 255, green: 0xBC / 255, blue: 0xFF / 255)
    static let track = Color.white.opacity(0.16)
}

struct UrgeView: View {
    @State private var viewModel: UrgeViewModel
    let onClose: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var ringSize: CGFloat = 182
    @ScaledMetric(relativeTo: .largeTitle) private var clockSize: CGFloat = 44

    init(viewModel: UrgeViewModel, onClose: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onClose = onClose
    }

    var body: some View {
        TimelineView(.periodic(from: viewModel.startedAt, by: 1)) { context in
            let remaining = viewModel.remainingSeconds(at: context.date)
            let phase = UrgePhase(remaining: remaining)
            VStack(spacing: 0) {
                HStack {
                    Button("Close", systemImage: "xmark", action: onClose)
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .foregroundStyle(UrgeColors.accent)
                    Spacer()
                }

                ScrollView {
                    VStack(spacing: 6) {
                        Text("Ride it out")
                            .textCase(.uppercase)
                            .font(.footnote)
                            .tracking(0.6)
                            .foregroundStyle(UrgeColors.ring)
                        ring(remaining: remaining)
                        Text(phase.coach)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .frame(maxWidth: 280)
                        if let reason = viewModel.reason {
                            ReasonCard(text: reason)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .containerRelativeFrame(.vertical) { height, _ in height }
                }
                .scrollBounceBehavior(.basedOnSize)

                Button(action: viewModel.gotThroughIt) {
                    Text("I got through it")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .foregroundStyle(UrgeColors.background)
                .background(UrgeColors.accent, in: .rect(cornerRadius: Radius.button))
            }
            .onChange(of: phase) { _, new in
                AccessibilityNotification.Announcement(String(localized: new.coach)).post()
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(UrgeColors.background.ignoresSafeArea())
        // Light status bar text on the dark background.
        .preferredColorScheme(.dark)
        // The timer should stay visible.
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .alert("Couldn't save the urge", isPresented: $viewModel.saveFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try again.")
        }
    }

    private func ring(remaining: Int) -> some View {
        let fraction = 1 - Double(remaining) / Double(urgeSeconds)
        let minutes = remaining / 60, seconds = remaining % 60
        return ZStack {
            Circle().stroke(UrgeColors.track, lineWidth: 12)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(UrgeColors.ring, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text(String(format: "%d:%02d", minutes, seconds))
                    .font(.system(size: clockSize, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                Text("of 5:00")
                    .font(.caption)
                    .foregroundStyle(UrgeColors.accent)
            }
        }
        .frame(width: ringSize, height: ringSize)
        .padding(.vertical, 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Time left")
        .accessibilityValue(Duration.seconds(remaining).formatted(.units(allowed: [.minutes, .seconds], width: .wide)))
        .accessibilityIdentifier("urgeTimer")
    }
}

private struct ReasonCard: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "heart.fill")
                .font(.subheadline)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("“\(text)”").font(.subheadline)
                Text("— one of your reasons").font(.caption).opacity(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(UrgeColors.accent)
        .padding(13)
        .background(.white.opacity(0.12), in: .rect(cornerRadius: 16))
        .padding(.top, 18)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    UrgeView(
        viewModel: UrgeViewModel(habitId: UUID(), store: SwiftDataHabitStore.inMemory(), onFinished: { _ in }),
        onClose: {}
    )
}
