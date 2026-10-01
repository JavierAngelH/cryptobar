import Foundation

struct PriceQuote: Identifiable, Sendable {
    var id: String { coin.id }
    let coin: Coin
    let price: Double
    let change24h: Double?
    let lastUpdated: Date

    var formattedPrice: String {
        PriceFormatter.format(price, currencyCode: "USD")
    }

    var formattedChange24h: String? {
        guard let change24h else { return nil }
        let sign = change24h >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", change24h))%"
    }

    var isPositiveChange: Bool {
        (change24h ?? 0) >= 0
    }
}

enum PriceFormatter {
    static func format(_ value: Double, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode.uppercased()
        formatter.maximumFractionDigits = value >= 1000 ? 0 : value >= 1 ? 2 : 4
        formatter.minimumFractionDigits = value >= 1000 ? 0 : value >= 1 ? 2 : 4
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func compactSummary(symbol: String, price: Double, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode.uppercased()
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        let priceText = formatter.string(from: NSNumber(value: price)) ?? "\(Int(price))"
        return "\(symbol.uppercased()) \(priceText)"
    }

    static func compactAxis(_ value: Double, currencyCode: String) -> String {
        let code = currencyCode.uppercased()
        if value >= 1_000_000 {
            return String(format: "%.1fM %@", value / 1_000_000, code)
        }
        if value >= 1_000 {
            return String(format: "%.1fK %@", value / 1_000, code)
        }
        return format(value, currencyCode: currencyCode)
    }

    /// USDT/USD P2P quotes sit near 1.000, so keep three decimal places.
    static func formatP2P(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 3
        formatter.maximumFractionDigits = 3
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.3f", value)
    }

    static func formatP2PPlain(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 3
        formatter.maximumFractionDigits = 3
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.3f", value)
    }
}
