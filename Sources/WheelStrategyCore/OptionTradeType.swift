import Foundation

public enum OptionTradeType: String, Codable, CaseIterable, Identifiable {
    case cashSecuredPut = "Cash-Secured Put"
    case coveredCall = "Covered Call"
    case buyStock = "Buy Stock"
    case sellStock = "Sell Stock"
    case activeClose = "Active Close"

    public var id: String { rawValue }

    public var defaultStatus: OptionTradeStatus {
        switch self {
        case .cashSecuredPut, .coveredCall:
            .open
        case .buyStock, .sellStock, .activeClose:
            .closed
        }
    }

    public var premiumCashFlowMultiplier: Double {
        switch self {
        case .cashSecuredPut, .coveredCall:
            1
        case .activeClose:
            -1
        case .buyStock, .sellStock:
            0
        }
    }

    public var countsAsOpenTrade: Bool {
        switch self {
        case .cashSecuredPut, .coveredCall:
            true
        case .buyStock, .sellStock, .activeClose:
            false
        }
    }
}
