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
        expiry: Date
    ) throws -> OptionTrade {
        guard strike > 0 else { throw WheelLedgerError.invalidStrike }
        guard premium >= 0 else { throw WheelLedgerError.invalidPremium }

        let trade = OptionTrade(
            type: type,
            strike: strike,
            premium: premium,
            expiry: expiry,
            status: type.defaultStatus,
            position: position
        )
        position.trades.append(trade)
        position.totalPremiumCollected += premiumImpact(for: trade, in: position)
        applyImmediateStockImpact(for: trade, in: position)
        return trade
    }

    public func markStatus(_ status: OptionTradeStatus, for trade: OptionTrade, in position: Position) {
        let oldStatus = trade.status
        guard oldStatus != status else { return }

        if oldStatus == .assigned {
            reverseAssignment(for: trade, in: position)
        }

        trade.status = status

        if status == .assigned {
            applyAssignment(for: trade, in: position)
        }
    }

    public func reverseTradeEffects(_ trade: OptionTrade, from position: Position) {
        if trade.status == .assigned {
            reverseAssignment(for: trade, in: position)
        }

        reverseImmediateStockImpact(for: trade, in: position)
        position.totalPremiumCollected -= premiumImpact(for: trade, in: position)
    }

    private func applyAssignment(for trade: OptionTrade, in position: Position) {
        switch trade.type {
        case .cashSecuredPut:
            applySharePurchase(price: trade.strike, in: position)
        case .coveredCall:
            applyShareSale(price: trade.strike, in: position)
        case .buyStock, .sellStock, .activeClose:
            break
        }
    }

    private func reverseAssignment(for trade: OptionTrade, in position: Position) {
        switch trade.type {
        case .cashSecuredPut:
            reverseSharePurchase(price: trade.strike, in: position)
        case .coveredCall:
            reverseShareSale(price: trade.strike, in: position)
        case .buyStock, .sellStock, .activeClose:
            break
        }
    }

    private func applyImmediateStockImpact(for trade: OptionTrade, in position: Position) {
        switch trade.type {
        case .buyStock:
            applySharePurchase(price: trade.strike, in: position)
        case .sellStock:
            applyShareSale(price: trade.strike, in: position)
        case .cashSecuredPut, .coveredCall, .activeClose:
            break
        }
    }

    private func reverseImmediateStockImpact(for trade: OptionTrade, in position: Position) {
        switch trade.type {
        case .buyStock:
            reverseSharePurchase(price: trade.strike, in: position)
        case .sellStock:
            reverseShareSale(price: trade.strike, in: position)
        case .cashSecuredPut, .coveredCall, .activeClose:
            break
        }
    }

    private func applySharePurchase(price: Double, in position: Position) {
        position.shares += position.contractQuantity
        position.grossShareCost += price * Double(position.contractQuantity)
    }

    private func reverseSharePurchase(price: Double, in position: Position) {
        position.shares = max(0, position.shares - position.contractQuantity)
        position.grossShareCost = max(0, position.grossShareCost - price * Double(position.contractQuantity))
    }

    private func applyShareSale(price: Double, in position: Position) {
        position.shares = max(0, position.shares - position.contractQuantity)
        position.grossShareCost = max(0, position.grossShareCost - price * Double(position.contractQuantity))
    }

    private func reverseShareSale(price: Double, in position: Position) {
        position.shares += position.contractQuantity
        position.grossShareCost += price * Double(position.contractQuantity)
    }

    public func premiumImpact(for trade: OptionTrade, in position: Position) -> Double {
        trade.type.premiumCashFlowMultiplier * trade.premium * Double(position.contractQuantity)
    }
}
