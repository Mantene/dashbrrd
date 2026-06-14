import SwiftUI

/// Cross-platform shims for iOS-only SwiftUI modifiers. The package compiles on macOS (for
/// fast `swift test`) where these modifiers don't exist, so feature views call these instead
/// of the raw modifiers and get a no-op off iOS.
public extension View {
    @ViewBuilder
    func dsTextContentField(autocapitalize: Bool = false) -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(autocapitalize ? .words : .never)
            .autocorrectionDisabled()
        #else
        self.autocorrectionDisabled()
        #endif
    }

    @ViewBuilder
    func dsURLKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
        #else
        self.autocorrectionDisabled()
        #endif
    }

    @ViewBuilder
    func dsNumberKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.numberPad)
        #else
        self
        #endif
    }

    @ViewBuilder
    func dsInlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
