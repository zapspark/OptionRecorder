import Foundation
import Testing
@testable import WheelStrategyCore

@Suite("MarketPriceProvider")
struct MarketPriceProviderTests {
    @Test("Ticker classifier recognizes China A symbols")
    func tickerClassifierRecognizesChinaA() {
        #expect(TickerClassifier.market(for: "600519.SH") == .chinaA)
        #expect(TickerClassifier.market(for: "000001") == .chinaA)
        #expect(TickerClassifier.market(for: "AAPL") == .global)
    }

    @Test("Market price service routes China A ticker to AkShare provider")
    func serviceRoutesChinaATickerToAkShare() async throws {
        let service = MarketPriceService(providers: [
            StubPriceProvider(sourceName: "AkShare", supportedMarket: .chinaA, price: 12.34),
            StubPriceProvider(sourceName: "Yahoo Finance", supportedMarket: .global, price: 56.78)
        ])

        let quote = try await service.latestPrice(for: "600519.SH")

        #expect(quote.source == "AkShare")
        #expect(quote.price == 12.34)
    }

    @Test("Market price service routes global ticker to global provider")
    func serviceRoutesGlobalTickerToGlobalProvider() async throws {
        let service = MarketPriceService(providers: [
            StubPriceProvider(sourceName: "AkShare", supportedMarket: .chinaA, price: 12.34),
            StubPriceProvider(sourceName: "Yahoo Finance", supportedMarket: .global, price: 56.78)
        ])

        let quote = try await service.latestPrice(for: "AAPL")

        #expect(quote.source == "Yahoo Finance")
        #expect(quote.price == 56.78)
    }

    @Test("Market price service reports missing provider")
    func serviceReportsMissingProvider() async throws {
        let service = MarketPriceService(providers: [
            StubPriceProvider(sourceName: "Yahoo Finance", supportedMarket: .global, price: 56.78)
        ])

        await #expect(throws: MarketPriceError.noProvider("600519.SH")) {
            _ = try await service.latestPrice(for: "600519.SH")
        }
    }
}

private struct StubPriceProvider: MarketPriceProvider {
    let sourceName: String
    let supportedMarket: TickerMarket
    let price: Double

    func supports(ticker: String) -> Bool {
        TickerClassifier.market(for: ticker) == supportedMarket
    }

    func latestPrice(for ticker: String) async throws -> MarketPriceQuote {
        MarketPriceQuote(
            ticker: TickerClassifier.normalized(ticker),
            price: price,
            currencyCode: nil,
            source: sourceName
        )
    }
}
