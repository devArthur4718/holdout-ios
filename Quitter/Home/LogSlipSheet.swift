import SwiftUI

/// Confirms a slip. Nothing happens until "Reset counter".
struct LogSlipSheet: View {
    let kind: HabitKind
    let onCancel: () -> Void
    let onConfirm: (SlipTrigger?) -> Void

    @State private var trigger: SlipTrigger?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Log a slip")
                    .font(.title2)
                    .accessibilityAddTraits(.isHeader)
                Text("Nothing is deleted. Your longest streak and total savings stay — the counter starts again from now.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.onSurfaceVariant)

                Text("What led to it? (optional)")
                    .font(.subheadline.weight(.semibold))
                FlowLayout {
                    ForEach(SlipTrigger.forKind(kind)) { item in
                        TriggerChip(trigger: item, isSelected: item == trigger) {
                            // Tapping the picked one again clears it: the trigger is optional.
                            trigger = item == trigger ? nil : item
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button(action: onCancel) {
                        Text("Cancel").frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .foregroundStyle(Palette.primary)
                    .overlay(RoundedRectangle(cornerRadius: Radius.button).strokeBorder(Palette.outline))

                    Button { onConfirm(trigger) } label: {
                        Text("Reset counter").frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .foregroundStyle(Palette.onErrorContainer)
                    .background(Palette.errorContainer, in: .rect(cornerRadius: Radius.button))
                }
                .font(.subheadline.weight(.medium))
                .padding(.top, 2)

                if Features.ads {
                    Text("No ads are shown anywhere in this flow.")
                        .font(.caption2)
                        .foregroundStyle(Palette.outline)
                        .frame(maxWidth: .infinity)
                }
            }
            .foregroundStyle(Palette.onSurface)
            .padding(20)
            .padding(.top, 8)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct TriggerChip: View {
    let trigger: SlipTrigger
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(trigger.label)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Palette.secondaryContainer : .clear, in: .rect(cornerRadius: 8))
                .overlay {
                    if !isSelected { RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.outline) }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        LogSlipSheet(kind: .smoking, onCancel: {}, onConfirm: { _ in })
    }
}
