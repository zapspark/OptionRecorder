import SwiftData
import SwiftUI
import WheelStrategyCore
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Position.ticker) private var positions: [Position]

    @State private var selectedPosition: Position?
    @State private var showingNewPosition = false
    @State private var positionPendingDeletion: Position?
    @State private var errorMessage: String?

    private var totalPremium: Double {
        positions.reduce(0) { $0 + $1.totalPremiumCollected }
    }

    private var totalShares: Int {
        positions.reduce(0) { $0 + $1.shares }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                sidebarSummary
                    .padding([.horizontal, .top], 12)
                    .padding(.bottom, 8)

                if positions.isEmpty {
                    ContentUnavailableView(
                        "No Positions",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Add a ticker and strategy to start tracking option trades.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $selectedPosition) {
                        ForEach(positions) { position in
                            PositionRow(
                                position: position,
                                onDelete: { requestDeletePosition(position) }
                            )
                                .tag(position)
                        }
                        .onDelete(perform: requestDeletePositions)
                    }
                    .listStyle(.sidebar)
                }
            }
            .navigationTitle("Positions")
            .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 380)
            .toolbar {
                Button {
                    showingNewPosition = true
                } label: {
                    Label("Add Position", systemImage: "plus")
                }
                .accessibilityIdentifier("add-position-toolbar-button")
                .keyboardShortcut("n", modifiers: [.command])
            }
            .sheet(isPresented: $showingNewPosition) {
                NewPositionSheet { ticker, strategy, contractQuantity in
                    addPosition(ticker: ticker, strategy: strategy, contractQuantity: contractQuantity)
                }
            }
        } detail: {
            if let selectedPosition {
                PositionDetailView(position: selectedPosition)
            } else {
                ContentUnavailableView(
                    "Select a Position",
                    systemImage: "sidebar.left",
                    description: Text("Choose a strategy book from the sidebar or add a new one.")
                )
            }
        }
        .alert("Unable to Save", isPresented: errorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .alert("Delete Book?", isPresented: deleteConfirmationPresented) {
            Button("Cancel", role: .cancel) {
                positionPendingDeletion = nil
            }
            Button("Delete Book", role: .destructive) {
                confirmDeletePosition()
            }
        } message: {
            Text(deleteConfirmationMessage)
        }
        .accessibilityIdentifier("option-recorder-root")
        .frame(minWidth: 1040, minHeight: 680)
    }

    private var sidebarSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Option Book")
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Button {
                    showingNewPosition = true
                } label: {
                    Label("Add Position", systemImage: "plus")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .help("Add Position")
                .accessibilityIdentifier("add-position-button")
            }

            LazyVGrid(columns: sidebarSummaryColumns, alignment: .leading, spacing: 8) {
                summaryItem("Books", value: "\(positions.count)")
                summaryItem("Shares", value: "\(totalShares)")
                summaryItem("Premium", value: totalPremium.formatted(.currency(code: currencyCode)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sidebarSummaryColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 64), spacing: 10, alignment: .leading)]
    }

    private func summaryItem(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(value)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func addPosition(ticker: String, strategy: OptionStrategy, contractQuantity: Int) -> Bool {
        do {
            let position = try OptionLedger().makePosition(
                ticker: ticker,
                strategy: strategy,
                contractQuantity: contractQuantity
            )
            if positions.contains(where: { $0.ticker == position.ticker && $0.strategy == position.strategy }) {
                selectedPosition = positions.first {
                    $0.ticker == position.ticker && $0.strategy == position.strategy
                }
                return true
            }

            modelContext.insert(position)
            selectedPosition = position
            try modelContext.save()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func requestDeletePositions(at offsets: IndexSet) {
        guard let firstIndex = offsets.first else { return }
        requestDeletePosition(positions[firstIndex])
    }

    private func requestDeletePosition(_ position: Position) {
        positionPendingDeletion = position
    }

    private func confirmDeletePosition() {
        guard let position = positionPendingDeletion else {
            return
        }
        positionPendingDeletion = nil
        deletePosition(position)
    }

    private var deleteConfirmationPresented: Binding<Bool> {
        Binding(
            get: { positionPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    positionPendingDeletion = nil
                }
            }
        )
    }

    private var deleteConfirmationMessage: String {
        guard let position = positionPendingDeletion else {
            return "This will delete the selected book and all of its trades."
        }
        return "This will delete \(position.ticker) \(position.strategy.rawValue) and all of its trades."
    }

    private func deletePosition(_ position: Position) {
        if selectedPosition == position {
            selectedPosition = nil
        }
        modelContext.delete(position)

        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }
}

private struct PositionRow: View {
    let position: Position
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(position.ticker)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityIdentifier("position-row-\(position.ticker)-\(position.strategy.rawValue)")

                Text(position.strategy.rawValue)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())

                Spacer(minLength: 8)

                Text("\(position.shares) sh")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Position", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Delete Position")
                .accessibilityIdentifier("delete-position-button-\(position.ticker)-\(position.strategy.rawValue)")
            }

            LazyVGrid(columns: positionStatColumns, alignment: .leading, spacing: 8) {
                positionStat("Price", value: "--")
                positionStat(
                    "Premium",
                    value: position.totalPremiumCollected.formatted(.currency(code: currencyCode))
                )
                positionStat(
                    "Cost Basis",
                    value: position.adjustedCostBasis.formatted(.currency(code: currencyCode))
                )
            }
        }
        .padding(.vertical, 6)
    }

    private var positionStatColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 74), spacing: 10, alignment: .leading)]
    }

    private func positionStat(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }
}

private struct PositionDetailView: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var position: Position
    @State private var tradeType: OptionTradeType = .cashSecuredPut
    @State private var strike = 0.0
    @State private var premium = 0.0
    @State private var expiryDate = Date()
    @State private var errorMessage: String?

    private var sortedTrades: [OptionTrade] {
        position.trades.sorted { lhs, rhs in
            if lhs.expiry == rhs.expiry {
                return lhs.date > rhs.date
            }
            return lhs.expiry > rhs.expiry
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                detailHeader
                metricGrid
                tradeForm
                timelineSection
            }
            .padding(24)
            .frame(maxWidth: 960, alignment: .leading)
        }
        .navigationTitle(position.ticker)
        .alert("Unable to Save", isPresented: errorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(position.ticker)
                .font(.largeTitle.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("\(position.strategy.rawValue) strategy ledger")
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var metricGrid: some View {
        LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 14) {
            MetricTile(
                title: "Shares",
                value: "\(position.shares)",
                icon: "number",
                identifier: "shares-metric"
            )
            MetricTile(
                title: "Strategy",
                value: position.strategy.rawValue,
                icon: "rectangle.3.group",
                identifier: "strategy-metric"
            )
            MetricTile(
                title: "Adjusted Cost",
                value: position.adjustedCostBasis.formatted(.currency(code: currencyCode)),
                icon: "target",
                identifier: "adjusted-cost-metric"
            )
            MetricTile(
                title: "Premium Collected",
                value: position.totalPremiumCollected.formatted(.currency(code: currencyCode)),
                icon: "banknote",
                identifier: "premium-metric"
            )
            MetricTile(
                title: "Open Trades",
                value: "\(position.trades.filter { $0.status == .open && $0.type.countsAsOpenTrade }.count)",
                icon: "clock",
                identifier: "open-trades-metric"
            )
            MetricTile(
                title: "Contract Qty",
                value: "\(position.contractQuantity)",
                icon: "number.circle",
                identifier: "contract-quantity-metric"
            )
        }
    }

    private var metricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 170), spacing: 16, alignment: .leading)]
    }

    private var tradeForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "New Trade", icon: "square.and.pencil")

            Picker("Type", selection: $tradeType) {
                ForEach(OptionTradeType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 620)
            .accessibilityIdentifier("trade-type-picker")

            tradeControls
        }
    }

    private var tradeControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                tradeNumberField(strikeFieldLabel, value: $strike, identifier: "trade-strike-field")
                tradeNumberField(premiumFieldLabel, value: $premium, identifier: "trade-premium-field")
                expiryField()
                addTradeFormButton
            }

            LazyVGrid(columns: narrowTradeControlColumns, alignment: .leading, spacing: 12) {
                tradeNumberField(strikeFieldLabel, value: $strike, identifier: "trade-strike-field")
                tradeNumberField(premiumFieldLabel, value: $premium, identifier: "trade-premium-field")
                expiryField()
                addTradeFormButton
            }
            .frame(maxWidth: 360, alignment: .leading)
        }
    }

    private var narrowTradeControlColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 168), spacing: 12, alignment: .leading)]
    }

    private func tradeNumberField(
        _ label: String,
        value: Binding<Double>,
        identifier: String,
        width: CGFloat? = nil
    ) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            TextField(label, value: value, format: .number.precision(.fractionLength(2)))
                .textFieldStyle(.roundedBorder)
                .frame(width: width ?? 96)
                .accessibilityIdentifier(identifier)
        }
    }

    private func expiryField(width: CGFloat? = nil) -> some View {
        HStack(spacing: 8) {
            Text("Expiry")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            DatePicker("Expiry", selection: $expiryDate, displayedComponents: .date)
                .labelsHidden()
                .frame(width: width ?? 150)
                .accessibilityIdentifier("trade-expiry-picker")
        }
    }

    private var addTradeFormButton: some View {
        Button {
            addTrade()
        } label: {
            Label("Add", systemImage: "plus")
        }
        .buttonStyle(.bordered)
        .disabled(!canAddTrade)
        .accessibilityIdentifier("add-trade-form-button")
    }

    private var strikeFieldLabel: String {
        switch tradeType {
        case .buyStock, .sellStock:
            return "Price"
        case .cashSecuredPut, .coveredCall, .activeClose:
            return "Strike"
        }
    }

    private var premiumFieldLabel: String {
        switch tradeType {
        case .activeClose:
            return "Close Premium"
        case .buyStock, .sellStock:
            return "Premium"
        case .cashSecuredPut, .coveredCall:
            return "Premium"
        }
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Trade Timeline", icon: "list.bullet.rectangle")

            if sortedTrades.isEmpty {
                ContentUnavailableView(
                    "No Trades",
                    systemImage: "tray",
                    description: Text("Enter strike, premium, and expiry to add the first option trade.")
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sortedTrades.enumerated()), id: \.offset) { index, trade in
                        TradeRow(
                            position: position,
                            trade: trade,
                            onStatusChange: updateStatus,
                            onDelete: deleteTrade
                        )

                        if index < sortedTrades.count - 1 {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
                .background(.background, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.quaternary)
                }
            }
        }
    }

    private var canAddTrade: Bool {
        strike > 0 && premium >= 0
    }

    private func addTrade() {
        do {
            _ = try OptionLedger().addTrade(
                to: position,
                type: tradeType,
                strike: strike,
                premium: premium,
                expiry: expiryDate
            )
            strike = 0
            premium = 0
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateStatus(_ trade: OptionTrade, to newStatus: OptionTradeStatus) {
        OptionLedger().markStatus(newStatus, for: trade, in: position)

        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteTrade(_ trade: OptionTrade) {
        OptionLedger().removeTrade(trade, from: position)
        modelContext.delete(trade)

        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let icon: String
    let identifier: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityIdentifier("\(identifier)-value")
            }
        }
        .padding(14)
        .frame(minWidth: 160, maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}

private struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.headline)
    }
}

private struct TradeRow: View {
    let position: Position
    let trade: OptionTrade
    let onStatusChange: (OptionTrade, OptionTradeStatus) -> Void
    let onDelete: (OptionTrade) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                tradeIcon
                tradeSummary
            }

            HStack {
                Spacer(minLength: 42)
                tradeActions
            }
        }
        .padding(12)
    }

    private var tradeIcon: some View {
        Image(systemName: typeIcon)
            .font(.title2)
            .foregroundStyle(typeTint)
            .frame(width: 30)
    }

    private var tradeSummary: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(trade.type.rawValue)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(trade.status.rawValue)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusTint.opacity(0.14), in: Capsule())
                    .foregroundStyle(statusTint)
            }

            LazyVGrid(columns: tradeDetailColumns, alignment: .leading, spacing: 8) {
                Label(trade.strike.formatted(.currency(code: currencyCode)), systemImage: "target")
                Label(trade.premium.formatted(.currency(code: currencyCode)), systemImage: "banknote")
                Label(trade.expiry.formatted(.dateTime.month().day().year()), systemImage: "calendar")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var tradeActions: some View {
        HStack(spacing: 8) {
            statusControl
            deleteButton
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            onDelete(trade)
        } label: {
            Label("Delete", systemImage: "trash")
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.borderless)
        .help("Delete trade")
        .accessibilityIdentifier("delete-trade-button")
    }

    private var tradeDetailColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 104), spacing: 10, alignment: .leading)]
    }

    @ViewBuilder
    private var statusControl: some View {
        if trade.type == .cashSecuredPut, trade.status == .open {
            HStack(spacing: 8) {
                quickStatusButton("Expired", systemImage: "checkmark.circle", status: .expired)
                    .accessibilityIdentifier("trade-expired-button")
                quickStatusButton("Assigned", systemImage: "arrow.down.to.line", status: .assigned)
                    .accessibilityIdentifier("trade-assigned-button")
                quickStatusButton("Rolled", systemImage: "arrow.triangle.2.circlepath", status: .rolled)
                    .accessibilityIdentifier("trade-rolled-button")
            }
        } else {
            Picker("Status", selection: Binding(
                get: { trade.status },
                set: { onStatusChange(trade, $0) }
            )) {
                ForEach(OptionTradeStatus.allCases) { status in
                    Text(status.rawValue).tag(status)
                }
            }
            .labelsHidden()
            .frame(width: 132)
            .accessibilityIdentifier("trade-status-picker")
        }
    }

    private func quickStatusButton(
        _ title: String,
        systemImage: String,
        status: OptionTradeStatus
    ) -> some View {
        Button {
            onStatusChange(trade, status)
        } label: {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var statusTint: Color {
        switch trade.status {
        case .open:
            .blue
        case .assigned:
            .orange
        case .expired:
            .green
        case .closed:
            .secondary
        case .rolled:
            .purple
        }
    }

    private var typeIcon: String {
        switch trade.type {
        case .cashSecuredPut:
            "arrow.down.left.circle.fill"
        case .coveredCall:
            "arrow.up.right.circle.fill"
        case .buyStock:
            "plus.circle.fill"
        case .sellStock:
            "minus.circle.fill"
        case .activeClose:
            "xmark.circle.fill"
        }
    }

    private var typeTint: Color {
        switch trade.type {
        case .cashSecuredPut:
            .purple
        case .coveredCall:
            .teal
        case .buyStock:
            .green
        case .sellStock:
            .orange
        case .activeClose:
            .red
        }
    }

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }
}

private struct NewPositionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var ticker = ""
    @State private var contractQuantityText = String(WheelLedger.contractMultiplier)
    @State private var strategy: OptionStrategy = .wheel

    let onAdd: (String, OptionStrategy, Int) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                Text("New Position")
                    .font(.title2.weight(.semibold))
            }

            AppKitTextField(placeholder: "Ticker", text: $ticker, onSubmit: add)
                .frame(height: 28)
                .accessibilityIdentifier("new-position-ticker-field")

            Picker("Strategy", selection: $strategy) {
                ForEach(OptionStrategy.allCases) { strategy in
                    Text(strategy.rawValue).tag(strategy)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("new-position-strategy-picker")

            AppKitTextField(
                placeholder: "Contract quantity",
                text: $contractQuantityText,
                onSubmit: add
            )
                .frame(height: 28)
                .accessibilityIdentifier("new-position-contract-quantity-field")

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Add") {
                    add()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canAdd)
                .accessibilityIdentifier("new-position-submit-button")
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private func add() {
        guard canAdd, let contractQuantity else { return }
        if onAdd(normalizedTicker, strategy, contractQuantity) {
            dismiss()
        }
    }

    private var normalizedTicker: String {
        ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private var contractQuantity: Int? {
        Int(contractQuantityText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var canAdd: Bool {
        guard !normalizedTicker.isEmpty, let contractQuantity else { return false }
        return contractQuantity > 0
    }
}

#if os(macOS)
private struct AppKitTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let onSubmit: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.delegate = context.coordinator
        textField.isEditable = true
        textField.isSelectable = true
        textField.focusRingType = .default
        textField.lineBreakMode = .byTruncatingTail
        textField.bezelStyle = .roundedBezel
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }

        context.coordinator.parent = self

        DispatchQueue.main.async {
            if nsView.window?.firstResponder == nil {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: AppKitTextField

        init(parent: AppKitTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }

            return false
        }
    }
}
#endif
