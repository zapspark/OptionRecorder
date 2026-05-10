import Foundation

public enum WheelLedgerError: LocalizedError, Equatable {
    case emptyTicker
    case invalidContractQuantity
    case invalidStrike
    case invalidPremium

    public var errorDescription: String? {
        switch self {
        case .emptyTicker:
            "Ticker cannot be empty."
        case .invalidContractQuantity:
            "Contract quantity must be greater than zero."
        case .invalidStrike:
            "Strike must be greater than zero."
        case .invalidPremium:
            "Premium cannot be negative."
        }
    }
}

public struct WheelLedger {
    public static let contractMultiplier = 100

    public init() {}

    public func makePosition(
        ticker: String,
        strategy: OptionStrategy = .wheel,
        contractQuantity: Int = Self.contractMultiplier
    ) throws -> Position {
        let normalizedTicker = ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalizedTicker.isEmpty else { throw WheelLedgerError.emptyTicker }
        guard contractQuantity > 0 else { throw WheelLedgerError.invalidContractQuantity }
        return Position(ticker: normalizedTicker, strategy: strategy, contractQuantity: contractQuantity)
    }

    @discardableResult
    public func addTrade(
        to position: Position,
        type: OptionTradeType,
        strike: Double,
        premium: Double,
        expiryDate: Date
    ) throws -> OptionTrade {
        guard strike > 0 else { throw WheelLedgerError.invalidStrike }
        guard premium >= 0 else { throw WheelLedgerError.invalidPremium }

        let trade = OptionTrade(
            type: type,
            strike: strike,
            premium: premium,
            expiryDate: expiryDate,
            status: type.defaultStatus,
            position: position
        )
        position.trades.append(trade)
        position.cumulativePremium += premiumImpact(for: trade, in: position)
        return trade
    }

    public func markStatus(_ status: OptionTradeStatus, for trade: OptionTrade, in position: Position) {
        let oldStatus = trade.status
        guard oldStatus != status else { return }

        if trade.type == .put, oldStatus == .assigned {
            reversePutAssignment(for: trade, in: position)
        }

        trade.status = status

        if trade.type == .put, status == .assigned {
            applyPutAssignment(for: trade, in: position)
        }
    }

    private func applyPutAssignment(for trade: OptionTrade, in position: Position) {
        position.shares += position.contractQuantity
        position.grossShareCost += trade.strike * Double(position.contractQuantity)
    }

    private func reversePutAssignment(for trade: OptionTrade, in position: Position) {
        position.shares = max(0, position.shares - position.contractQuantity)
        position.grossShareCost = max(0, position.grossShareCost - trade.strike * Double(position.contractQuantity))
    }

    public func premiumImpact(for trade: OptionTrade, in position: Position) -> Double {
        trade.type.premiumCashFlowMultiplier * trade.premium * Double(position.contractQuantity)
    }
}
