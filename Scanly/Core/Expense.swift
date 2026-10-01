import CoreData
import Foundation

@objc(Expense)
final class Expense: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Expense> {
        NSFetchRequest<Expense>(entityName: "Expense")
    }

    @NSManaged var id: UUID
    @NSManaged var createdAt: Date
    @NSManaged var transactionDate: Date
    @NSManaged var amount: Double
    @NSManaged var currencyCode: String
    @NSManaged var merchant: String
    @NSManaged var category: String
    @NSManaged var rawText: String?
    @NSManaged var imageData: Data?
}

extension Expense: Identifiable {}

extension Expense {
    /// Temporary helper until scan + AI flow exists — creates a saved expense for UI testing.
    @discardableResult
    static func insertSample(
        in context: NSManagedObjectContext,
        merchant: String,
        amount: Double,
        currencyCode: String,
        category: String
    ) -> Expense {
        let expense = Expense(context: context)
        let now = Date()
        expense.id = UUID()
        expense.createdAt = now
        expense.transactionDate = now
        expense.amount = amount
        expense.currencyCode = currencyCode
        expense.merchant = merchant
        expense.category = category
        expense.rawText = nil
        expense.imageData = nil
        return expense
    }
}
