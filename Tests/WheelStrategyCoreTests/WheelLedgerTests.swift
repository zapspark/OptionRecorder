import Testing
import Foundation
@testable import WheelStrategyCore

@Suite("WheelLedger")
struct WheelLedgerTests {
    @Test("Put assigned adds 100 shares and deducts premium from adjusted cost basis")
    func putAssignmentUpdatesAdjustedCostBasis() throws {
        let ledger = WheelLedger()
        let position = try ledger.makePosition(ticker: "aapl")
        let trade = try ledger.addTrade(
            to: position,
            type: .put,
            strike: 180,
            premium: 2.50,
            expiryDate: Date(timeIntervalSince1970: 1_800_000_000)
        )

        ledger.markStatus(.assigned, for: trade, in: position)

        #expect(position.ticker == "AAPL")
        #expect(position.strategy == .wheel)
        #expect(position.shares == 100)
        #expect(position.grossShareCost == 18_000)
        #expect(position.cumulativePremium == 250)
        #expect(position.adjustedCostBasis == 177.50)
    }

    @Test("Marking the same Put assigned twice does not double count shares")
    func repeatedAssignmentIsIdempotent() throws {
        let ledger = WheelLedger()
        let position = try ledger.makePosition(ticker: "MSFT")
        let trade = try ledger.addTrade(
            to: position,
            type: .put,
            strike: 300,
            premium: 4,
            expiryDate: .now
        )

        ledger.markStatus(.assigned, for: trade, in: position)
        ledger.markStatus(.assigned, for: trade, in: position)

        #expect(position.shares == 100)
        #expect(position.adjustedCostBasis == 296)
    }

    @Test("Reverting assigned Put removes assignment stock cost but keeps collected premium")
    func revertingAssignmentKeepsPremiumHistory() throws {
        let ledger = WheelLedger()
        let position = try ledger.makePosition(ticker: "TSLA")
        let trade = try ledger.addTrade(
            to: position,
            type: .put,
            strike: 220,
            premium: 3,
            expiryDate: .now
        )

        ledger.markStatus(.assigned, for: trade, in: position)
        ledger.markStatus(.expired, for: trade, in: position)

        #expect(position.shares == 0)
        #expect(position.grossShareCost == 0)
        #expect(position.cumulativePremium == 300)
        #expect(position.adjustedCostBasis == 0)
    }

    @Test("Position contract quantity drives premium and assignment math")
    func customContractQuantityDrivesLedgerMath() throws {
        let ledger = WheelLedger()
        let position = try ledger.makePosition(ticker: "SPX", contractQuantity: 10)
        let trade = try ledger.addTrade(
            to: position,
            type: .put,
            strike: 50,
            premium: 2,
            expiryDate: .now
        )

        ledger.markStatus(.assigned, for: trade, in: position)

        #expect(position.contractQuantity == 10)
        #expect(position.shares == 10)
        #expect(position.grossShareCost == 500)
        #expect(position.cumulativePremium == 20)
        #expect(position.adjustedCostBasis == 48)
    }

    @Test("Active close is a closing operation and reduces net premium")
    func activeCloseReducesNetPremium() throws {
        let ledger = OptionLedger()
        let position = try ledger.makePosition(ticker: "AAPL")
        _ = try ledger.addTrade(
            to: position,
            type: .call,
            strike: 200,
            premium: 2,
            expiryDate: .now
        )
        let closeTrade = try ledger.addTrade(
            to: position,
            type: .activeClose,
            strike: 200,
            premium: 0.75,
            expiryDate: .now
        )

        #expect(closeTrade.status == .closed)
        #expect(position.cumulativePremium == 125)

        ledger.removeTrade(closeTrade, from: position)
        #expect(position.cumulativePremium == 200)
    }

    @Test("OptionLedger keeps UI code strategy agnostic while dispatching wheel rules")
    func optionLedgerDispatchesByStrategy() throws {
        let ledger = OptionLedger()
        let position = try ledger.makePosition(ticker: "nvda", strategy: .wheel)
        let trade = try ledger.addTrade(
            to: position,
            type: .put,
            strike: 900,
            premium: 10,
            expiryDate: .now
        )

        ledger.markStatus(.assigned, for: trade, in: position)

        #expect(position.ticker == "NVDA")
        #expect(position.strategy == .wheel)
        #expect(position.shares == 100)
        #expect(position.adjustedCostBasis == 890)
    }
}
