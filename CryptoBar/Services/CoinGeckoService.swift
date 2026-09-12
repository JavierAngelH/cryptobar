import Foundation

enum CoinGeckoError: LocalizedError {
    case invalidURL
    case rateLimited(retryAfter: TimeInterval?)
    case httpError(statusCode: Int)
    case decodingFailed
    case emptySelection

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL."
        case .rateLimited:
            return "Rate limited by CoinGecko. Retrying shortly…"
        case .httpError(let statusCode):
            return "CoinGecko returned HTTP \(statusCode)."
        case .decodingFailed:
            return "Could not read price data."
        case .emptySelection:
            return "Add at least one coin in Settings."
        }
    }
}

struct CoinGeckoService: Sendable {
    private let baseURL = "https://api.coingecko.com/api/v3"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchPrices(
        coinIDs: [String],
        vsCurrency: String,
        apiKey: String?,
        catalog: [Coin]
    ) async throws -> [PriceQuote] {
        guard !coinIDs.isEmpty else { throw CoinGeckoError.emptySelection }

        let ids = coinIDs.joined(separator: ",")
        var components = URLComponents(string: "\(baseURL)/simple/price")
        components?.queryItems = [
            URLQueryItem(name: "ids", value: ids),
            URLQueryItem(name: "vs_currencies", value: vsCurrency.lowercased()),
            URLQueryItem(name: "include_24hr_change", value: "true"),
            URLQueryItem(name: "include_last_updated_at", value: "true")
        ]

        guard let url = components?.url else { throw CoinGeckoError.invalidURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        if let apiKey, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-cg-demo-api-key")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CoinGeckoError.httpError(statusCode: -1)
        }

        if http.statusCode == 429 {
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw CoinGeckoError.rateLimited(retryAfter: retryAfter)
        }

        guard (200 ... 299).contains(http.statusCode) else {
            throw CoinGeckoError.httpError(statusCode: http.statusCode)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]]
        else {
            throw CoinGeckoError.decodingFailed
        }

        let currency = vsCurrency.lowercased()
        let catalogByID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
        let now = Date()

        return coinIDs.compactMap { coinID in
            guard let entry = json[coinID] else { return nil }
            guard let price = Self.parseNumber(entry[currency]) else { return nil }

            let changeKey = "\(currency)_24h_change"
            let change = Self.parseNumber(entry[changeKey])
            let updatedAt: Date
            if let timestamp = entry["last_updated_at"] as? TimeInterval {
                updatedAt = Date(timeIntervalSince1970: timestamp)
            } else {
                updatedAt = now
            }

            let coin = catalogByID[coinID] ?? Coin(id: coinID, symbol: coinID, name: coinID.capitalized)
            return PriceQuote(coin: coin, price: price, change24h: change, lastUpdated: updatedAt)
        }
    }

    func fetchMarketChart(
        coinID: String,
        vsCurrency: String,
        days: Int,
        apiKey: String?
    ) async throws -> [PriceChartPoint] {
        var components = URLComponents(string: "\(baseURL)/coins/\(coinID)/market_chart")
        components?.queryItems = [
            URLQueryItem(name: "vs_currency", value: vsCurrency.lowercased()),
            URLQueryItem(name: "days", value: String(days))
        ]

        guard let url = components?.url else { throw CoinGeckoError.invalidURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        if let apiKey, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-cg-demo-api-key")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CoinGeckoError.httpError(statusCode: -1)
        }

        if http.statusCode == 429 {
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw CoinGeckoError.rateLimited(retryAfter: retryAfter)
        }

        guard (200 ... 299).contains(http.statusCode) else {
            throw CoinGeckoError.httpError(statusCode: http.statusCode)
        }

        struct MarketChartResponse: Decodable {
            let prices: [[Double]]
        }

        let decoded = try JSONDecoder().decode(MarketChartResponse.self, from: data)
        return decoded.prices.compactMap { entry in
            guard entry.count >= 2 else { return nil }
            return PriceChartPoint(
                date: Date(timeIntervalSince1970: entry[0] / 1000),
                price: entry[1]
            )
        }
    }

    func fetchCoinList(apiKey: String?) async throws -> [Coin] {
        guard let url = URL(string: "\(baseURL)/coins/list") else {
            throw CoinGeckoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        if let apiKey, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-cg-demo-api-key")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CoinGeckoError.httpError(statusCode: -1)
        }

        if http.statusCode == 429 {
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw CoinGeckoError.rateLimited(retryAfter: retryAfter)
        }

        guard (200 ... 299).contains(http.statusCode) else {
            throw CoinGeckoError.httpError(statusCode: http.statusCode)
        }

        struct RemoteCoin: Decodable {
            let id: String
            let symbol: String
            let name: String
        }

        let remote = try JSONDecoder().decode([RemoteCoin].self, from: data)
        return remote.map { Coin(id: $0.id, symbol: $0.symbol, name: $0.name) }
    }

    private static func parseNumber(_ value: Any?) -> Double? {
        switch value {
        case let number as Double:
            return number
        case let number as Int:
            return Double(number)
        case let number as NSNumber:
            return number.doubleValue
        default:
            return nil
        }
    }
}
