import SwiftUI

/// Centralized visual constants so spacing/radii/typography stay consistent and themeable
/// from one place. Components reference these rather than hard-coded literals.
public enum DS {
    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
    }

    public enum Radius {
        public static let card: CGFloat = 12
        public static let chip: CGFloat = 8
    }

    public enum Opacity {
        public static let disabled: Double = 0.4
        public static let secondary: Double = 0.7
    }
}
