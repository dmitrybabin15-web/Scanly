import CoreData
import Foundation
import SwiftUI
import UIKit

enum CSVExport {
    static func csvString(from expenses: [Expense]) -> String {
        var lines: [String] = ["Date,Amount,Currency,Merchant,Category,CreatedAt"]

        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dayFormatter.dateFormat = "yyyy-MM-dd"

        let createdFormatter = ISO8601DateFormatter()
        createdFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for expense in expenses.sorted(by: { $0.transactionDate > $1.transactionDate }) {
            let fields: [String] = [
                dayFormatter.string(from: expense.transactionDate),
                String(expense.amount),
                escape(expense.currencyCode),
                escape(expense.merchant),
                escape(expense.category),
                createdFormatter.string(from: expense.createdAt)
            ]
            lines.append(fields.joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    static func csvData(from expenses: [Expense]) -> Data {
        Data(csvString(from: expenses).utf8)
    }

    static func writeTemporaryFile(from expenses: [Expense], filename: String = "scanly-expenses.csv") throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try csvData(from: expenses).write(to: url, options: .atomic)
        return url
    }

    private static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
