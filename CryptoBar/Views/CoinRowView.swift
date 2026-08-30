import SwiftUI

struct CoinRowView: View {
    let quote: PriceQuote
    let currencyCode: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(quote.coin.name)
                    .font(.headline)
                Text(quote.coin.displaySymbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(PriceFormatter.format(quote.price, currencyCode: currencyCode))
                    .font(.headline.monospacedDigit())

                if let change = quote.formattedChange24h {
                    Text(change)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(quote.isPositiveChange ? .green : .red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct CoinRowSkeleton: View {
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 100, height: 14)
            Spacer()
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 72, height: 14)
        }
        .padding(.vertical, 8)
    }
}
