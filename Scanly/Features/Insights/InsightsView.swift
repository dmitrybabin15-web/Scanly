import Charts
import CoreData
import SwiftUI

struct InsightsView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Expense.transactionDate, ascending: true)],
        animation: .default
    )
    private var expenses: FetchedResults<Expense>

    @State private var selectedCurrency: String = ""

    private var currencyCodes: [String] {
        Array(
            Set(
                expenses.map {
                    $0.currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                }.filter { !$0.isEmpty }
            )
        ).sorted()
    }

    private var activeCurrency: String {
        if currencyCodes.isEmpty { return "USD" }
        if selectedCurrency.isEmpty || !currencyCodes.contains(selectedCurrency) {
            return currencyCodes[0]
        }
        return selectedCurrency
    }

    var body: some View {
        Group {
            if expenses.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .navigationTitle("insights_nav_title")
        .onAppear(perform: syncCurrencySelection)
        .onChange(of: expenses.count) { _ in syncCurrencySelection() }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("insights_currency", selection: $selectedCurrency) {
                    ForEach(currencyCodes, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(currencyCodes.count <= 1)

                Text(
                    String(
                        format: String(localized: String.LocalizationValue("insights_charts_use_format")),
                        locale: .current,
                        activeCurrency
                    )
                )
                .font(.footnote)
                .foregroundStyle(.secondary)

                thisMonthSection

                monthlySection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private var thisMonthSection: some View {
        let cal = Calendar.current
        let interval = ExpenseSummary.monthInterval(containing: Date(), calendar: cal)
        let rows = ExpenseSummary.categoryTotals(
            expenses: Array(expenses),
            currencyFilter: activeCurrency,
            from: interval.start,
            to: interval.end
        )

        return VStack(alignment: .leading, spacing: 8) {
            Text("insights_this_month")
                .font(.headline)

            if rows.isEmpty {
                Text(
                    String(
                        format: String(localized: String.LocalizationValue("insights_no_expenses_month_format")),
                        locale: .current,
                        activeCurrency
                    )
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            } else {
                Chart(rows) { row in
                    BarMark(
                        x: .value(String(localized: String.LocalizationValue("insights_chart_amount")), row.total),
                        y: .value(String(localized: String.LocalizationValue("insights_chart_category")), row.category)
                    )
                    .annotation(position: .trailing, alignment: .leading) {
                        Text(formatted(amount: row.total, code: activeCurrency))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: CGFloat(max(220, rows.count * 36)))
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var monthlySection: some View {
        let cal = Calendar.current
        let monthStarts = ExpenseSummary.lastNMonthStarts(n: 6, endingAt: Date(), calendar: cal)
        let totals = ExpenseSummary.monthlyTotals(expenses: Array(expenses), currencyFilter: activeCurrency)
        let totalsByMonth = Dictionary(uniqueKeysWithValues: totals.map { ($0.monthStart, $0.total) })

        let chartRows: [(month: Date, total: Double)] = monthStarts.map { month in
            (month, totalsByMonth[month] ?? 0)
        }

        return VStack(alignment: .leading, spacing: 8) {
            Text("insights_last_6_months")
                .font(.headline)

            Chart(chartRows, id: \.month) { row in
                BarMark(
                    x: .value(String(localized: String.LocalizationValue("insights_chart_month")), row.month, unit: .month),
                    y: .value(String(localized: String.LocalizationValue("insights_chart_total")), row.total)
                )
                .foregroundStyle(.tint)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel(monthLabel(date))
                    }
                }
            }
            .frame(height: 220)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.pie")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("insights_empty_title")
                .font(.headline)
            Text("insights_empty_detail")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func syncCurrencySelection() {
        guard !currencyCodes.isEmpty else {
            selectedCurrency = ""
            return
        }
        if selectedCurrency.isEmpty || !currencyCodes.contains(selectedCurrency) {
            selectedCurrency = currencyCodes[0]
        }
    }

    private func monthLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMM yy")
        return formatter.string(from: date)
    }

    private func formatted(amount: Double, code: String) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = code
        nf.locale = Locale.current
        return nf.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
}

#Preview("Insights") {
    NavigationStack {
        InsightsView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
