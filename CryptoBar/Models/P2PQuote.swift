import Foundation

/// A Binance P2P payment method for USDT/USD.
/// Panama Banesco is `BanescoPanama`. The `Banesco` identifier is a different
/// market: sell ads mix other rails, and buy ads are often empty.
struct P2PMethod: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let menuBarName: String

    static let tracked: [P2PMethod] = [
        P2PMethod(id: "Zinli", name: "Zinli", menuBarName: "Zinli"),
        P2PMethod(id: "BanescoPanama", name: "Banesco Panama", menuBarName: "Banesco")
    ]
}

struct P2PMethodQuote: Identifiable, Sendable {
    var id: String { method.id }
    let method: P2PMethod
    /// Lowest price to buy USDT (Binance tradeType BUY).
    let buyPrice: Double?
    /// Highest price to sell USDT (Binance tradeType SELL).
    let sellPrice: Double?
    let updatedAt: Date

    var hasPrice: Bool {
        buyPrice != nil || sellPrice != nil
    }

    var menuBarSummary: String {
        let buy = buyPrice.map(PriceFormatter.formatP2PPlain) ?? "—"
        let sell = sellPrice.map(PriceFormatter.formatP2PPlain) ?? "—"
        return "\(method.menuBarName) \(buy)/\(sell)"
    }

    static func empty(_ method: P2PMethod, at date: Date = Date()) -> P2PMethodQuote {
        P2PMethodQuote(method: method, buyPrice: nil, sellPrice: nil, updatedAt: date)
    }
}
