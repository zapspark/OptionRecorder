import Foundation

public struct MarketPriceQuote: Equatable {
    public let ticker: String
    public let price: Double
    public let currencyCode: String?
    public let source: String
    public let retrievedAt: Date

    public init(
        ticker: String,
        price: Double,
        currencyCode: String?,
        source: String,
        retrievedAt: Date = .now
    ) {
        self.ticker = ticker
        self.price = price
        self.currencyCode = currencyCode
        self.source = source
        self.retrievedAt = retrievedAt
    }
}

public enum TickerMarket: Equatable {
    case chinaA
    case global
}

public enum MarketPriceError: LocalizedError, Equatable {
    case emptyTicker
    case missingAPIKey(String)
    case missingAkShareEndpoint
    case noProvider(String)
    case invalidResponse(String)

    public var errorDescription: String? {
        switch self {
        case .emptyTicker:
            "Ticker cannot be empty."
        case .missingAPIKey(let provider):
            "\(provider) API key is missing."
        case .missingAkShareEndpoint:
            "AkShare price endpoint is missing."
        case .noProvider(let ticker):
            "No market price provider is configured for \(ticker)."
        case .invalidResponse(let provider):
            "\(provider) returned an invalid price response."
        }
    }
}

public protocol MarketPriceProvider {
    var sourceName: String { get }
    func supports(ticker: String) -> Bool
    func latestPrice(for ticker: String) async throws -> MarketPriceQuote
}

public struct TickerClassifier {
    public static func normalized(_ ticker: String) -> String {
        ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    public static func market(for ticker: String) -> TickerMarket {
        let normalizedTicker = normalized(ticker)
        let symbol = normalizedTicker.components(separatedBy: ".").first ?? normalizedTicker
        let suffix = normalizedTicker.components(separatedBy: ".").dropFirst().first
        let chinaASuffixes = ["SH", "SS", "SSE", "SZ", "SZSE"]

        if let suffix, chinaASuffixes.contains(suffix), isSixDigitSymbol(symbol) {
            return .chinaA
        }

        if isSixDigitSymbol(symbol),
           ["0", "2", "3", "4", "6", "8", "9"].contains(symbol.prefix(1)) {
            return .chinaA
        }

        return .global
    }

    public static func akShareSymbol(for ticker: String) -> String {
        let normalizedTicker = normalized(ticker)
        return normalizedTicker.components(separatedBy: ".").first ?? normalizedTicker
    }

    private static func isSixDigitSymbol(_ symbol: String) -> Bool {
        symbol.count == 6 && symbol.allSatisfy(\.isNumber)
    }
}

public struct MarketPriceService {
    private let providers: [any MarketPriceProvider]

    public init(providers: [any MarketPriceProvider] = MarketPriceProviderRegistry.defaultProviders()) {
        self.providers = providers
    }

    public func provider(for ticker: String) throws -> any MarketPriceProvider {
        let normalizedTicker = TickerClassifier.normalized(ticker)
        guard !normalizedTicker.isEmpty else { throw MarketPriceError.emptyTicker }

        guard let provider = providers.first(where: { $0.supports(ticker: normalizedTicker) }) else {
            throw MarketPriceError.noProvider(normalizedTicker)
        }

        return provider
    }

    public func latestPrice(for ticker: String) async throws -> MarketPriceQuote {
        try await provider(for: ticker).latestPrice(for: ticker)
    }
}

public struct MarketPriceProviderRegistry {
    public static func defaultProviders(environment: [String: String] = ProcessInfo.processInfo.environment) -> [any MarketPriceProvider] {
        var providers: [any MarketPriceProvider] = []

        if let akShareEndpoint = environment["AKSHARE_PRICE_ENDPOINT"],
           let endpointURL = URL(string: akShareEndpoint),
           !akShareEndpoint.isEmpty {
            providers.append(AkSharePriceProvider(endpointURL: endpointURL))
        }

        if let apiKey = environment["ALPHA_VANTAGE_API_KEY"], !apiKey.isEmpty {
            providers.append(AlphaVantagePriceProvider(apiKey: apiKey))
        }

        providers.append(YahooFinancePriceProvider())
        return providers
    }
}

public struct YahooFinancePriceProvider: MarketPriceProvider {
    public let sourceName = "Yahoo Finance"

    public init() {}

    public func supports(ticker: String) -> Bool {
        TickerClassifier.market(for: ticker) == .global
    }

    public func latestPrice(for ticker: String) async throws -> MarketPriceQuote {
        let normalizedTicker = TickerClassifier.normalized(ticker)
        guard !normalizedTicker.isEmpty else { throw MarketPriceError.emptyTicker }

        let encodedTicker = normalizedTicker.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? normalizedTicker
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encodedTicker)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(YahooChartResponse.self, from: data)

        guard let meta = response.chart.result?.first?.meta,
              let price = meta.regularMarketPrice else {
            throw MarketPriceError.invalidResponse(sourceName)
        }

        return MarketPriceQuote(
            ticker: meta.symbol ?? normalizedTicker,
            price: price,
            currencyCode: meta.currency,
            source: sourceName
        )
    }
}

public struct AlphaVantagePriceProvider: MarketPriceProvider {
    public let sourceName = "Alpha Vantage"
    private let apiKey: String

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    public func supports(ticker: String) -> Bool {
        TickerClassifier.market(for: ticker) == .global
    }

    public func latestPrice(for ticker: String) async throws -> MarketPriceQuote {
        let normalizedTicker = TickerClassifier.normalized(ticker)
        guard !normalizedTicker.isEmpty else { throw MarketPriceError.emptyTicker }
        guard !apiKey.isEmpty else { throw MarketPriceError.missingAPIKey(sourceName) }

        var components = URLComponents(string: "https://www.alphavantage.co/query")!
        components.queryItems = [
            URLQueryItem(name: "function", value: "GLOBAL_QUOTE"),
            URLQueryItem(name: "symbol", value: normalizedTicker),
            URLQueryItem(name: "apikey", value: apiKey)
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try JSONDecoder().decode(AlphaVantageQuoteResponse.self, from: data)

        guard let priceText = response.globalQuote.price,
              let price = Double(priceText) else {
            throw MarketPriceError.invalidResponse(sourceName)
        }

        return MarketPriceQuote(
            ticker: response.globalQuote.symbol ?? normalizedTicker,
            price: price,
            currencyCode: "USD",
            source: sourceName
        )
    }
}

public struct AkSharePriceProvider: MarketPriceProvider {
    public let sourceName = "AkShare"
    private let endpointURL: URL

    public init(endpointURL: URL) {
        self.endpointURL = endpointURL
    }

    public func supports(ticker: String) -> Bool {
        TickerClassifier.market(for: ticker) == .chinaA
    }

    public func latestPrice(for ticker: String) async throws -> MarketPriceQuote {
        let symbol = TickerClassifier.akShareSymbol(for: ticker)
        guard !symbol.isEmpty else { throw MarketPriceError.emptyTicker }

        var components = URLComponents(url: endpointURL, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []
        queryItems.append(URLQueryItem(name: "symbol", value: symbol))
        components?.queryItems = queryItems

        guard let url = components?.url else { throw MarketPriceError.missingAkShareEndpoint }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(AkShareQuoteResponse.self, from: data)

        guard let price = response.price ?? response.latestPrice else {
            throw MarketPriceError.invalidResponse(sourceName)
        }

        return MarketPriceQuote(
            ticker: response.symbol ?? symbol,
            price: price,
            currencyCode: response.currencyCode ?? "CNY",
            source: sourceName
        )
    }
}

private struct YahooChartResponse: Decodable {
    let chart: Chart

    struct Chart: Decodable {
        let result: [Result]?
    }

    struct Result: Decodable {
        let meta: Meta
    }

    struct Meta: Decodable {
        let symbol: String?
        let currency: String?
        let regularMarketPrice: Double?
    }
}

private struct AlphaVantageQuoteResponse: Decodable {
    let globalQuote: GlobalQuote

    enum CodingKeys: String, CodingKey {
        case globalQuote = "Global Quote"
    }

    struct GlobalQuote: Decodable {
        let symbol: String?
        let price: String?

        enum CodingKeys: String, CodingKey {
            case symbol = "01. symbol"
            case price = "05. price"
        }
    }
}

private struct AkShareQuoteResponse: Decodable {
    let symbol: String?
    let price: Double?
    let latestPrice: Double?
    let currencyCode: String?

    enum CodingKeys: String, CodingKey {
        case symbol
        case price
        case latestPrice = "latest_price"
        case currencyCode = "currency"
    }
}
