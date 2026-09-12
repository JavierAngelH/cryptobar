import Charts
import SwiftUI

struct CoinChartView: View {
    let points: [PriceChartPoint]
    let currencyCode: String
    let isPositive: Bool

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Time", point.date),
                y: .value("Price", point.price)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(isPositive ? Color.green : Color.red)

            AreaMark(
                x: .value("Time", point.date),
                y: .value("Price", point.price)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                (isPositive ? Color.green : Color.red).opacity(0.15)
            )
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                if let price = value.as(Double.self) {
                    AxisValueLabel {
                        Text(PriceFormatter.compactAxis(price, currencyCode: currencyCode))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYScale(domain: yDomain)
    }

    private var yDomain: ClosedRange<Double> {
        let prices = points.map(\.price)
        guard let min = prices.min(), let max = prices.max(), min < max else {
            return 0 ... 1
        }
        let padding = (max - min) * 0.08
        return (min - padding) ... (max + padding)
    }
}
