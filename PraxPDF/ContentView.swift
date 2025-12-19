//
//  ContentView.swift
//  PraxPDF - Prax=1219-7
//
//  Created by Elmer Cat on 12/15/25.
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import AppKit
import CoreGraphics

private let DEBUG_LOGS = false

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
    @State private var mergeAsShown: Bool = false

    @State private var pageCount: Int? = nil
    @State private var totalHeightPoints: CGFloat? = nil
    @State private var maxWidthPoints: CGFloat? = nil
    
    @State private var unknownFieldNames: [String] = []
    @State private var showUnknownFieldsAlert: Bool = false

    @AppStorage("mergeTopMargin") private var mergeTopMargin: Double = 0
    @AppStorage("mergeBottomMargin") private var mergeBottomMargin: Double = 0
    @AppStorage("mergeInterPageGap") private var mergeInterPageGap: Double = 0

    @State private var isPreviewingMerge: Bool = false
    @State private var lastPreviewURL: URL? = nil
    @StateObject private var perPageTrimModel = PerPageTrimModel()

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

                // Compute PDF page metrics
                computePageMetrics(for: entry.url)

                pdfPreviewModel.fileURL = entry.url
                PreviewWindowPresenter.shared.present(model: pdfPreviewModel)
                
            } else {
                editPcardHolderName = ""
                editDocumentNumber = ""
                editDate = ""
                editAmount = ""
                editVendor = ""
                editGLAccount = ""
                editCostObject = ""
                editDescription = ""
                
                pageCount = nil
                totalHeightPoints = nil
                maxWidthPoints = nil
                
                unknownFieldNames = []
                showUnknownFieldsAlert = false

                pdfPreviewModel.fileURL = nil
                PreviewWindowPresenter.shared.close()
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

                        Group {
                            if let pc = pageCount, let totalH = totalHeightPoints, let maxW = maxWidthPoints {
                                let inchesW = maxW / 72.0
                                let inchesH = totalH / 72.0
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("PDF Metrics").font(.headline)
                                    Text("Pages: \(pc)")
                                    Text(String(format: "Merged size: %.0f × %.0f pts (%.2f × %.2f in)", maxW, totalH, inchesW, inchesH))
                                    if !unknownFieldNames.isEmpty {
                                        Text("Other fields: \(unknownFieldNames.count)")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            } else {
                                Text("PDF Metrics: —")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Merge Layout").font(.headline)
                            VStack(alignment: .leading, spacing: 12) {
                                LabeledContent("Top trim") {
                                    HStack(spacing: 8) {
                                        TextField("pts", value: $mergeTopMargin, format: .number)
                                            .frame(width: 70)
                                            .textFieldStyle(.roundedBorder)
                                        Stepper(value: $mergeTopMargin, in: 0...1000, step: 1) { EmptyView() }
                                            .labelsHidden()
                                        Slider(value: $mergeTopMargin, in: 0...1000, step: 1)
                                            .frame(width: 160)
                                        Text("\(Int(mergeTopMargin)) pt")
                                        Text(inches(fromPoints: CGFloat(mergeTopMargin))).foregroundStyle(.secondary)
                                    }
                                }
                                LabeledContent("Bottom trim") {
                                    HStack(spacing: 8) {
                                        TextField("pts", value: $mergeBottomMargin, format: .number)
                                            .frame(width: 70)
                                            .textFieldStyle(.roundedBorder)
                                        Stepper(value: $mergeBottomMargin, in: 0...1000, step: 1) { EmptyView() }
                                            .labelsHidden()
                                        Slider(value: $mergeBottomMargin, in: 0...1000, step: 1)
                                            .frame(width: 160)
                                        Text("\(Int(mergeBottomMargin)) pt")
                                        Text(inches(fromPoints: CGFloat(mergeBottomMargin))).foregroundStyle(.secondary)
                                    }
                                }
                                LabeledContent("Gap between pages") {
                                    HStack(spacing: 8) {
                                        TextField("pts", value: $mergeInterPageGap, format: .number)
                                            .frame(width: 70)
                                            .textFieldStyle(.roundedBorder)
                                        Stepper(value: $mergeInterPageGap, in: -200...1000, step: 1) { EmptyView() }
                                            .labelsHidden()
                                        Slider(value: $mergeInterPageGap, in: -200...1000, step: 1)
                                            .frame(width: 160)
                                        Text("\(Int(mergeInterPageGap)) pt")
                                        Text(inches(fromPoints: CGFloat(mergeInterPageGap))).foregroundStyle(.secondary)
                                    }
                                }
                                Menu("Presets") {
                                    Button("No trims (0)") { applyPreset(points: 0) }
                                    Button("0.25 in (18)") { applyPreset(points: 18) }
                                    Button("0.5 in (36)") { applyPreset(points: 36) }
                                    Button("1.0 in (72)") { applyPreset(points: 72) }
                                }
                            }
                            HStack(spacing: 12) {
                                Button(isPreviewingMerge ? "Update Preview" : "Preview Merge") {
                                    previewMergedPDF()
                                }
                                .buttonStyle(.bordered)

                                Button("Open Page Trim Tool") {
                                    if let id = selection, let entry = selectedFiles.first(where: { $0.id == id }) {
                                        // Present a new window with the page crop tool
                                        PageTrimWindowPresenter.present(url: entry.url, model: perPageTrimModel)
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                            .onChange(of: mergeTopMargin) { _, _ in updatePreviewIfNeeded() }
                            .onChange(of: mergeBottomMargin) { _, _ in updatePreviewIfNeeded() }
                            .onChange(of: mergeInterPageGap) { _, _ in updatePreviewIfNeeded() }
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

                            Button("Merge Pages") {
                                handleMergePagesOverwrite()
                            }
                            .buttonStyle(.bordered)

                            Button("Merge Pages As…") {
                                mergeAsShown = true
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
        .sheet(isPresented: $mergeAsShown) {
            if let id = selection, let entry = selectedFiles.first(where: { $0.id == id }) {
                SaveAsPanel(suggestedURL: entry.url.deletingPathExtension().appendingPathExtension("merged.pdf")) { destination in
                    do {
                        try mergeAllPagesVerticallyIntoSinglePage(
                            sourceURL: entry.url,
                            destinationURL: destination,
                            trimTop: CGFloat(mergeTopMargin),
                            trimBottom: CGFloat(mergeBottomMargin),
                            interPageGap: CGFloat(mergeInterPageGap),
                            perPageTrims: perPageTrimModel.trims
                        )
                        // Update preview to show merged result if overwriting selected file
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
        .alert("Other Form Fields Detected", isPresented: $showUnknownFieldsAlert) {
            Button("OK", role: .cancel) { showUnknownFieldsAlert = false }
        } message: {
            if unknownFieldNames.isEmpty {
                Text("No additional form fields detected.")
            } else {
                Text(unknownFieldNames.joined(separator: ", "))
            }
        }
    }
    
    private func updatePreviewIfNeeded() {
        // Only auto-update when we are already previewing a merge
        guard isPreviewingMerge, let id = selection, let entry = selectedFiles.first(where: { $0.id == id }) else { return }
        do {
            let fm = FileManager.default
            let tmp = fm.temporaryDirectory.appendingPathComponent("preview-merged-\(UUID().uuidString)").appendingPathExtension("pdf")
            try mergeAllPagesVerticallyIntoSinglePage(
                sourceURL: entry.url,
                destinationURL: tmp,
                trimTop: CGFloat(mergeTopMargin),
                trimBottom: CGFloat(mergeBottomMargin),
                interPageGap: CGFloat(mergeInterPageGap),
                perPageTrims: perPageTrimModel.trims
            )
            if let old = lastPreviewURL {
                try? FileManager.default.removeItem(at: old)
            }
            pdfPreviewModel.fileURL = tmp
            lastPreviewURL = tmp
            if !pdfPreviewModel.isVisible {
                PreviewWindowPresenter.shared.present(model: pdfPreviewModel)
            }
        } catch {
            saveError = error.localizedDescription
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

    private func computePageMetrics(for url: URL) {
        let needsStop = url.startAccessingSecurityScopedResource()
        defer { if needsStop { url.stopAccessingSecurityScopedResource() } }
        guard let doc = PDFDocument(url: url) else {
            pageCount = nil
            totalHeightPoints = nil
            maxWidthPoints = nil
            return
        }
        let count = doc.pageCount
        var totalH: CGFloat = 0
        var maxW: CGFloat = 0
        let knownFields = KnownFormFields.all
        var foundUnknowns = Set<String>()
        for i in 0..<count {
            guard let page = doc.page(at: i) else { continue }
            let rect = page.bounds(for: .mediaBox)
            totalH += rect.height
            if rect.width > maxW { maxW = rect.width }
            for annot in page.annotations {
                if let name = annot.fieldName, !name.isEmpty, !knownFields.contains(name) {
                    foundUnknowns.insert(name)
                }
            }
        }
        pageCount = count
        totalHeightPoints = totalH
        maxWidthPoints = maxW
        let sortedUnknowns = Array(foundUnknowns).sorted()
        unknownFieldNames = sortedUnknowns
        showUnknownFieldsAlert = !sortedUnknowns.isEmpty
    }
    
    private func inches(fromPoints pts: CGFloat) -> String {
        let inches = pts / 72.0
        return String(format: "%.2f in", inches)
    }
    
    private func applyPreset(points: CGFloat) {
        mergeTopMargin = Double(points)
        mergeBottomMargin = Double(points)
        // Inter-page gap often matches trims; keep as-is to allow zero-gap when desired
    }

    private func handleMergePagesOverwrite() {
        guard let id = selection, let entry = selectedFiles.first(where: { $0.id == id }) else { return }
        do {
            try mergeAllPagesVerticallyIntoSinglePage(
                sourceURL: entry.url,
                destinationURL: entry.url,
                trimTop: CGFloat(mergeTopMargin),
                trimBottom: CGFloat(mergeBottomMargin),
                interPageGap: CGFloat(mergeInterPageGap),
                perPageTrims: perPageTrimModel.trims
            )
            // Refresh preview if it's currently visible
            if pdfPreviewModel.isVisible {
                let current = pdfPreviewModel.fileURL
                pdfPreviewModel.fileURL = nil
                pdfPreviewModel.fileURL = current
            }
            // Recompute metrics based on the new single-page doc
            computePageMetrics(for: entry.url)
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func previewMergedPDF() {
        guard let id = selection, let entry = selectedFiles.first(where: { $0.id == id }) else { return }
        do {
            let fm = FileManager.default
            let tmp = fm.temporaryDirectory.appendingPathComponent("preview-merged-\(UUID().uuidString)").appendingPathExtension("pdf")
            try mergeAllPagesVerticallyIntoSinglePage(
                sourceURL: entry.url,
                destinationURL: tmp,
                trimTop: CGFloat(mergeTopMargin),
                trimBottom: CGFloat(mergeBottomMargin),
                interPageGap: CGFloat(mergeInterPageGap),
                perPageTrims: perPageTrimModel.trims
            )
            if let old = lastPreviewURL {
                try? FileManager.default.removeItem(at: old)
            }
            pdfPreviewModel.fileURL = tmp
            lastPreviewURL = tmp
            isPreviewingMerge = true
            if !pdfPreviewModel.isVisible {
                PreviewWindowPresenter.shared.present(model: pdfPreviewModel)
            }
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func mergeAllPagesVerticallyIntoSinglePage(sourceURL: URL, destinationURL: URL, trimTop: CGFloat = 0, trimBottom: CGFloat = 0, interPageGap: CGFloat = 0, perPageTrims: [Int: EdgeTrims] = [:]) throws {
        let needsStopSource = sourceURL.startAccessingSecurityScopedResource()
        defer { if needsStopSource { sourceURL.stopAccessingSecurityScopedResource() } }
        guard let sourceDoc = PDFDocument(url: sourceURL) else {
            throw NSError(domain: "PraxPDF", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Unable to open source PDF for merging."])
        }

        let pageCount = sourceDoc.pageCount
        if pageCount == 0 {
            let empty = PDFDocument()
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.removeItem(at: destinationURL)
            }
            empty.write(to: destinationURL)
            return
        }

        // Use mediaBox consistently (matches the Trim Tool and thumbnails)
        var pageRects: [CGRect] = []
        pageRects.reserveCapacity(pageCount)

        for i in 0..<pageCount {
            guard let page = sourceDoc.page(at: i) else { continue }
            let rect = page.bounds(for: .mediaBox)
            pageRects.append(rect)
        }

        let canvas = PDFGeometry.canvasSize(for: pageRects, trims: perPageTrims, trimTop: trimTop, trimBottom: trimBottom, interPageGap: interPageGap)
        let canvasWidth = canvas.width
        let canvasHeight = canvas.height

        // Temporarily remove annotations to avoid drawing their appearances twice
        var removedPerPage: [[PDFAnnotation]] = Array(repeating: [], count: pageCount)
        for i in 0..<pageCount {
            if let p = sourceDoc.page(at: i) {
                removedPerPage[i] = p.annotations
                for a in p.annotations { p.removeAnnotation(a) }
            }
        }

        // Create a one-page PDF context
        let fm = FileManager.default
        var mediaBox = CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)
        let tmpOut = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
        guard let consumer = CGDataConsumer(url: tmpOut as CFURL) else {
            throw NSError(domain: "PraxPDF", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Failed to create data consumer."])
        }
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "PraxPDF", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Failed to create PDF context."])
        }

        ctx.beginPDFPage([kCGPDFContextMediaBox as String: mediaBox] as CFDictionary)

        // Stack pages from top to bottom. Track the Y origin of each placed slice for annotation mapping.
        var currentTop = canvasHeight
        var placedOriginsY: [CGFloat] = Array(repeating: 0, count: pageCount)

        for i in 0..<pageCount {
            guard let page = sourceDoc.page(at: i) else { continue }
            let rect = pageRects[i]
            let per = perPageTrims[i] ?? .zero
            let seamTop: CGFloat = (i == 0) ? 0 : trimTop
            let seamBottom: CGFloat = (i == pageCount - 1) ? 0 : trimBottom

            let vis = PDFGeometry.visibleRect(media: rect, trims: per, seamTop: seamTop, seamBottom: seamBottom)
            let visibleWidth = vis.width
            let visibleHeight = vis.height
            guard visibleWidth > 0, visibleHeight > 0 else {
                currentTop -= (max(0, visibleHeight) + interPageGap)
                continue
            }

            // Place the slice at the LEFT edge (x = 0) and directly under the running top
            let destX: CGFloat = 0
            let destY: CGFloat = currentTop - visibleHeight
            placedOriginsY[i] = destY

            ctx.saveGState()
            // Translate so that (vis.minX, vis.minY) in page space lands at (destX, destY) in canvas space
            ctx.translateBy(x: destX - vis.minX, y: destY - vis.minY)
            // Clip in the CURRENT (translated) coordinate system using a rect defined in PAGE space coordinates
            // Because we translated by (-vis.minX, -vis.minY), the clip rect is simply:
            ctx.clip(to: vis)

            if let cgPage = page.pageRef {
                ctx.drawPDFPage(cgPage)
            } else {
                page.draw(with: .mediaBox, to: ctx)
            }
            ctx.restoreGState()

            currentTop -= (visibleHeight + interPageGap)
        }

        ctx.endPDFPage()
        ctx.closePDF()

        // Restore annotations to source pages
        for i in 0..<pageCount {
            if let p = sourceDoc.page(at: i) {
                for a in removedPerPage[i] { p.addAnnotation(a) }
            }
        }

        // Move temp to destination
        let needsStopDest = destinationURL.startAccessingSecurityScopedResource()
        defer { if needsStopDest { destinationURL.stopAccessingSecurityScopedResource() } }
        if fm.fileExists(atPath: destinationURL.path) { try? fm.removeItem(at: destinationURL) }
        try fm.moveItem(at: tmpOut, to: destinationURL)

        // Second pass: reopen merged and re-add cloned annotations with the SAME translation used above
        let needsStopDest2 = destinationURL.startAccessingSecurityScopedResource()
        defer { if needsStopDest2 { destinationURL.stopAccessingSecurityScopedResource() } }
        guard let mergedDoc = PDFDocument(url: destinationURL), let mergedPage = mergedDoc.page(at: 0) else { return }

        for i in 0..<pageCount {
            guard let srcPage = sourceDoc.page(at: i) else { continue }
            let rect = pageRects[i]
            let per = perPageTrims[i] ?? .zero
            let seamTop: CGFloat = (i == 0) ? 0 : trimTop
            let seamBottom: CGFloat = (i == pageCount - 1) ? 0 : trimBottom

            let vis = PDFGeometry.visibleRect(media: rect, trims: per, seamTop: seamTop, seamBottom: seamBottom)
            let dx = 0 - vis.minX
            let dy = placedOriginsY[i] - vis.minY

            for annot in srcPage.annotations {
                guard annot.fieldName != nil else { continue }
                guard let copied = annot.copy() as? PDFAnnotation else { continue }
                copied.bounds = annot.bounds.offsetBy(dx: dx, dy: dy)
                mergedPage.addAnnotation(copied)
                if copied.widgetFieldType == .text {
                    if let v = copied.widgetStringValue, !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        copied.widgetStringValue = v
                    }
                }
            }
        }

        // Save final merged doc safely
        let tmpFinal = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
        guard mergedDoc.write(to: tmpFinal) else { return }
        if fm.fileExists(atPath: destinationURL.path) { try? fm.removeItem(at: destinationURL) }
        try fm.moveItem(at: tmpFinal, to: destinationURL)
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
                            if DEBUG_LOGS { print("Discovered file in folder: \(item.path)") }
                            collected.append(item)
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
            if DEBUG_LOGS { print("\n--- Parsing PDF: \(url.lastPathComponent) ---") }
            guard let doc = PDFDocument(url: url) else {
                if DEBUG_LOGS { print("Failed to open PDF: \(url.path)") }
                return nil
            }
            if DEBUG_LOGS { print("Opened PDF. Page count: \(doc.pageCount)") }

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
                if DEBUG_LOGS { print("Page #\(pageIndex + 1): annotations=\(page.annotations.count)") }
                for annot in page.annotations {
                    let key = annot.fieldName ?? ""
                    if key.isEmpty { continue }
                    let widgetType = String(describing: annot.widgetFieldType)
                    let extracted = value(from: annot) ?? "(nil)"
                    if DEBUG_LOGS { print("  Annotation field=\(key) type=\(widgetType) value=\(extracted)") }

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

            if DEBUG_LOGS {
                print("Captured -> Holder=\(pcardHolderName ?? "nil"), Doc#=\(documentNumber ?? "nil"), Date=\(date ?? "nil"), Amount=\(amount ?? "nil"), Vendor=\(vendor ?? "nil"), GL=\(glAccount ?? "nil"), CostObject=\(costObject ?? "nil"), Desc=\(description ?? "nil"))")
            }

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

        expanded = expanded.filter { isPDF($0) }

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
                    let target = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    let current = (annot.widgetStringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if current != target {
                        annot.widgetStringValue = target
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

private final class PageTrimWindowPresenter: NSObject, NSWindowDelegate {
    static let shared = PageTrimWindowPresenter()
    private var window: NSWindow?
    private let frameKey = "PageTrimWindowFrame"

    static func present(url: URL, model: PerPageTrimModel) {
        shared.present(url: url, model: model)
    }

    private func present(url: URL, model: PerPageTrimModel) {
        if let win = window, let hosting = win.contentViewController as? NSHostingController<PageTrimView> {
            hosting.rootView = PageTrimView(url: url, model: model)
            win.makeKeyAndOrderFront(nil)
            return
        }
        let hosting = NSHostingController(rootView: PageTrimView(url: url, model: model))
        let win = NSWindow(contentViewController: hosting)
        win.title = "Page Trim Tool"
        if let saved = UserDefaults.standard.string(forKey: frameKey) {
            win.setFrame(NSRectFromString(saved), display: true)
        } else {
            win.setContentSize(NSSize(width: 900, height: 700))
            win.center()
        }
        win.delegate = self
        win.isReleasedWhenClosed = false
        win.makeKeyAndOrderFront(nil)
        window = win
    }

    func windowDidMove(_ notification: Notification) { saveFrame(notification) }
    func windowDidEndLiveResize(_ notification: Notification) { saveFrame(notification) }
    func windowWillClose(_ notification: Notification) { window = nil }

    private func saveFrame(_ notification: Notification) {
        guard let win = notification.object as? NSWindow else { return }
        UserDefaults.standard.set(NSStringFromRect(win.frame), forKey: frameKey)
    }
}

#Preview("ContentView") {
    ContentView(pdfPreviewModel: PDFPreviewModel())
}

