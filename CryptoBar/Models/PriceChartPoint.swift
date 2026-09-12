import Foundation

struct PriceChartPoint: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let price: Double
}

enum ChartRange: String, CaseIterable, Identifiable {
    case day = "1D"
    case week = "7D"
    case month = "30D"

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .day: 1
        case .week: 7
        case .month: 30
        }
    }
}
