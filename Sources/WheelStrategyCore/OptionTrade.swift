import Foundation
import SwiftData

@Model
public final class OptionTrade {
    public var typeRawValue: String
    public var strike: Double
    public var premium: Double
    public var expiryDate: Date
    public var statusRawValue: String
    public var openedAt: Date
    public var position: Position?

    public var type: OptionTradeType {
        get { OptionTradeType(rawValue: typeRawValue) ?? .put }
        set { typeRawValue = newValue.rawValue }
    }

    public var status: OptionTradeStatus {
        get { OptionTradeStatus(rawValue: statusRawValue) ?? .open }
        set { statusRawValue = newValue.rawValue }
    }

    public init(
        type: OptionTradeType,
        strike: Double,
        premium: Double,
        expiryDate: Date,
        status: OptionTradeStatus = .open,
        openedAt: Date = .now,
        position: Position? = nil
    ) {
        self.typeRawValue = type.rawValue
        self.strike = strike
        self.premium = premium
        self.expiryDate = expiryDate
        self.statusRawValue = status.rawValue
        self.openedAt = openedAt
        self.position = position
    }
}
