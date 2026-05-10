import Foundation
import SwiftData

@Model
public final class OptionTrade {
    public var id: UUID
    public var typeRawValue: String
    public var strike: Double
    public var premium: Double
    public var expiry: Date
    public var statusRawValue: String
    public var date: Date
    public var position: Position?

    public var ticker: String {
        position?.ticker ?? ""
    }

    public var type: OptionTradeType {
        get { OptionTradeType(rawValue: typeRawValue) ?? .cashSecuredPut }
        set { typeRawValue = newValue.rawValue }
    }

    public var status: OptionTradeStatus {
        get { OptionTradeStatus(rawValue: statusRawValue) ?? .open }
        set { statusRawValue = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        type: OptionTradeType,
        strike: Double,
        premium: Double,
        expiry: Date,
        status: OptionTradeStatus = .open,
        date: Date = .now,
        position: Position? = nil
    ) {
        self.id = id
        self.typeRawValue = type.rawValue
        self.strike = strike
        self.premium = premium
        self.expiry = expiry
        self.statusRawValue = status.rawValue
        self.date = date
        self.position = position
    }
}
