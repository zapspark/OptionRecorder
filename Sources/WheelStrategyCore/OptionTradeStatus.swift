import Foundation

public enum OptionTradeStatus: String, Codable, CaseIterable, Identifiable {
    case open = "Open"
    case assigned = "Assigned"
    case expired = "Expired"
    case closed = "Closed"
    case rolled = "Rolled"

    public var id: String { rawValue }
}
