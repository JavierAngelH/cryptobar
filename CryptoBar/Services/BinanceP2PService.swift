import Foundation

enum BinanceP2PError: LocalizedError, Sendable {
    case invalidURL
    case rateLimited
    case httpError(statusCode: Int)
    case decodingFailed
    case apiError(code: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Binance P2P URL."
        case .rateLimited:
            return "Binance P2P is rate limiting. Prices will refresh on the next cycle."
        case .httpError(let statusCode):
            return "Binance P2P returned HTTP \(statusCode)."
        case .decodingFailed:
            return "Could not read Binance P2P prices."
        case .apiError(let code):
            return "Binance P2P error \(code)."
        }
    }
}

struct P2PFetchResult: Sendable {
    let quotes: [P2PMethodQuote]
    let failedMethodIDs: Set<String>
    let errorMessage: String?

    var allFailed: Bool {
        !quotes.isEmpty && failedMethodIDs.count == quotes.count
    }
}

struct BinanceP2PService: Sendable {
    private let endpoint = "https://p2p.binance.com/bapi/c2c/v2/friendly/c2c/adv/search"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Best buy and sell for each tracked payment method.
    /// Buy is the lowest USDT ask (tradeType BUY). Sell is the highest USDT bid (tradeType SELL).
    func fetchQuotes(methods: [P2PMethod] = P2PMethod.tracked) async -> P2PFetchResult {
        await withTaskGroup(of: MethodResult.self) { group in
            for (index, method) in methods.enumerated() {
                group.addTask {
                    await self.fetchMethod(method, index: index)
                }
            }

            var results: [MethodResult] = []
            for await result in group {
                results.append(result)
            }
            results.sort { $0.index < $1.index }

            let quotes = results.map(\.quote)
            let failed = Set(results.filter(\.failed).map { $0.quote.method.id })
            let message: String?
            if failed.isEmpty {
                message = nil
            } else if failed.count == quotes.count {
                message = results.compactMap(\.errorMessage).first ?? "Could not load P2P prices."
            } else {
                message = "Some P2P prices are unavailable."
            }
            return P2PFetchResult(quotes: quotes, failedMethodIDs: failed, errorMessage: message)
        }
    }

    private func fetchMethod(_ method: P2PMethod, index: Int) async -> MethodResult {
        do {
            async let buy = searchBestPrice(payType: method.id, tradeType: "BUY")
            async let sell = searchBestPrice(payType: method.id, tradeType: "SELL")
            let buyPrice = try await buy
            let sellPrice = try await sell
            let quote = P2PMethodQuote(
                method: method,
                buyPrice: buyPrice,
                sellPrice: sellPrice,
                updatedAt: Date()
            )
            return MethodResult(index: index, quote: quote, failed: false, errorMessage: nil)
        } catch let error as BinanceP2PError {
            return MethodResult(
                index: index,
                quote: .empty(method),
                failed: true,
                errorMessage: error.localizedDescription
            )
        } catch {
            return MethodResult(
                index: index,
                quote: .empty(method),
                failed: true,
                errorMessage: error.localizedDescription
            )
        }
    }

    /// - Returns: nil when the book has no ads that actually list this payment method.
    private func searchBestPrice(payType: String, tradeType: String) async throws -> Double? {
        let ads = try await searchAds(payType: payType, tradeType: tradeType)
        let prices = ads.compactMap { ad -> Double? in
            guard Self.accepts(ad, payType: payType), let price = Self.parseNumber(ad["price"]) else {
                return nil
            }
            return price
        }
        switch tradeType {
        case "BUY":
            return prices.min()
        case "SELL":
            return prices.max()
        default:
            return nil
        }
    }

    private func searchAds(payType: String, tradeType: String) async throws -> [[String: Any]] {
        guard let url = URL(string: endpoint) else { throw BinanceP2PError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("web", forHTTPHeaderField: "clienttype")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )

        let body: [String: Any] = [
            "asset": "USDT",
            "fiat": "USD",
            "merchantCheck": false,
            "page": 1,
            "payTypes": [payType],
            "rows": 20,
            "tradeType": tradeType
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BinanceP2PError.httpError(statusCode: -1)
        }
        if http.statusCode == 429 {
            throw BinanceP2PError.rateLimited
        }
        guard (200 ... 299).contains(http.statusCode) else {
            throw BinanceP2PError.httpError(statusCode: http.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BinanceP2PError.decodingFailed
        }

        if let code = json["code"] as? String, code != "000000" {
            throw BinanceP2PError.apiError(code: code)
        }

        let entries = json["data"] as? [[String: Any]] ?? []
        return entries.compactMap { entry in
            entry["adv"] as? [String: Any]
        }
    }

    private static func accepts(_ ad: [String: Any], payType: String) -> Bool {
        let methods = ad["tradeMethods"] as? [[String: Any]] ?? []
        let target = payType.lowercased()
        return methods.contains { method in
            [method["identifier"], method["payType"], method["tradeMethodName"]].contains { value in
                (value as? String)?.lowercased() == target
            }
        }
    }

    private static func parseNumber(_ value: Any?) -> Double? {
        switch value {
        case let number as Double:
            return number
        case let number as Int:
            return Double(number)
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            return Double(string)
        default:
            return nil
        }
    }
}

private struct MethodResult: Sendable {
    let index: Int
    let quote: P2PMethodQuote
    let failed: Bool
    let errorMessage: String?
}
