//
//  PreviewWindowView.swift
//  PraxPDF - Prax=1219-7
//

import SwiftUI
import PDFKit
import AppKit
import Combine

// Minimal SwiftUI wrapper around PDFView
struct PDFViewContainer: View {
    @ObservedObject var previewModel: PDFPreviewModel

    var body: some View {
        Group {
            if let url = previewModel.fileURL {
                PDFViewRepresentable(url: url)
            } else {
                ContentUnavailableView { Text("No PDF available") }
            }
        }
    }
}

// Keep existing representable
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
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }
        let needsReload = (nsView.document == nil) || (nsView.document?.documentURL != url)
        if needsReload {
            if let doc = PDFDocument(url: url) {
                nsView.document = doc
                nsView.layoutDocumentView()
                nsView.autoScales = true
            } else {
                nsView.document = nil
            }
        } else {
            nsView.layoutDocumentView()
        }
    }
}

final class PDFPreviewModel: ObservableObject {
    @Published var fileURL: URL?
    @Published var isVisible: Bool = false
}

// Presenter that mirrors PageTrimWindowPresenter
final class PreviewWindowPresenter: NSObject, NSWindowDelegate {
    static let shared = PreviewWindowPresenter()
    private var window: NSWindow?
    private let frameKey = "PreviewWindowFrame"

    func present(model: PDFPreviewModel) {
        if let win = window, let hosting = win.contentViewController as? NSHostingController<PDFViewContainer> {
            hosting.rootView = PDFViewContainer(previewModel: model)
            win.makeKeyAndOrderFront(nil)
            model.isVisible = true
            return
        }
        let hosting = NSHostingController(rootView: PDFViewContainer(previewModel: model))
        let win = NSWindow(contentViewController: hosting)
        win.title = "Preview"
        if let saved = UserDefaults.standard.string(forKey: frameKey) {
            win.setFrame(NSRectFromString(saved), display: true)
        } else {
            win.setContentSize(NSSize(width: 800, height: 1000))
            win.center()
        }
        win.delegate = self
        win.isReleasedWhenClosed = false
        win.makeKeyAndOrderFront(nil)
        window = win
        model.isVisible = true
    }

    func close() {
        window?.close()
    }

    func windowDidMove(_ notification: Notification) { saveFrame(notification) }
    func windowDidEndLiveResize(_ notification: Notification) { saveFrame(notification) }
    func windowWillClose(_ notification: Notification) {
        if let hosting = window?.contentViewController as? NSHostingController<PDFViewContainer> {
            hosting.rootView.previewModel.isVisible = false
        }
        window = nil
    }

    private func saveFrame(_ notification: Notification) {
        guard let win = notification.object as? NSWindow else { return }
        UserDefaults.standard.set(NSStringFromRect(win.frame), forKey: frameKey)
    }
}

