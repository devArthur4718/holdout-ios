import SwiftUI

/// Brand colors from the Holdout design. Each one has a light and dark value in Assets.xcassets.
enum Palette {
    static let background = Color("Background")
    static let surfaceContainer = Color("SurfaceContainer")
    static let onSurface = Color("OnSurface")
    static let onSurfaceVariant = Color("OnSurfaceVariant")
    static let primary = Color("Primary")
    static let onPrimary = Color("OnPrimary")
    static let primaryContainer = Color("PrimaryContainer")
    static let onPrimaryContainer = Color("OnPrimaryContainer")
    static let secondaryContainer = Color("SecondaryContainer")
    static let outline = Color("Outline")
    static let outlineVariant = Color("OutlineVariant")
    static let errorContainer = Color("ErrorContainer")
    static let onErrorContainer = Color("OnErrorContainer")
}

/// iOS corner radii from the design.
enum Radius {
    static let button: CGFloat = 14
    static let card: CGFloat = 14
    static let iconTile: CGFloat = 20
}
