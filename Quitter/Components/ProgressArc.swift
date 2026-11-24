import SwiftUI

struct ProgressArc: View {
    enum Size {
        case large, compact

        var maxWidth: CGFloat { self == .large ? 280 : 210 }
        var stroke: CGFloat { self == .large ? 14 : 10 }
        var showEnds: Bool { self == .large }
    }

    let elapsedSeconds: Int
    /// The habit's personal goals, which join the ladder the arc fills up to.
    var personalGoals: [PersonalGoal] = []
    var size: Size = .large
    var progressColor: Color = Palette.primary
    var trackColor: Color = Palette.primary.opacity(0.16)
    var contentColor: Color = Palette.primary
    var secondaryColor: Color = Palette.onSurfaceVariant

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var available: CGFloat = 280

    private static let startAngle = 160.0
    private static let sweep = 220.0
    private static let belowCentre = sin(20 * Double.pi / 180)

    var body: some View {
        let text = ArcText(elapsedSeconds: elapsedSeconds, personal: personalGoals)
        let fraction = Goals.fraction(elapsedSeconds: elapsedSeconds, personal: personalGoals)
        let width = min(available, size.maxWidth)
        let stroke = size.stroke
        let radius = (width - stroke) / 2
        let arcHeight = stroke + radius * (1 + Self.belowCentre) // includes the round caps
        let top = stroke + radius * 0.35

        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                ZStack {
                    ArcShape(start: Self.startAngle, sweep: Self.sweep, fraction: 1, stroke: stroke)
                        .stroke(trackColor, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                    ArcShape(start: Self.startAngle, sweep: Self.sweep, fraction: max(0.5 / Self.sweep, fraction), stroke: stroke)
                        .stroke(progressColor, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                        // Animates real jumps (a slip, a new goal), not the once-a-second tick: a never-ending
                        // animation would keep the app from ever going idle.
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.7), value: (fraction * 200).rounded())
                }
                .frame(width: width, height: arcHeight)

                ArcCentre(text: text, size: size, contentColor: contentColor, secondaryColor: secondaryColor)
                    .frame(width: width * 0.6)
                    .frame(minHeight: arcHeight - top)
                    .padding(.top, top)
            }
            .frame(width: width)

            if size.showEnds {
                HStack(alignment: .top) {
                    Text(verbatim: 0.formatted())
                    Spacer(minLength: 8)
                    Text(text.goal).multilineTextAlignment(.trailing)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(secondaryColor)
                .frame(width: width)
                .padding(.top, 2)
            }

            Text(text.progress)
                .font(size == .large ? .subheadline : .footnote)
                .foregroundStyle(secondaryColor)
                .multilineTextAlignment(.center)
                .frame(width: width)
                .padding(.top, size.showEnds ? 4 : 6)
        }
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { available = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text.accessibility)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

private struct ArcCentre: View {
    let text: ArcText
    let size: ProgressArc.Size
    let contentColor: Color
    let secondaryColor: Color

    @ScaledMetric(relativeTo: .largeTitle) private var largeNumber: CGFloat = 60
    @ScaledMetric(relativeTo: .largeTitle) private var compactNumber: CGFloat = 44
    /// The point sizes of .subheadline (large) and .footnote (compact), scaled like them.
    @ScaledMetric(relativeTo: .subheadline) private var largeDetail: CGFloat = 15
    @ScaledMetric(relativeTo: .footnote) private var compactDetail: CGFloat = 13

    private var detailSize: CGFloat { size == .large ? largeDetail : compactDetail }

    var body: some View {
        let big = size == .large ? largeNumber : compactNumber
        VStack(spacing: 0) {
            Text(text.big)
                .font(.system(size: big, weight: .medium).monospacedDigit())
                .foregroundStyle(contentColor)
                .minimumScaleFactor((size == .large ? 18 : 14) / big)
            if let unit = text.unit {
                Text(unit)
                    .font(size == .large ? .callout.weight(.medium) : .subheadline.weight(.medium))
                    .foregroundStyle(contentColor)
                    .minimumScaleFactor(0.5)
            }
            if let detail = text.detail {
                Text(detail)
                    .font((size == .large ? Font.subheadline : .footnote).monospacedDigit())
                    .foregroundStyle(secondaryColor)
                    // Shrinks rather than cutting "13 h 36 min" short, down to about 9 pt as on Android.
                    .minimumScaleFactor(min(1, 9 / detailSize))
            }
        }
        .lineLimit(1)
        .multilineTextAlignment(.center)
    }
}

private struct ArcShape: Shape {
    let start: Double
    let sweep: Double
    var fraction: Double
    let stroke: CGFloat

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let radius = (rect.width - stroke) / 2
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.minY + stroke / 2 + radius),
            radius: radius,
            startAngle: .degrees(start),
            endAngle: .degrees(start + sweep * min(1, max(0, fraction))),
            clockwise: false
        )
        return path
    }
}

#Preview("Sizes") {
    ScrollView {
        VStack(spacing: 32) {
            ProgressArc(elapsedSeconds: 18_429)
            ProgressArc(elapsedSeconds: 755 * 86_400 + 13 * 3_600 + 36 * 60)
            ProgressArc(elapsedSeconds: 9_999 * 86_400 + 23 * 3_600 + 59 * 60, size: .compact)
        }
        .padding()
    }
}

#Preview("Dark, largest text") {
    ScrollView {
        VStack(spacing: 32) {
            ProgressArc(elapsedSeconds: 9_999 * 86_400 + 23 * 3_600 + 59 * 60)
            ProgressArc(elapsedSeconds: 3_600, size: .compact)
        }
        .padding()
    }
    .background(Palette.background)
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility5)
}
