import Foundation
import SwiftData

@Model
public final class Position {
    public var ticker: String
    public var strategyRawValue: String?
    public var shares: Int
    public var grossShareCost: Double
    public var totalPremiumCollected: Double
    public var contractQuantity: Int = 100

    @Relationship(deleteRule: .cascade, inverse: \OptionTrade.position)
    public var trades: [OptionTrade]

    public var adjustedCostBasis: Double {
        guard shares > 0 else { return 0 }
        return (grossShareCost - totalPremiumCollected) / Double(shares)
    }

    public var strategy: OptionStrategy {
        get { strategyRawValue.flatMap(OptionStrategy.init(rawValue:)) ?? .wheel }
        set { strategyRawValue = newValue.rawValue }
    }

    public init(
        ticker: String,
        strategy: OptionStrategy = .wheel,
        contractQuantity: Int = 100,
        shares: Int = 0,
        grossShareCost: Double = 0,
        totalPremiumCollected: Double = 0,
        trades: [OptionTrade] = []
    ) {
        self.ticker = ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.strategyRawValue = strategy.rawValue
        self.contractQuantity = contractQuantity
        self.shares = shares
        self.grossShareCost = grossShareCost
        self.totalPremiumCollected = totalPremiumCollected
        self.trades = trades
    }
}
