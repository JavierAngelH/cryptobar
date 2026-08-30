import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: PriceViewModel
    var onDone: (() -> Void)?

    @State private var searchText = ""

    private let currencies = ["usd", "eur", "gbp", "jpy", "cad", "aud"]
    private let refreshOptions: [(label: String, seconds: TimeInterval)] = [
        ("30 seconds", 30),
        ("60 seconds", 60),
        ("2 minutes", 120)
    ]

    private var displayedCoins: [Coin] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if query.count >= 2 {
            return viewModel.catalog
                .filter {
                    $0.name.lowercased().contains(query)
                        || $0.symbol.lowercased().contains(query)
                        || $0.id.lowercased().contains(query)
                }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .prefix(50)
                .map { $0 }
        }

        let selected = viewModel.selectedCoinIDs.compactMap { id in
            viewModel.catalog.first { $0.id == id }
                ?? Coin.defaults.first { $0.id == id }
        }

        if selected.isEmpty {
            return Coin.defaults
        }
        return selected
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.title2.bold())
                    .foregroundStyle(CryptoBarColors.primaryText)

                GroupBox("Tracked coins") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Search to add coins…", text: $searchText)
                            .textFieldStyle(.roundedBorder)

                        Text("Your tracked coins are listed below. Type at least 2 characters to search and add more.")
                            .font(.caption)
                            .foregroundStyle(CryptoBarColors.secondaryText)

                        if CoinCatalog.shared.isLoading {
                            HStack {
                                ProgressView().controlSize(.small)
                                Text("Loading coin list…")
                                    .foregroundStyle(CryptoBarColors.secondaryText)
                            }
                        }

                        ForEach(displayedCoins) { coin in
                            Toggle(isOn: coinToggleBinding(for: coin)) {
                                VStack(alignment: .leading) {
                                    Text(coin.name)
                                        .foregroundStyle(CryptoBarColors.primaryText)
                                    Text(coin.displaySymbol)
                                        .font(.caption)
                                        .foregroundStyle(CryptoBarColors.secondaryText)
                                }
                            }
                        }
                    }
                }

                HStack {
                    GroupBox("Currency") {
                        Picker("Currency", selection: $viewModel.vsCurrency) {
                            ForEach(currencies, id: \.self) { code in
                                Text(code.uppercased()).tag(code)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .onChange(of: viewModel.vsCurrency) { _, _ in
                            viewModel.fetchPrices()
                        }
                    }

                    GroupBox("Refresh") {
                        Picker("Refresh", selection: $viewModel.refreshInterval) {
                            ForEach(refreshOptions, id: \.seconds) { option in
                                Text(option.label).tag(option.seconds)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                    }
                }

                GroupBox("Launch at Login") {
                    Toggle("Open CryptoBar when you log in", isOn: $viewModel.launchAtLogin)
                    if let error = viewModel.launchAtLoginError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                GroupBox("CoinGecko API key (optional)") {
                    VStack(alignment: .leading, spacing: 6) {
                        SecureField("Demo API key", text: $viewModel.apiKey)
                            .textFieldStyle(.roundedBorder)
                        Text("Free key from coingecko.com — improves rate limits. Not required.")
                            .font(.caption)
                            .foregroundStyle(CryptoBarColors.secondaryText)
                    }
                }

                HStack {
                    Spacer()
                    Button("Done") { onDone?() }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
        }
        .frame(width: 420, height: 520)
        .cryptoBarPanelStyle()
        .task {
            await CoinCatalog.shared.loadIfNeeded(apiKey: viewModel.apiKey)
            viewModel.syncLaunchAtLoginState()
        }
    }

    private func coinToggleBinding(for coin: Coin) -> Binding<Bool> {
        Binding(
            get: { viewModel.isCoinSelected(coin) },
            set: { isOn in
                if isOn {
                    if !viewModel.selectedCoinIDs.contains(coin.id) {
                        viewModel.selectedCoinIDs.append(coin.id)
                    }
                } else {
                    viewModel.selectedCoinIDs.removeAll { $0 == coin.id }
                }
                viewModel.fetchPrices()
            }
        )
    }
}
