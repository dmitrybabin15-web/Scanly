import SwiftUI
import CoreData

struct ExpensesListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var subscription: SubscriptionService

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Expense.createdAt, ascending: false)],
        animation: .default
    )
    private var expenses: FetchedResults<Expense>

    @State private var isSharePresented = false
    @State private var shareURL: URL?
    @State private var showPaywall = false
    @State private var exportErrorMessage: String?
    @State private var dataErrorMessage: String?

    var body: some View {
        Group {
            if expenses.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(expenses) { expense in
                        ExpenseRow(expense: expense)
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("expenses_nav_title")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if !subscription.isPro {
                        Button("expenses_upgrade_pro", systemImage: "crown") {
                            showPaywall = true
                        }
                    }

                    Button("expenses_export_csv", systemImage: "doc.text") {
                        prepareExport(.csv)
                    }
                    .disabled(expenses.isEmpty)

                    Button("expenses_export_pdf", systemImage: "doc.richtext") {
                        prepareExport(.pdf)
                    }
                    .disabled(expenses.isEmpty)

                    Button("expenses_add_sample", systemImage: "plus") {
                        addSample()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("expenses_a11y_actions")
            }
        }
        .sheet(isPresented: $isSharePresented, onDismiss: { shareURL = nil }) {
            if let shareURL {
                ShareSheet(items: [shareURL])
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(subscription: subscription)
        }
        .alert("expenses_export_error_title", isPresented: Binding(get: { exportErrorMessage != nil }, set: { _ in exportErrorMessage = nil })) {
            Button("common_ok", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "")
        }
        .alert("expenses_data_error_title", isPresented: Binding(get: { dataErrorMessage != nil }, set: { _ in dataErrorMessage = nil })) {
            Button("common_ok", role: .cancel) {}
        } message: {
            Text(dataErrorMessage ?? "")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("expenses_empty_title")
                .font(.headline)
            Text("expenses_empty_detail")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("expenses_add_sample_button") {
                addSample()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private enum ExportKind {
        case csv
        case pdf
    }

    private func prepareExport(_ kind: ExportKind) {
        do {
            let url: URL
            switch kind {
            case .csv:
                url = try CSVExport.writeTemporaryFile(from: Array(expenses))
            case .pdf:
                url = try PDFExport.writeTemporaryFile(from: Array(expenses))
            }
            shareURL = url
            isSharePresented = true
        } catch {
            let fallback = String(localized: String.LocalizationValue("expenses_export_error_fallback"))
            exportErrorMessage = error.localizedDescription.isEmpty ? fallback : error.localizedDescription
        }
    }

    private func addSample() {
        Expense.insertSample(
            in: viewContext,
            merchant: String(localized: String.LocalizationValue("sample_merchant_name")),
            amount: Double.random(in: 1.0 ... 99.0),
            currencyCode: "USD",
            category: String(localized: String.LocalizationValue("category_other"))
        )
        do {
            try viewContext.save()
        } catch {
            let fallback = String(localized: String.LocalizationValue("expenses_data_error_fallback"))
            dataErrorMessage = error.localizedDescription.isEmpty ? fallback : error.localizedDescription
        }
    }

    private func delete(at offsets: IndexSet) {
        offsets.map { expenses[$0] }.forEach(viewContext.delete)
        do {
            try viewContext.save()
        } catch {
            let fallback = String(localized: String.LocalizationValue("expenses_data_error_fallback"))
            dataErrorMessage = error.localizedDescription.isEmpty ? fallback : error.localizedDescription
        }
    }
}

private struct ExpenseRow: View {
    @ObservedObject var expense: Expense

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(expense.merchant.isEmpty ? "—" : expense.merchant)
                    .font(.headline)
                Spacer()
                Text(formattedAmount)
                    .font(.headline.monospacedDigit())
            }
            HStack {
                Text(expense.category)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(expense.transactionDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var formattedAmount: String {
        let code = expense.currencyCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = expense.amount
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = code.isEmpty ? "USD" : code
        nf.locale = Locale.current
        return nf.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

#Preview("Expenses — sample data") {
    NavigationStack {
        ExpensesListView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    .environmentObject(SubscriptionService.shared)
}
