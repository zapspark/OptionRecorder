import Foundation

public enum OptionTradeStatus: String, Codable, CaseIterable, Identifiable {
    case open = "Open"
    case assigned = "Assigned"
    case expired = "Expired"
    case closed = "Closed"

    public var id: String { rawValue }
}
