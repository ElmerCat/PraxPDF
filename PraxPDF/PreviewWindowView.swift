import SwiftUI
import PDFKit
import Combine

struct PreviewWindowView: View {
    @ObservedObject private var previewModel: PDFPreviewModel

    init(previewModel: PDFPreviewModel? = nil) {
        // If no model is injected, create a private one so we don't crash.
        self._previewModel = ObservedObject(wrappedValue: previewModel ?? PDFPreviewModel())
    }

    var body: some View {
        Group {
            if let url = previewModel.fileURL {
                VStack {
                    Text(url.lastPathComponent)
                        .font(.headline)
                        .padding()
                    PDFViewRepresentable(url: url)
                        .edgesIgnoringSafeArea(.all)
                }
            } else {
                ContentUnavailableView {
                    Text("No PDF available")
                }
            }
        }
        .onAppear {
            previewModel.isVisible = true
        }
        .onDisappear {
            previewModel.isVisible = false
        }
    }
}


import AppKit

struct PDFViewRepresentable: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.displaysPageBreaks = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.autoScales = true
        pdfView.backgroundColor = .clear
        return pdfView
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        // Ensure security-scoped access while loading the document
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

        // Reload if document is nil or the URL changed
        let needsReload = (nsView.document == nil) || (nsView.document?.documentURL != url)
        if needsReload {
            if let doc = PDFDocument(url: url) {
                nsView.document = doc
                // Apply layout/scaling after setting document
                nsView.layoutDocumentView()
                nsView.autoScales = true
                print("PDF loaded for \(url.lastPathComponent), pages=\(doc.pageCount)")
            } else {
                nsView.document = nil
                print("Failed to load PDF at: \(url.path)")
            }
        } else {
            // Force layout on same-document updates
            nsView.layoutDocumentView()
        }
    }
}


final class PDFPreviewModel: ObservableObject {
    @Published var fileURL: URL?
    @Published var isVisible: Bool = false
}

#Preview("Preview Window") {
    let model = PDFPreviewModel()
    return PreviewWindowView(previewModel: model)
}
