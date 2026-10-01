import CoreData
import PhotosUI
import SwiftUI
import UIKit
import VisionKit

struct ScanView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var subscription: SubscriptionService

    @State private var isCameraPresented = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var processingMessage = String(localized: String.LocalizationValue("scan_processing_reading"))
    @State private var errorMessage: String?
    @State private var draft: ReceiptDraft?
    @State private var showPaywall = false

    private var isDocumentCameraSupported: Bool {
        VNDocumentCameraViewController.isSupported
    }

    var body: some View {
        Group {
            if let draft {
                reviewView(for: draft)
            } else {
                emptyState
            }
        }
        .navigationTitle("tab_scan")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isDocumentCameraSupported {
                    Button("scan_toolbar_scan", systemImage: "camera") {
                        presentScannerIfAllowed()
                    }
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    Label("scan_toolbar_photo", systemImage: "photo.on.rectangle")
                }
            }
        }
        .onChange(of: selectedPhotoItem) { newItem in
            guard let newItem else { return }
            guard subscription.canStartNewScan() else {
                selectedPhotoItem = nil
                showPaywall = true
                return
            }
            Task {
                await loadPhoto(from: newItem)
            }
        }
        .sheet(isPresented: $isCameraPresented) {
            DocumentCameraRepresentable { image in
                process(image: image)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(subscription: subscription)
        }
        .alert("scan_alert_title", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("common_ok", role: .cancel) {}
        } message: {
            Text(errorMessage ?? String(localized: String.LocalizationValue("scan_error_unknown")))
        }
        .overlay {
            if isProcessing {
                ZStack {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView(processingMessage)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("scan_empty_title")
                .font(.title3.weight(.semibold))
            Text("scan_empty_detail")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            statusBanner
            if !subscription.isPro {
                Text(
                    String(
                        format: String(localized: String.LocalizationValue("scan_free_scans_format")),
                        locale: .current,
                        subscription.freeScansRemaining
                    )
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            }
            if isDocumentCameraSupported {
                Button("scan_open_document_camera") {
                    presentScannerIfAllowed()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("scan_camera_unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var statusBanner: some View {
        Group {
            if subscription.isPro {
                Label("scan_status_pro_active", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            } else if subscription.freeScansRemaining == 0 {
                Label("scan_status_limit_reached", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            } else {
                Label("scan_status_free_plan", systemImage: "person")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
    }

    private func reviewView(for draft: ReceiptDraft) -> some View {
        Form {
            Section("scan_section_receipt_details") {
                TextField("scan_field_merchant", text: binding(\.merchant))
                TextField("scan_field_amount", text: binding(\.amount))
                    .keyboardType(.decimalPad)
                TextField("scan_field_currency", text: binding(\.currencyCode))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                DatePicker("scan_field_date", selection: binding(\.date), displayedComponents: .date)
                TextField("scan_field_category", text: binding(\.category))
            }

            Section("scan_section_ocr_text") {
                TextEditor(text: binding(\.rawText))
                    .font(.footnote.monospaced())
                    .frame(minHeight: 140)
            }

            Section {
                Button("scan_save_expense") { saveDraft() }
                    .buttonStyle(.borderedProminent)
                Button("scan_scan_again") {
                    self.draft = nil
                    if isDocumentCameraSupported {
                        presentScannerIfAllowed()
                    }
                }
            }
        }
    }

    private func loadPhoto(from item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                await MainActor.run { errorMessage = String(localized: String.LocalizationValue("scan_error_load_photo")) }
                return
            }
            await MainActor.run {
                selectedPhotoItem = nil
                process(image: image)
            }
        } catch {
            await MainActor.run {
                errorMessage = displayErrorMessage(error, fallbackKey: "scan_error_photo_access_fallback")
            }
        }
    }

    private func presentScannerIfAllowed() {
        guard subscription.canStartNewScan() else {
            errorMessage = String(localized: String.LocalizationValue("scan_error_limit_reached"))
            showPaywall = true
            return
        }
        isCameraPresented = true
    }

    private func process(image: UIImage) {
        guard subscription.canStartNewScan() else {
            errorMessage = String(localized: String.LocalizationValue("scan_error_limit_reached"))
            showPaywall = true
            return
        }
        guard let cgImage = image.cgImage else {
            errorMessage = String(localized: String.LocalizationValue("scan_error_read_image"))
            return
        }

        isProcessing = true
        processingMessage = String(localized: String.LocalizationValue("scan_processing_reading"))

        Task {
            do {
                let text = try await recognizeTextOffMainThread(from: cgImage)

                await MainActor.run {
                    processingMessage = String(localized: String.LocalizationValue("scan_processing_understanding"))
                }

                let ai = await AIParsingService.parseReceipt(ocrText: text)
                let draft = ReceiptDraft.fromOCRText(text, ai: ai)

                await MainActor.run {
                    self.draft = draft
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = displayErrorMessage(error, fallbackKey: "scan_error_processing_fallback")
                    isProcessing = false
                }
            }
        }
    }

    private func recognizeTextOffMainThread(from cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let text = try OCRService().recognizeText(from: cgImage)
                    continuation.resume(returning: text)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func saveDraft() {
        guard let draft else { return }
        guard subscription.isPro || subscription.canStartNewScan() else {
            showPaywall = true
            return
        }
        let expense = Expense(context: viewContext)
        expense.id = UUID()
        expense.createdAt = Date()
        expense.transactionDate = draft.date
        expense.amount = draft.parsedAmount
        let code = draft.currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        expense.currencyCode = code.isEmpty ? "USD" : String(code.prefix(3))
        expense.merchant = draft.merchant
        expense.category = draft.category.isEmpty ? String(localized: String.LocalizationValue("category_other")) : draft.category
        expense.rawText = draft.rawText
        expense.imageData = nil

        do {
            try viewContext.save()
            subscription.recordFreeScanSaveIfNeeded()
            self.draft = nil
        } catch {
            let fallback = String(localized: String.LocalizationValue("scan_error_save_fallback"))
            errorMessage = displayErrorMessage(error, fallback: fallback)
        }
    }

    private func displayErrorMessage(_ error: Error, fallbackKey: String) -> String {
        displayErrorMessage(error, fallback: String(localized: String.LocalizationValue(fallbackKey)))
    }

    private func displayErrorMessage(_ error: Error, fallback: String) -> String {
        let text = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty || text == "The operation couldn’t be completed." {
            return fallback
        }
        return text
    }

    private func binding<T>(_ keyPath: WritableKeyPath<ReceiptDraft, T>) -> Binding<T> {
        Binding(
            get: { draft?[keyPath: keyPath] ?? ReceiptDraft.fromOCRText("")[keyPath: keyPath] },
            set: { newValue in
                guard var draft else { return }
                draft[keyPath: keyPath] = newValue
                self.draft = draft
            }
        )
    }
}

private struct DocumentCameraRepresentable: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onImagePicked: (UIImage) -> Void

        init(onImagePicked: @escaping (UIImage) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            defer { controller.dismiss(animated: true) }
            guard scan.pageCount > 0 else { return }
            onImagePicked(scan.imageOfPage(at: 0))
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true)
        }
    }
}

#Preview("Scan") {
    NavigationStack {
        ScanView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    .environmentObject(SubscriptionService.shared)
}
