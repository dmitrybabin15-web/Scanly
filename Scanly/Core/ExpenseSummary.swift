import CoreData
import Foundation

enum ExpenseSummary {
    struct MonthTotal: Identifiable {
        let monthStart: Date
        let total: Double
        let currencyCode: String

        var id: String { "\(currencyCode)-\(monthStart.timeIntervalSince1970)" }
    }

    struct CategoryTotal: Identifiable {
        let category: String
        let total: Double

        var id: String { category }
    }

    /// Groups by calendar month start (user calendar) and sums amounts. Optionally filters by ISO currency.
    static func monthlyTotals(expenses: [Expense], currencyFilter: String?) -> [MonthTotal] {
        let cal = Calendar.current
        var sums: [String: Double] = [:]

        for expense in expenses {
            let code = expense.currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !code.isEmpty else { continue }
            if let currencyFilter, code != currencyFilter.uppercased() { continue }

            let comps = cal.dateComponents([.year, .month], from: expense.transactionDate)
            guard let monthStart = cal.date(from: comps) else { continue }

            let key = "\(code)|\(monthStart.timeIntervalSince1970)"
            sums[key, default: 0] += expense.amount
        }

        return sums.map { key, total in
            let parts = key.split(separator: "|")
            let code = String(parts[0])
            let ts = TimeInterval(parts[1]) ?? 0
            let monthStart = Date(timeIntervalSince1970: ts)
            return MonthTotal(monthStart: monthStart, total: total, currencyCode: code)
        }
        .sorted { $0.monthStart < $1.monthStart }
    }

    /// Sums by category for `[start, end)` on `transactionDate`.
    static func categoryTotals(
        expenses: [Expense],
        currencyFilter: String?,
        from start: Date,
        to end: Date
    ) -> [CategoryTotal] {
        var sums: [String: Double] = [:]

        for expense in expenses {
            guard expense.transactionDate >= start, expense.transactionDate < end else { continue }
            let code = expense.currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !code.isEmpty else { continue }
            if let currencyFilter, code != currencyFilter.uppercased() { continue }

            let category = expense.category.trimmingCharacters(in: .whitespacesAndNewlines)
            let label = category.isEmpty ? "Other" : category
            sums[label, default: 0] += expense.amount
        }

        return sums.map { CategoryTotal(category: $0.key, total: $0.value) }
            .sorted { $0.total > $1.total }
    }

    /// Month range `[start, nextMonth)` for the same calendar month as `reference`.
    static func monthInterval(containing reference: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let comps = calendar.dateComponents([.year, .month], from: reference)
        let start = calendar.date(from: comps) ?? reference
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? reference
        return (start, end)
    }

    static func lastNMonthStarts(n: Int, endingAt reference: Date, calendar: Calendar = .current) -> [Date] {
        guard let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: reference)) else {
            return []
        }
        return (0 ..< n).compactMap { offset in
            calendar.date(byAdding: .month, value: -offset, to: currentMonth)
        }.reversed()
    }
}
