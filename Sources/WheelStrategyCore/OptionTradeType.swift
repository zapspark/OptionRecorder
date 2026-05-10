import Foundation

public enum OptionTradeType: String, Codable, CaseIterable, Identifiable {
    case put = "Put"
    case call = "Call"
    case activeClose = "Active Close"

    public var id: String { rawValue }

    public var defaultStatus: OptionTradeStatus {
        switch self {
        case .put, .call:
            .open
        case .activeClose:
            .closed
        }
    }

    public var premiumCashFlowMultiplier: Double {
        switch self {
        case .put, .call:
            1
        case .activeClose:
            -1
        }
    }
}
