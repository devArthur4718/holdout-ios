import SwiftUI

/// Stand-in for screens that are not built yet.
struct PlaceholderView: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.largeTitle)
            .foregroundStyle(Palette.onSurface)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}
