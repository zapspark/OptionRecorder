import Foundation

public struct OptionLedger {
    private let wheelLedger = WheelLedger()

    public init() {}

    public func makePosition(
        ticker: String,
        strategy: OptionStrategy = .wheel,
        contractQuantity: Int = WheelLedger.contractMultiplier
    ) throws -> Position {
        switch strategy {
        case .wheel:
            return try wheelLedger.makePosition(
                ticker: ticker,
                strategy: strategy,
                contractQuantity: contractQuantity
            )
        }
    }

    @discardableResult
    public func addTrade(
        to position: Position,
        type: OptionTradeType,
        strike: Double,
        premium: Double,
        expiryDate: Date
    ) throws -> OptionTrade {
        switch position.strategy {
        case .wheel:
            return try wheelLedger.addTrade(
                to: position,
                type: type,
                strike: strike,
                premium: premium,
                expiryDate: expiryDate
            )
        }
    }

    public func markStatus(_ status: OptionTradeStatus, for trade: OptionTrade, in position: Position) {
        switch position.strategy {
        case .wheel:
            wheelLedger.markStatus(status, for: trade, in: position)
        }
    }

    public func removeTrade(_ trade: OptionTrade, from position: Position) {
        if trade.type == .put, trade.status == .assigned {
            markStatus(.open, for: trade, in: position)
        }

        position.cumulativePremium -= wheelLedger.premiumImpact(for: trade, in: position)
    }
}
