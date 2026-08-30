import SwiftUI

enum CryptoBarColors {
    static let panelBackground = Color(nsColor: .windowBackgroundColor)
    static let primaryText = Color(nsColor: .labelColor)
    static let secondaryText = Color(nsColor: .secondaryLabelColor)
}

extension View {
    func cryptoBarPanelStyle() -> some View {
        foregroundStyle(CryptoBarColors.primaryText)
            .background(CryptoBarColors.panelBackground)
    }
}
