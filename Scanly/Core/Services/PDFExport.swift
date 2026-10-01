import Foundation
import UIKit

enum PDFExport {
    private static let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
    private static let margin: CGFloat = 48
    private static let rowHeight: CGFloat = 18
    private static let headerFont = UIFont.boldSystemFont(ofSize: 11)
    private static let bodyFont = UIFont.systemFont(ofSize: 10)
    private static let titleFont = UIFont.boldSystemFont(ofSize: 20)
    private static let metaFont = UIFont.systemFont(ofSize: 10)

    static func writeTemporaryFile(from expenses: [Expense], filename: String = "scanly-expenses.pdf") throws -> URL {
        let sorted = expenses.sorted(by: { $0.transactionDate > $1.transactionDate })
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { context in
            var cursorY = margin
            let contentWidth = pageRect.width - margin * 2

            func drawTitlePageHeader() {
                (String(localized: String.LocalizationValue("pdf_title")) as NSString).draw(
                    at: CGPoint(x: margin, y: cursorY),
                    withAttributes: [.font: titleFont]
                )
                cursorY += 28
                let generated = "\(String(localized: String.LocalizationValue("pdf_generated_prefix"))) \(formattedGeneratedDate())"
                (generated as NSString).draw(
                    at: CGPoint(x: margin, y: cursorY),
                    withAttributes: [.font: metaFont, .foregroundColor: UIColor.secondaryLabel]
                )
                cursorY += 22
            }

            func beginContinuationPage() {
                context.beginPage()
                cursorY = margin
                drawTableHeader(at: &cursorY, contentWidth: contentWidth)
            }

            context.beginPage()
            drawTitlePageHeader()

            if sorted.isEmpty {
                (String(localized: String.LocalizationValue("pdf_no_expenses")) as NSString).draw(
                    at: CGPoint(x: margin, y: cursorY),
                    withAttributes: [.font: bodyFont, .foregroundColor: UIColor.secondaryLabel]
                )
                return
            }

            drawTableHeader(at: &cursorY, contentWidth: contentWidth)

            for expense in sorted {
                if cursorY > pageRect.height - margin - rowHeight * 2 {
                    beginContinuationPage()
                }
                drawRow(expense, at: &cursorY, contentWidth: contentWidth)
            }
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func formattedGeneratedDate() -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: Date())
    }

    private static func drawTableHeader(at cursorY: inout CGFloat, contentWidth: CGFloat) {
        let columns = columnFrames(contentWidth: contentWidth)
        let headers = [
            String(localized: String.LocalizationValue("pdf_col_date")),
            String(localized: String.LocalizationValue("pdf_col_merchant")),
            String(localized: String.LocalizationValue("pdf_col_category")),
            String(localized: String.LocalizationValue("pdf_col_amount"))
        ]
        let fonts = [headerFont, headerFont, headerFont, headerFont]
        for (i, text) in headers.enumerated() {
            let rect = columns[i]
            let attr: [NSAttributedString.Key: Any] = [.font: fonts[i]]
            let s = NSAttributedString(string: text, attributes: attr)
            let y = cursorY
            if i == 3 {
                let size = s.size()
                s.draw(at: CGPoint(x: rect.maxX - size.width, y: y))
            } else {
                s.draw(with: CGRect(x: rect.minX, y: y, width: rect.width, height: rowHeight), options: .usesLineFragmentOrigin, context: nil)
            }
        }
        cursorY += rowHeight
        let lineY = cursorY - 4
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: lineY))
        path.addLine(to: CGPoint(x: margin + contentWidth, y: lineY))
        UIColor.separator.setStroke()
        path.lineWidth = 0.5
        path.stroke()
        cursorY += 6
    }

    private static func columnFrames(contentWidth: CGFloat) -> [CGRect] {
        let wDate: CGFloat = 88
        let wAmount: CGFloat = 96
        let wCategory: CGFloat = 96
        let wMerchant = contentWidth - wDate - wCategory - wAmount
        let x0 = margin
        let x1 = x0 + wDate
        let x2 = x1 + wMerchant
        let x3 = x2 + wCategory
        return [
            CGRect(x: x0, y: 0, width: wDate, height: rowHeight),
            CGRect(x: x1, y: 0, width: wMerchant, height: rowHeight),
            CGRect(x: x2, y: 0, width: wCategory, height: rowHeight),
            CGRect(x: x3, y: 0, width: wAmount, height: rowHeight)
        ]
    }

    private static func drawRow(_ expense: Expense, at cursorY: inout CGFloat, contentWidth: CGFloat) {
        let columns = columnFrames(contentWidth: contentWidth)
        let dateText = formattedTransactionDate(expense.transactionDate)
        let merchant = expense.merchant.isEmpty ? "—" : expense.merchant
        let merchantLine = truncate(merchant, maxWidth: columns[1].width - 2, font: bodyFont)
        let category = expense.category.isEmpty ? "—" : expense.category
        let amountText = formattedAmount(expense)

        let rowY = cursorY
        (dateText as NSString).draw(
            with: CGRect(x: columns[0].minX, y: rowY, width: columns[0].width, height: rowHeight * 2),
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: [.font: bodyFont],
            context: nil
        )
        (merchantLine as NSString).draw(
            with: CGRect(x: columns[1].minX, y: rowY, width: columns[1].width, height: rowHeight * 2),
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: [.font: bodyFont],
            context: nil
        )
        (category as NSString).draw(
            with: CGRect(x: columns[2].minX, y: rowY, width: columns[2].width, height: rowHeight * 2),
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: [.font: bodyFont],
            context: nil
        )
        let amountAttr = NSAttributedString(string: amountText, attributes: [.font: bodyFont])
        let amountSize = amountAttr.size()
        amountAttr.draw(at: CGPoint(x: columns[3].maxX - amountSize.width, y: rowY))

        cursorY += rowHeight
    }

    private static func formattedTransactionDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    private static func formattedAmount(_ expense: Expense) -> String {
        let code = expense.currencyCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = code.isEmpty ? "USD" : code
        nf.locale = Locale.current
        return nf.string(from: NSNumber(value: expense.amount)) ?? String(expense.amount)
    }

    private static func truncate(_ text: String, maxWidth: CGFloat, font: UIFont) -> String {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let s = text as NSString
        if s.size(withAttributes: attrs).width <= maxWidth {
            return text
        }
        var low = 0
        var high = text.count
        let ellipsis = "…"
        while low < high {
            let mid = (low + high + 1) / 2
            let prefix = String(text.prefix(mid)) + ellipsis
            if (prefix as NSString).size(withAttributes: attrs).width <= maxWidth {
                low = mid
            } else {
                high = mid - 1
            }
        }
        if low == 0 {
            return ellipsis
        }
        return String(text.prefix(low)) + ellipsis
    }
}
