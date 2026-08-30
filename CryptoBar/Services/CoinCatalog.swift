import Foundation

@MainActor
final class CoinCatalog {
    static let shared = CoinCatalog()

    private let cacheKey = "coinCatalogCache"
    private let cacheDateKey = "coinCatalogCacheDate"
    private let cacheTTL: TimeInterval = 86_400
    private let service = CoinGeckoService()

    private(set) var coins: [Coin] = Coin.defaults
    private(set) var isLoading = false

    func loadIfNeeded(apiKey: String?) async {
        if let cached = readCache(), !cached.isEmpty {
            coins = cached
            return
        }
        await refresh(apiKey: apiKey)
    }

    func refresh(apiKey: String?) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let fetched = try await service.fetchCoinList(apiKey: apiKey)
            coins = fetched
            writeCache(fetched)
        } catch {
            if coins.isEmpty {
                coins = Coin.defaults
            }
        }
    }

    func coin(for id: String) -> Coin? {
        coins.first { $0.id == id }
    }

    private func readCache() -> [Coin]? {
        guard
            let date = UserDefaults.standard.object(forKey: cacheDateKey) as? Date,
            Date().timeIntervalSince(date) < cacheTTL,
            let data = UserDefaults.standard.data(forKey: cacheKey),
            let decoded = try? JSONDecoder().decode([Coin].self, from: data),
            !decoded.isEmpty
        else {
            return nil
        }
        return decoded
    }

    private func writeCache(_ coins: [Coin]) {
        guard let data = try? JSONEncoder().encode(coins) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
        UserDefaults.standard.set(Date(), forKey: cacheDateKey)
    }
}
