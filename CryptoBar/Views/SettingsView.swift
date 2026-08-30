import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: PriceViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var catalogError: String?

    private let currencies = ["usd", "eur", "gbp", "jpy", "cad", "aud"]
    private let refreshOptions: [(label: String, seconds: TimeInterval)] = [
        ("30 seconds", 30),
        ("60 seconds", 60),
        ("2 minutes", 120)
    ]

    private var filteredCoins: [Coin] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return viewModel.catalog.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        return viewModel.catalog.filter {
            $0.name.lowercased().contains(query)
                || $0.symbol.lowercased().contains(query)
                || $0.id.lowercased().contains(query)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.title2.bold())

            GroupBox("Tracked coins") {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Search coins", text: $searchText)
                        .textFieldStyle(.roundedBorder)

                    if CoinCatalog.shared.isLoading {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("Loading coin list…")
                                .foregroundStyle(.secondary)
                        }
                    }

                    List(filteredCoins.prefix(200), id: \.id) { coin in
                        Toggle(isOn: Binding(
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
                        )) {
                            VStack(alignment: .leading) {
                                Text(coin.name)
                                Text(coin.displaySymbol)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(height: 180)

                    if let catalogError {
                        Text(catalogError)
                            .font(.caption)
                            .foregroundStyle(.red)
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
                    .onChange(of: viewModel.vsCurrency) { _ in
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
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420, height: 560)
        .task {
            await CoinCatalog.shared.loadIfNeeded(apiKey: viewModel.apiKey)
            viewModel.syncLaunchAtLoginState()
        }
    }
}
