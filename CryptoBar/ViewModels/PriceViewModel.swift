import Foundation
import Observation

@MainActor
@Observable
final class PriceViewModel {
    var quotes: [PriceQuote] = []
    var isLoading = false
    var errorMessage: String?
    var isRateLimited = false

    var selectedCoinIDs: [String] {
        didSet { persist() }
    }

    var vsCurrency: String {
        didSet { persist() }
    }

    var refreshInterval: TimeInterval {
        didSet {
            persist()
            restartPolling()
        }
    }

    var apiKey: String {
        didSet { persist() }
    }

    var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
            if let error = LaunchAtLoginManager.setEnabled(launchAtLogin) {
                launchAtLoginError = error
                launchAtLogin = LaunchAtLoginManager.isEnabled
            } else {
                launchAtLoginError = nil
            }
        }
    }

    var launchAtLoginError: String?

    var lastFetchDate: Date?
    var catalog: [Coin] { CoinCatalog.shared.coins }

    private let service = CoinGeckoService()
    private var pollingTask: Task<Void, Never>?
    private var fetchTask: Task<Void, Never>?
    private var backoffSeconds: TimeInterval = 0

    private enum Keys {
        static let selectedCoinIDs = "selectedCoinIDs"
        static let vsCurrency = "vsCurrency"
        static let refreshInterval = "refreshInterval"
        static let apiKey = "apiKey"
        static let launchAtLogin = "launchAtLogin"
    }

    init() {
        let defaults = UserDefaults.standard
        selectedCoinIDs = defaults.stringArray(forKey: Keys.selectedCoinIDs)
            ?? Coin.defaults.map(\.id)
        vsCurrency = defaults.string(forKey: Keys.vsCurrency) ?? "usd"
        refreshInterval = defaults.object(forKey: Keys.refreshInterval) as? TimeInterval ?? 60
        apiKey = defaults.string(forKey: Keys.apiKey) ?? ""
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        launchAtLoginError = nil
    }

    func start() {
        Task {
            await CoinCatalog.shared.loadIfNeeded(apiKey: apiKey)
        }
        restartPolling()
        if launchAtLogin && !LaunchAtLoginManager.isEnabled {
            _ = LaunchAtLoginManager.setEnabled(true)
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        fetchTask?.cancel()
        fetchTask = nil
    }

    func refreshIfStale(force: Bool = false) {
        if force || shouldRefreshNow() {
            fetchPrices()
        }
    }

    func fetchPrices() {
        fetchTask?.cancel()
        fetchTask = Task {
            await performFetch()
        }
    }

    func menuBarSummary() -> String {
        guard let first = quotes.first else { return "CryptoBar" }
        return PriceFormatter.compactSummary(
            symbol: first.coin.displaySymbol,
            price: first.price,
            currencyCode: vsCurrency
        )
    }

    func toggleCoin(_ coin: Coin) {
        if selectedCoinIDs.contains(coin.id) {
            selectedCoinIDs.removeAll { $0 == coin.id }
        } else {
            selectedCoinIDs.append(coin.id)
        }
        fetchPrices()
    }

    func isCoinSelected(_ coin: Coin) -> Bool {
        selectedCoinIDs.contains(coin.id)
    }

    func syncLaunchAtLoginState() {
        launchAtLogin = LaunchAtLoginManager.isEnabled
    }

    private func shouldRefreshNow() -> Bool {
        guard let lastFetchDate else { return true }
        return Date().timeIntervalSince(lastFetchDate) > 30
    }

    private func restartPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                let interval = max(refreshInterval, 30)
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }
                fetchPrices()
            }
        }
        fetchPrices()
    }

    private func performFetch() async {
        guard !selectedCoinIDs.isEmpty else {
            quotes = []
            errorMessage = CoinGeckoError.emptySelection.errorDescription
            isLoading = false
            return
        }

        if backoffSeconds > 0 {
            isRateLimited = true
            errorMessage = "Rate limited — retrying in \(Int(backoffSeconds))s…"
            try? await Task.sleep(for: .seconds(backoffSeconds))
            guard !Task.isCancelled else { return }
        }

        isLoading = quotes.isEmpty
        errorMessage = nil
        isRateLimited = false

        do {
            let fetched = try await service.fetchPrices(
                coinIDs: selectedCoinIDs,
                vsCurrency: vsCurrency,
                apiKey: apiKey,
                catalog: catalog
            )
            guard !Task.isCancelled else { return }
            quotes = fetched
            lastFetchDate = Date()
            backoffSeconds = 0
            errorMessage = nil
        } catch CoinGeckoError.rateLimited(let retryAfter) {
            guard !Task.isCancelled else { return }
            backoffSeconds = retryAfter ?? min(max(backoffSeconds * 2, 15), 120)
            isRateLimited = true
            errorMessage = CoinGeckoError.rateLimited(retryAfter: retryAfter).errorDescription
            scheduleRetry(after: backoffSeconds)
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func scheduleRetry(after seconds: TimeInterval) {
        fetchTask?.cancel()
        fetchTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            await performFetch()
        }
    }

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(selectedCoinIDs, forKey: Keys.selectedCoinIDs)
        defaults.set(vsCurrency, forKey: Keys.vsCurrency)
        defaults.set(refreshInterval, forKey: Keys.refreshInterval)
        defaults.set(apiKey, forKey: Keys.apiKey)
    }
}
