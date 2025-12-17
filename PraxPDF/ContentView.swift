//
//  ContentView.swift
//  PraxPDF
//
//  Created by Elmer Cat on 12/15/25.
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import AppKit

struct PDFEntry: Identifiable, Hashable {
    let id: UUID
    let url: URL
    var fileName: String { url.lastPathComponent }
    let pcardHolderName: String?
    let documentNumber: String?
    let date: String?
    let amount: String?
    let vendor: String?
    let glAccount: String?
    let costObject: String?
    let description: String?
    
    init(id: UUID = UUID(), url: URL, pcardHolderName: String?, documentNumber: String?, date: String?, amount: String?, vendor: String?, glAccount: String?, costObject: String?, description: String?) {
        self.id = id
        self.url = url
        self.pcardHolderName = pcardHolderName
        self.documentNumber = documentNumber
        self.date = date
        self.amount = amount
        self.vendor = vendor
        self.glAccount = glAccount
        self.costObject = costObject
        self.description = description
    }
}

struct ContentView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @ObservedObject var pdfPreviewModel: PDFPreviewModel

    @State private var showingImporter = false
    @State private var selectedFiles: [PDFEntry] = []
    @State private var importError: String?
    @State private var selection: PDFEntry.ID? = nil

    // Editing state for selected entry
    @State private var editPcardHolderName: String = ""
    @State private var editDocumentNumber: String = ""
    @State private var editDate: String = ""
    @State private var editAmount: String = ""
    @State private var editVendor: String = ""
    @State private var editGLAccount: String = ""
    @State private var editCostObject: String = ""
    @State private var editDescription: String = ""
    @State private var saveError: String?
    @State private var showSavePanel: Bool = false

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Button {
                    showingImporter = true
                } label: {
                    Label("Select Files", systemImage: "folder.badge.plus")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    selectedFiles.removeAll()
                    selection = nil
                } label: {
                    Label("Clear List", systemImage: "trash")
                        .font(.headline)
                }
                .buttonStyle(.bordered)
                .disabled(selectedFiles.isEmpty)
            }

            if !selectedFiles.isEmpty {
                Text("Selected Files")
                    .font(.title3)
                    .bold()

                Table(selectedFiles, selection: $selection) {
                    TableColumn("File") { entry in
                        Text(entry.fileName)
                    }
                    TableColumn("PcardHolderName") { entry in
                        Text(entry.pcardHolderName ?? "—")
                    }
                    TableColumn("DocumentNumber") { entry in
                        Text(entry.documentNumber ?? "—")
                    }
                    TableColumn("Date") { entry in
                        Text(entry.date ?? "—")
                    }
                    TableColumn("Amount") { entry in
                        Text(entry.amount ?? "—")
                    }
                    TableColumn("Vendor") { entry in
                        Text(entry.vendor ?? "—")
                    }
                    TableColumn("GLAccount") { entry in
                        Text(entry.glAccount ?? "—")
                    }
                    TableColumn("CostObject") { entry in
                        Text(entry.costObject ?? "—")
                    }
                    TableColumn("Description") { entry in
                        Text(entry.description ?? "—")
                    }
                }
                .frame(minHeight: 200)
            } else {
                ContentUnavailableView("No files selected", systemImage: "doc", description: Text("Click ‘Select Files’ to choose one or more documents."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
        .navigationTitle("PraxPDF")
        .onChange(of: selection) { _, newValue in
            if let id = newValue, let entry = selectedFiles.first(where: { $0.id == id }) {
                editPcardHolderName = entry.pcardHolderName ?? ""
                editDocumentNumber = entry.documentNumber ?? ""
                editDate = entry.date ?? ""
                editAmount = entry.amount ?? ""
                editVendor = entry.vendor ?? ""
                editGLAccount = entry.glAccount ?? ""
                editCostObject = entry.costObject ?? ""
                editDescription = entry.description ?? ""

                pdfPreviewModel.fileURL = entry.url
                openWindow(id: "preview")
            } else {
                editPcardHolderName = ""
                editDocumentNumber = ""
                editDate = ""
                editAmount = ""
                editVendor = ""
                editGLAccount = ""
                editCostObject = ""
                editDescription = ""

                pdfPreviewModel.fileURL = nil
                dismissWindow(id: "preview")
            }
        }
    }

    private var detailView: some View {
        Group {
            if let id = selection, let entry = selectedFiles.first(where: { $0.id == id }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(entry.fileName)
                            .font(.title2).bold()

                        VStack(alignment: .leading, spacing: 10) {
                            LabeledContent("Pcard Holder") { TextField("Pcard Holder", text: $editPcardHolderName) }
                            LabeledContent("Document #") { TextField("Document #", text: $editDocumentNumber) }
                            LabeledContent("Date") { TextField("Date", text: $editDate) }
                            LabeledContent("Amount") { TextField("Amount", text: $editAmount) }
                            LabeledContent("Vendor") { TextField("Vendor", text: $editVendor) }
                            LabeledContent("GL Account") { TextField("GL Account", text: $editGLAccount) }
                            LabeledContent("Cost Object") { TextField("Cost Object", text: $editCostObject) }
                            LabeledContent("Description") { TextField("Description", text: $editDescription) }
                        }

                        HStack {
                            Button("Save") {
                                handleSaveCurrentSelection()
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Save As…") {
                                showSavePanel = true
                            }
                            .buttonStyle(.bordered)
                        }

                        Divider()
                    }
                    .padding()
                }
                .navigationTitle("Details")
            } else {
                ContentUnavailableView("No Selection", systemImage: "square.split.2x1", description: Text("Choose a row on the left to see details."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .sheet(isPresented: $showSavePanel) {
            if let id = selection, let entry = selectedFiles.first(where: { $0.id == id }) {
                SaveAsPanel(suggestedURL: entry.url) { destination in
                    do {
                        try saveEdits(from: entry.url, to: destination)
                    } catch {
                        saveError = error.localizedDescription
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.pdf, .folder],
            allowsMultipleSelection: true
        ) { result in
            handleImportResult(result)
        }
        .alert("Save Error", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "Unknown error")
        }
        .alert("Import Error", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "Unknown error")
        }
    }

    private func handleSaveCurrentSelection() {
        if let id = selection, let entry = selectedFiles.first(where: { $0.id == id }) {
            do {
                try saveEdits(to: entry.url)
                if let idx = selectedFiles.firstIndex(where: { $0.id == id }) {
                    selectedFiles[idx] = PDFEntry(
                        id: entry.id,
                        url: entry.url,
                        pcardHolderName: editPcardHolderName.isEmpty ? nil : editPcardHolderName,
                        documentNumber: editDocumentNumber.isEmpty ? nil : editDocumentNumber,
                        date: editDate.isEmpty ? nil : editDate,
                        amount: editAmount.isEmpty ? nil : editAmount,
                        vendor: editVendor.isEmpty ? nil : editVendor,
                        glAccount: editGLAccount.isEmpty ? nil : editGLAccount,
                        costObject: editCostObject.isEmpty ? nil : editCostObject,
                        description: editDescription.isEmpty ? nil : editDescription
                    )
                    if pdfPreviewModel.isVisible {
                        // Reassign to trigger update
                        let current = pdfPreviewModel.fileURL
                        pdfPreviewModel.fileURL = nil
                        pdfPreviewModel.fileURL = current
                    }
                }
            } catch {
                saveError = error.localizedDescription
            }
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            processImportedURLs(urls)
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func processImportedURLs(_ urls: [URL]) {
        var seen = Set<URL>(selectedFiles.map { $0.url })

        func filesRecursively(in folderURL: URL) -> [URL] {
            var collected: [URL] = []
            let fm = FileManager.default
            if let enumerator = fm.enumerator(at: folderURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
                for case let item as URL in enumerator {
                    do {
                        let resourceValues = try item.resourceValues(forKeys: [.isDirectoryKey])
                        if resourceValues.isDirectory == true {
                            continue
                        } else {
                            collected.append(item)
                            print("Discovered file in folder: \(item.path)")
                        }
                    } catch {
                        continue
                    }
                }
            }
            return collected
        }

        func extractFormFields(from url: URL) -> PDFEntry? {
            let needsStop = url.startAccessingSecurityScopedResource()
            defer { if needsStop { url.stopAccessingSecurityScopedResource() } }
            print("\n--- Parsing PDF: \(url.lastPathComponent) ---")
            guard let doc = PDFDocument(url: url) else {
                print("Failed to open PDF: \(url.path)")
                return nil
            }
            print("Opened PDF. Page count: \(doc.pageCount)")

            var pcardHolderName: String?
            var documentNumber: String?
            var date: String?
            var amount: String?
            var vendor: String?
            var glAccount: String?
            var costObject: String?
            var description: String?

            func value(from annot: PDFAnnotation) -> String? {
                if let v = annot.widgetStringValue, !v.isEmpty { return v }
                if let v = annot.contents, !v.isEmpty { return v }
                return nil
            }

            for pageIndex in 0..<doc.pageCount {
                guard let page = doc.page(at: pageIndex) else { continue }
                print("Page #\(pageIndex + 1): annotations=\(page.annotations.count)")
                for annot in page.annotations {
                    let key = annot.fieldName ?? ""
                    if key.isEmpty { continue }
                    let widgetType = String(describing: annot.widgetFieldType)
                    let extracted = value(from: annot) ?? "(nil)"
                    print("  Annotation field=\(key) type=\(widgetType) value=\(extracted)")

                    if let v = value(from: annot), !(v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                        switch key {
                        case "PcardHolderName":
                            if pcardHolderName == nil { pcardHolderName = v }
                        case "DocumentNumber":
                            if documentNumber == nil { documentNumber = v }
                        case "Date":
                            if date == nil { date = v }
                        case "Amount":
                            if amount == nil { amount = v }
                        case "Vendor":
                            if vendor == nil { vendor = v }
                        case "GLAccount":
                            if glAccount == nil { glAccount = v }
                        case "CostObject":
                            if costObject == nil { costObject = v }
                        case "Description":
                            if description == nil { description = v }
                        default:
                            break
                        }
                    }
                }
            }

            print("Captured -> Holder=\(pcardHolderName ?? "nil"), Doc#=\(documentNumber ?? "nil"), Date=\(date ?? "nil"), Amount=\(amount ?? "nil"), Vendor=\(vendor ?? "nil"), GL=\(glAccount ?? "nil"), CostObject=\(costObject ?? "nil"), Desc=\(description ?? "nil"))")

            return PDFEntry(
                url: url,
                pcardHolderName: pcardHolderName,
                documentNumber: documentNumber,
                date: date,
                amount: amount,
                vendor: vendor,
                glAccount: glAccount,
                costObject: costObject,
                description: description
            )
        }

        var expanded: [URL] = []
        for url in urls {
            let needsStop = url.startAccessingSecurityScopedResource()
            defer { if needsStop { url.stopAccessingSecurityScopedResource() } }

            do {
                let values = try url.resourceValues(forKeys: [.isDirectoryKey])
                if values.isDirectory == true {
                    expanded.append(contentsOf: filesRecursively(in: url))
                } else {
                    expanded.append(url)
                }
            } catch {
                expanded.append(url)
            }
        }

        expanded = expanded.filter { url in
            if let type = UTType(filenameExtension: url.pathExtension) {
                return type.conforms(to: .pdf)
            }
            return url.pathExtension.lowercased() == "pdf"
        }

        let uniqueURLs = expanded.filter { seen.insert($0).inserted }
        let entries: [PDFEntry] = uniqueURLs.compactMap { extractFormFields(from: $0) ?? PDFEntry(url: $0, pcardHolderName: nil, documentNumber: nil, date: nil, amount: nil, vendor: nil, glAccount: nil, costObject: nil, description: nil) }
        selectedFiles.append(contentsOf: entries)
    }
}

extension ContentView {
    // Convenience: overwrite the same file
    func saveEdits(to url: URL) throws {
        try saveEdits(from: url, to: url)
    }

    // Open the source PDF, apply current edits, and write to destination URL
    func saveEdits(from sourceURL: URL, to destinationURL: URL) throws {
        let needsStopSource = sourceURL.startAccessingSecurityScopedResource()
        defer { if needsStopSource { sourceURL.stopAccessingSecurityScopedResource() } }
        guard let doc = PDFDocument(url: sourceURL) else {
            throw NSError(domain: "PraxPDF", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to open PDF for writing."])
        }

        // Update form fields by name
        let updates: [(String, String)] = [
            ("PcardHolderName", editPcardHolderName),
            ("DocumentNumber", editDocumentNumber),
            ("Date", editDate),
            ("Amount", editAmount),
            ("Vendor", editVendor),
            ("GLAccount", editGLAccount),
            ("CostObject", editCostObject),
            ("Description", editDescription)
        ]

        for pageIndex in 0..<doc.pageCount {
            guard let page = doc.page(at: pageIndex) else { continue }
            for annot in page.annotations {
                guard let key = annot.fieldName, !key.isEmpty else { continue }
                if let newValue = updates.first(where: { $0.0 == key })?.1 {
                    if !newValue.isEmpty {
                        annot.widgetStringValue = newValue
                        annot.contents = newValue
                    } else {
                        annot.widgetStringValue = nil
                        annot.contents = nil
                    }
                }
            }
        }

        // Write to a temporary file first
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
        guard doc.write(to: tmp) else {
            throw NSError(domain: "PraxPDF", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to write PDF data."])
        }

        // Move temp to destination (overwrite if exists)
        let needsStopDest = destinationURL.startAccessingSecurityScopedResource()
        defer { if needsStopDest { destinationURL.stopAccessingSecurityScopedResource() } }
        if fm.fileExists(atPath: destinationURL.path) {
            try? fm.removeItem(at: destinationURL)
        }
        try fm.moveItem(at: tmp, to: destinationURL)
    }
}

// A small wrapper around NSSavePanel to pick a destination URL
struct SaveAsPanel: View {
    let suggestedURL: URL
    let onSave: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SavePanelRepresentable(suggestedURL: suggestedURL) { url in
            if let url { onSave(url) }
            dismiss()
        }
        .frame(width: 0, height: 0)
    }
}


#Preview("ContentView") {
    ContentView(pdfPreviewModel: PDFPreviewModel())
}
