import Foundation

struct Coin: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let symbol: String
    let name: String

    var displaySymbol: String {
        symbol.uppercased()
    }

    var coingeckoURL: URL {
        URL(string: "https://www.coingecko.com/en/coins/\(id)")!
    }
}

extension Coin {
    static let bitcoin = Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin")
    static let ethereum = Coin(id: "ethereum", symbol: "eth", name: "Ethereum")
    static let solana = Coin(id: "solana", symbol: "sol", name: "Solana")

    static let defaults: [Coin] = [.bitcoin, .ethereum, .solana]
}
