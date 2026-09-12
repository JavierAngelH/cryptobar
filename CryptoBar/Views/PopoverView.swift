import SwiftUI

struct PopoverView: View {
    @Bindable var viewModel: PriceViewModel
    var onOpenSettings: () -> Void

    @State private var expandedCoinID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 320)
        .cryptoBarPanelStyle()
    }

    private var header: some View {
        HStack {
            Label("CryptoBar", systemImage: "bitcoinsign.circle.fill")
                .font(.headline)
                .foregroundStyle(CryptoBarColors.primaryText)
            Spacer()
            Button {
                onOpenSettings()
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(CryptoBarColors.primaryText)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.quotes.isEmpty {
            VStack(spacing: 0) {
                ForEach(0 ..< 3, id: \.self) { _ in
                    CoinRowSkeleton()
                        .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 8)
        } else if let error = viewModel.errorMessage, viewModel.quotes.isEmpty {
            VStack(spacing: 12) {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(CryptoBarColors.secondaryText)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    viewModel.fetchPrices()
                }
                .controlSize(.small)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        } else if viewModel.quotes.isEmpty {
            VStack(spacing: 12) {
                Text("No coins selected.")
                    .foregroundStyle(CryptoBarColors.secondaryText)
                Button("Open Settings") {
                    onOpenSettings()
                }
                .controlSize(.small)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.quotes) { quote in
                        CoinRowView(
                            quote: quote,
                            currencyCode: viewModel.vsCurrency,
                            apiKey: viewModel.apiKey,
                            isExpanded: expandedCoinID == quote.id,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedCoinID = expandedCoinID == quote.id ? nil : quote.id
                                }
                            }
                        )
                        .padding(.horizontal, 16)
                        if quote.id != viewModel.quotes.last?.id {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 420)
        }
    }

    private var footer: some View {
        HStack {
            if let lastFetch = viewModel.lastFetchDate {
                Text("Updated \(lastFetch.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(CryptoBarColors.secondaryText)
            } else {
                Text("Waiting for first update…")
                    .font(.caption2)
                    .foregroundStyle(CryptoBarColors.secondaryText)
            }

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button {
                    viewModel.refreshIfStale(force: true)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(CryptoBarColors.primaryText)
                }
                .buttonStyle(.plain)
                .help("Refresh now")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
