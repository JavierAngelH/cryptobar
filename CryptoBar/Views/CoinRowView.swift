import AppKit
import SwiftUI

struct CoinRowView: View {
    let quote: PriceQuote
    let currencyCode: String
    let apiKey: String
    let isExpanded: Bool
    let onTap: () -> Void

    @State private var chartPoints: [PriceChartPoint] = []
    @State private var chartRange: ChartRange = .week
    @State private var isLoadingChart = false
    @State private var chartError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(quote.coin.name)
                            .font(.headline)
                            .foregroundStyle(CryptoBarColors.primaryText)
                        Text(quote.coin.displaySymbol)
                            .font(.caption)
                            .foregroundStyle(CryptoBarColors.secondaryText)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(PriceFormatter.format(quote.price, currencyCode: currencyCode))
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(CryptoBarColors.primaryText)

                        if let change = quote.formattedChange24h {
                            Text(change)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(quote.isPositiveChange ? .green : .red)
                        }
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(CryptoBarColors.secondaryText)
                }
            }
            .buttonStyle(.plain)
            .help("Show price chart")

            if isExpanded {
                expandedChartSection
            }
        }
        .padding(.vertical, 4)
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                loadChart()
            }
        }
        .onChange(of: chartRange) { _, _ in
            if isExpanded {
                loadChart()
            }
        }
    }

    @ViewBuilder
    private var expandedChartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Range", selection: $chartRange) {
                ForEach(ChartRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if isLoadingChart {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(height: 120)
            } else if let chartError {
                VStack(spacing: 8) {
                    Text(chartError)
                        .font(.caption)
                        .foregroundStyle(CryptoBarColors.secondaryText)
                        .multilineTextAlignment(.center)
                    Button("Open on CoinGecko") {
                        openCoinGecko()
                    }
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
            } else if chartPoints.isEmpty {
                VStack(spacing: 8) {
                    Text("No chart data available.")
                        .font(.caption)
                        .foregroundStyle(CryptoBarColors.secondaryText)
                    Button("Open on CoinGecko") {
                        openCoinGecko()
                    }
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
            } else {
                CoinChartView(
                    points: chartPoints,
                    currencyCode: currencyCode,
                    isPositive: chartIsPositive
                )
                .frame(height: 140)
            }

            Button {
                openCoinGecko()
            } label: {
                Label("View on CoinGecko", systemImage: "safari")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
        }
        .padding(.top, 4)
    }

    private var chartIsPositive: Bool {
        guard let first = chartPoints.first?.price, let last = chartPoints.last?.price else {
            return quote.isPositiveChange
        }
        return last >= first
    }

    private func loadChart() {
        isLoadingChart = true
        chartError = nil

        Task {
            let service = CoinGeckoService()
            do {
                let points = try await service.fetchMarketChart(
                    coinID: quote.coin.id,
                    vsCurrency: currencyCode,
                    days: chartRange.days,
                    apiKey: apiKey
                )
                chartPoints = points
                chartError = points.isEmpty ? "Could not load chart." : nil
            } catch {
                chartPoints = []
                chartError = error.localizedDescription
            }
            isLoadingChart = false
        }
    }

    private func openCoinGecko() {
        NSWorkspace.shared.open(quote.coin.coingeckoURL)
    }
}

struct CoinRowSkeleton: View {
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(CryptoBarColors.secondaryText.opacity(0.25))
                .frame(width: 100, height: 14)
            Spacer()
            RoundedRectangle(cornerRadius: 4)
                .fill(CryptoBarColors.secondaryText.opacity(0.25))
                .frame(width: 72, height: 14)
        }
        .padding(.vertical, 8)
    }
}
