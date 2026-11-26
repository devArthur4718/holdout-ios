import SwiftUI

/// A short message at the bottom that goes away by itself, like an Android snackbar.
struct Toast: View {
    let text: String
    let onDone: () -> Void

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Palette.background)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Palette.onSurface, in: .rect(cornerRadius: 10))
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onTapGesture(perform: onDone)
            .accessibilityIdentifier("toast")
            .task(id: text) {
                AccessibilityNotification.Announcement(text).post()
                try? await Task.sleep(for: .seconds(3.2))
                onDone()
            }
    }
}
