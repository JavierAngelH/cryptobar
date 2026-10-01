import SwiftUI

struct P2PSectionView: View {
    let quotes: [P2PMethodQuote]
    let isLoading: Bool
    let errorMessage: String?
    let lastFetchDate: Date?
    let onRetry: () -> Void

    private let priceColumnWidth: CGFloat = 76

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if isLoading && quotes.isEmpty {
                ForEach(0 ..< 2, id: \.self) { _ in
                    CoinRowSkeleton()
                }
            } else if quotes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(errorMessage ?? "P2P prices are unavailable.")
                        .font(.caption)
                        .foregroundStyle(CryptoBarColors.secondaryText)
                    Button("Retry", action: onRetry)
                        .controlSize(.small)
                }
            } else {
                ForEach(quotes) { quote in
                    methodRow(quote)
                }

                if let errorMessage {
                    HStack(alignment: .center, spacing: 8) {
                        Text(errorMessage)
                            .font(.caption2)
                            .foregroundStyle(CryptoBarColors.secondaryText)
                        Spacer(minLength: 8)
                        Button("Retry", action: onRetry)
                            .controlSize(.mini)
                    }
                }

                if let lastFetchDate {
                    Text("P2P updated \(lastFetchDate.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(CryptoBarColors.secondaryText)
                }
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private var header: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Text("P2P USDT/USD")
                    .font(.caption.weight(.semibold))
                if isLoading && !quotes.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            Spacer(minLength: 8)
            Text("Buy")
                .frame(width: priceColumnWidth, alignment: .trailing)
            Text("Sell")
                .frame(width: priceColumnWidth, alignment: .trailing)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(CryptoBarColors.secondaryText)
    }

    private func methodRow(_ quote: P2PMethodQuote) -> some View {
        HStack(spacing: 8) {
            Text(quote.method.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(CryptoBarColors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            priceText(quote.buyPrice, side: "Buy", tint: .red)
            priceText(quote.sellPrice, side: "Sell", tint: .green)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: quote))
    }

    private func priceText(_ price: Double?, side: String, tint: Color) -> some View {
        Text(price.map(PriceFormatter.formatP2P) ?? "—")
            .font(.subheadline.monospacedDigit().weight(.medium))
            .foregroundStyle(price == nil ? CryptoBarColors.secondaryText : tint)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: priceColumnWidth, alignment: .trailing)
            .help(price.map { "\(side) \(PriceFormatter.formatP2P($0))" } ?? "No \(side.lowercased()) ads right now")
    }

    private func accessibilityLabel(for quote: P2PMethodQuote) -> String {
        let buy = quote.buyPrice.map(PriceFormatter.formatP2P) ?? "no ads"
        let sell = quote.sellPrice.map(PriceFormatter.formatP2P) ?? "no ads"
        return "\(quote.method.name), buy \(buy), sell \(sell)"
    }
}
