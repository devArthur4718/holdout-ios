import SwiftUI

/// A not-yet-built screen reached from another one.
struct ComingSoonView: View {
    let title: String

    var body: some View {
        Text("Coming soon")
            .foregroundStyle(Palette.onSurfaceVariant)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle(LocalizedStringKey(title))
            .navigationBarTitleDisplayMode(.inline)
    }
}
