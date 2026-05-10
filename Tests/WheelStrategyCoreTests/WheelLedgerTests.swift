import Testing
import Foundation
@testable import WheelStrategyCore

@Suite("WheelLedger")
struct WheelLedgerTests {
    @Test("Cash-secured put assigned adds 100 shares and deducts premium from adjusted cost basis")
    func putAssignmentUpdatesAdjustedCostBasis() throws {
        let ledger = WheelLedger()
        let expiry = Date(timeIntervalSince1970: 1_800_000_000)
        let position = try ledger.makePosition(ticker: "aapl")
        let trade = try ledger.addTrade(
            to: position,
            type: .cashSecuredPut,
            strike: 180,
            premium: 2.50,
            expiry: expiry
        )

        ledger.markStatus(.assigned, for: trade, in: position)

        #expect(trade.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        #expect(trade.ticker == "AAPL")
        #expect(trade.expiry == expiry)
        #expect(position.ticker == "AAPL")
        #expect(position.strategy == .wheel)
        #expect(position.shares == 100)
        #expect(position.grossShareCost == 18_000)
        #expect(position.totalPremiumCollected == 250)
        #expect(position.adjustedCostBasis == 177.50)
    }

    @Test("Marking the same cash-secured put assigned twice does not double count shares")
    func repeatedAssignmentIsIdempotent() throws {
        let ledger = WheelLedger()
        let position = try ledger.makePosition(ticker: "MSFT")
        let trade = try ledger.addTrade(
            to: position,
            type: .cashSecuredPut,
            strike: 300,
            premium: 4,
            expiry: .now
        )

        ledger.markStatus(.assigned, for: trade, in: position)
        ledger.markStatus(.assigned, for: trade, in: position)

        #expect(position.shares == 100)
        #expect(position.adjustedCostBasis == 296)
    }

    @Test("Reverting assigned cash-secured put removes assignment stock cost but keeps collected premium")
    func revertingAssignmentKeepsPremiumHistory() throws {
        let ledger = WheelLedger()
        let position = try ledger.makePosition(ticker: "TSLA")
        let trade = try ledger.addTrade(
            to: position,
            type: .cashSecuredPut,
            strike: 220,
            premium: 3,
            expiry: .now
        )

        ledger.markStatus(.assigned, for: trade, in: position)
        ledger.markStatus(.expired, for: trade, in: position)

        #expect(position.shares == 0)
        #expect(position.grossShareCost == 0)
        #expect(position.totalPremiumCollected == 300)
        #expect(position.adjustedCostBasis == 0)
    }

    @Test("Position contract quantity drives premium and assignment math")
    func customContractQuantityDrivesLedgerMath() throws {
        let ledger = WheelLedger()
        let position = try ledger.makePosition(ticker: "SPX", contractQuantity: 10)
        let trade = try ledger.addTrade(
            to: position,
            type: .cashSecuredPut,
            strike: 50,
            premium: 2,
            expiry: .now
        )

        ledger.markStatus(.assigned, for: trade, in: position)

        #expect(position.contractQuantity == 10)
        #expect(position.shares == 10)
        #expect(position.grossShareCost == 500)
        #expect(position.totalPremiumCollected == 20)
        #expect(position.adjustedCostBasis == 48)
    }

    @Test("Active close is a closing operation and reduces net premium")
    func activeCloseReducesNetPremium() throws {
        let ledger = OptionLedger()
        let position = try ledger.makePosition(ticker: "AAPL")
        _ = try ledger.addTrade(
            to: position,
            type: .coveredCall,
            strike: 200,
            premium: 2,
            expiry: .now
        )
        let closeTrade = try ledger.addTrade(
            to: position,
            type: .activeClose,
            strike: 200,
            premium: 0.75,
            expiry: .now
        )

        #expect(closeTrade.status == .closed)
        #expect(position.totalPremiumCollected == 125)

        ledger.removeTrade(closeTrade, from: position)
        #expect(position.totalPremiumCollected == 200)
    }

    @Test("OptionLedger keeps UI code strategy agnostic while dispatching wheel rules")
    func optionLedgerDispatchesByStrategy() throws {
        let ledger = OptionLedger()
        let position = try ledger.makePosition(ticker: "nvda", strategy: .wheel)
        let trade = try ledger.addTrade(
            to: position,
            type: .cashSecuredPut,
            strike: 900,
            premium: 10,
            expiry: .now
        )

        ledger.markStatus(.assigned, for: trade, in: position)

        #expect(position.ticker == "NVDA")
        #expect(position.strategy == .wheel)
        #expect(position.shares == 100)
        #expect(position.adjustedCostBasis == 890)
    }

    @Test("Stock buy and sell operations update shares and stock cost immediately")
    func stockTradesUpdateSharesAndCost() throws {
        let ledger = OptionLedger()
        let position = try ledger.makePosition(ticker: "AAPL")
        let buy = try ledger.addTrade(
            to: position,
            type: .buyStock,
            strike: 180,
            premium: 0,
            expiry: .now
        )

        #expect(buy.status == .closed)
        #expect(position.shares == 100)
        #expect(position.grossShareCost == 18_000)
        #expect(position.adjustedCostBasis == 180)

        let sell = try ledger.addTrade(
            to: position,
            type: .sellStock,
            strike: 180,
            premium: 0,
            expiry: .now
        )

        #expect(sell.status == .closed)
        #expect(position.shares == 0)
        #expect(position.grossShareCost == 0)
    }

    @Test("Covered call assignment can remove shares and rolled status is available")
    func coveredCallAssignmentAndRolledStatus() throws {
        let ledger = OptionLedger()
        let position = try ledger.makePosition(ticker: "AAPL")
        _ = try ledger.addTrade(
            to: position,
            type: .buyStock,
            strike: 180,
            premium: 0,
            expiry: .now
        )
        let call = try ledger.addTrade(
            to: position,
            type: .coveredCall,
            strike: 180,
            premium: 2,
            expiry: .now
        )

        ledger.markStatus(.assigned, for: call, in: position)

        #expect(position.shares == 0)
        #expect(position.grossShareCost == 0)
        #expect(position.totalPremiumCollected == 200)

        ledger.markStatus(.rolled, for: call, in: position)

        #expect(call.status == .rolled)
        #expect(position.shares == 100)
        #expect(position.grossShareCost == 18_000)
    }
}
