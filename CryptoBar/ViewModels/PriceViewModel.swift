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

    var menuBarRotationInterval: TimeInterval {
        didSet { persist() }
    }

    var launchAtLogin: Bool {
        didSet {
            guard !suppressLaunchAtLoginSideEffects else { return }
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
            if let error = LaunchAtLoginManager.setEnabled(launchAtLogin) {
                launchAtLoginError = error
                suppressLaunchAtLoginSideEffects = true
                launchAtLogin = LaunchAtLoginManager.isEnabled
                suppressLaunchAtLoginSideEffects = false
            } else {
                launchAtLoginError = nil
            }
        }
    }

    var launchAtLoginError: String?

    var lastFetchDate: Date?
    var catalog: [Coin] { CoinCatalog.shared.coins }

    var p2pQuotes: [P2PMethodQuote] = []
    var p2pIsLoading = false
    var p2pErrorMessage: String?
    var p2pLastFetchDate: Date?

    private let service = CoinGeckoService()
    private let p2pService = BinanceP2PService()
    private var pollingTask: Task<Void, Never>?
    private var p2pPollingTask: Task<Void, Never>?
    private var fetchTask: Task<Void, Never>?
    private var p2pFetchTask: Task<Void, Never>?
    private var backoffSeconds: TimeInterval = 0
    private var suppressLaunchAtLoginSideEffects = false

    /// P2P is four HTTP calls per refresh, so keep it on a slower floor than coin prices.
    private var p2pRefreshInterval: TimeInterval {
        max(refreshInterval, 60)
    }

    private enum Keys {
        static let selectedCoinIDs = "selectedCoinIDs"
        static let vsCurrency = "vsCurrency"
        static let refreshInterval = "refreshInterval"
        static let apiKey = "apiKey"
        static let launchAtLogin = "launchAtLogin"
        static let menuBarRotationInterval = "menuBarRotationInterval"
    }

    private(set) var menuBarDisplayIndex = 0

    init() {
        let defaults = UserDefaults.standard
        selectedCoinIDs = defaults.stringArray(forKey: Keys.selectedCoinIDs)
            ?? Coin.defaults.map(\.id)
        vsCurrency = defaults.string(forKey: Keys.vsCurrency) ?? "usd"
        refreshInterval = defaults.object(forKey: Keys.refreshInterval) as? TimeInterval ?? 60
        menuBarRotationInterval = defaults.object(forKey: Keys.menuBarRotationInterval) as? TimeInterval ?? 5
        apiKey = defaults.string(forKey: Keys.apiKey) ?? ""
        suppressLaunchAtLoginSideEffects = true
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        suppressLaunchAtLoginSideEffects = false
        launchAtLoginError = nil
    }

    func start() {
        CoinCatalog.shared.preloadInBackground(apiKey: apiKey)
        restartPolling()
        if launchAtLogin && !LaunchAtLoginManager.isEnabled {
            _ = LaunchAtLoginManager.setEnabled(true)
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        p2pPollingTask?.cancel()
        p2pPollingTask = nil
        fetchTask?.cancel()
        fetchTask = nil
        p2pFetchTask?.cancel()
        p2pFetchTask = nil
    }

    func refreshIfStale(force: Bool = false) {
        if force || shouldRefreshNow() {
            fetchPrices()
        }
        if force || shouldRefreshP2PNow() {
            fetchP2P()
        }
    }

    func fetchPrices() {
        fetchTask?.cancel()
        fetchTask = Task {
            await performFetch()
        }
    }

    func fetchP2P() {
        p2pFetchTask?.cancel()
        p2pFetchTask = Task {
            await performP2PFetch()
        }
    }

    func menuBarSlotCount() -> Int {
        menuBarSlots().count
    }

    func menuBarSummary() -> String {
        switch currentMenuBarSlot() {
        case .coin(let quote):
            return PriceFormatter.compactSummary(
                symbol: quote.coin.displaySymbol,
                price: quote.price,
                currencyCode: vsCurrency
            )
        case .p2p(let quote):
            return quote.menuBarSummary
        case nil:
            return "CryptoBar"
        }
    }

    /// 24h change for the coin currently in the menu bar. Nil for P2P rows.
    func menuBarPriceChange() -> Double? {
        guard case .coin(let quote) = currentMenuBarSlot() else { return nil }
        return quote.change24h
    }

    func advanceMenuBarDisplay() {
        let count = menuBarSlotCount()
        guard count > 1, menuBarRotationInterval > 0 else { return }
        menuBarDisplayIndex = (menuBarDisplayIndex + 1) % count
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
        suppressLaunchAtLoginSideEffects = true
        launchAtLogin = LaunchAtLoginManager.isEnabled
        suppressLaunchAtLoginSideEffects = false
    }

    private func shouldRefreshNow() -> Bool {
        guard let lastFetchDate else { return true }
        return Date().timeIntervalSince(lastFetchDate) > 30
    }

    private func shouldRefreshP2PNow() -> Bool {
        guard let p2pLastFetchDate else { return true }
        return Date().timeIntervalSince(p2pLastFetchDate) >= p2pRefreshInterval
    }

    private enum MenuBarSlot {
        case coin(PriceQuote)
        case p2p(P2PMethodQuote)
    }

    private func menuBarSlots() -> [MenuBarSlot] {
        var slots = quotes.map { MenuBarSlot.coin($0) }
        if menuBarRotationInterval > 0 {
            slots += p2pQuotes.filter(\.hasPrice).map { MenuBarSlot.p2p($0) }
        }
        return slots
    }

    private func currentMenuBarSlot() -> MenuBarSlot? {
        let slots = menuBarSlots()
        guard !slots.isEmpty else { return nil }
        if menuBarRotationInterval <= 0 {
            return slots.first
        }
        return slots[menuBarDisplayIndex % slots.count]
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

        p2pPollingTask?.cancel()
        p2pPollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(p2pRefreshInterval))
                guard !Task.isCancelled else { return }
                fetchP2P()
            }
        }

        fetchPrices()
        fetchP2P()
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
            if fetched.isEmpty {
                errorMessage = "Could not parse prices from CoinGecko."
            } else {
                quotes = fetched
                lastFetchDate = Date()
                backoffSeconds = 0
                errorMessage = nil
            }
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

    private func performP2PFetch() async {
        p2pIsLoading = p2pQuotes.isEmpty

        let result = await p2pService.fetchQuotes()
        guard !Task.isCancelled else { return }

        if result.allFailed && p2pQuotes.contains(where: \.hasPrice) {
            p2pErrorMessage = result.errorMessage
        } else {
            p2pQuotes = mergedP2PQuotes(result)
            p2pErrorMessage = result.errorMessage
            if !result.allFailed {
                p2pLastFetchDate = Date()
            }
        }

        p2pIsLoading = false
    }

    private func mergedP2PQuotes(_ result: P2PFetchResult) -> [P2PMethodQuote] {
        result.quotes.map { incoming in
            guard result.failedMethodIDs.contains(incoming.id),
                  let previous = p2pQuotes.first(where: { $0.id == incoming.id }),
                  previous.hasPrice
            else {
                return incoming
            }
            return previous
        }
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
        defaults.set(menuBarRotationInterval, forKey: Keys.menuBarRotationInterval)
        defaults.set(apiKey, forKey: Keys.apiKey)
    }
}
