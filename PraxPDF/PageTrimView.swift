//  PageTrimView.swift
//  PraxPDF - Prax=1219-6

import SwiftUI
import PDFKit
import AppKit

struct PageTrimView: View {
    let url: URL
    @ObservedObject var model: PerPageTrimModel

    @State private var pdfDocument: PDFDocument?
    @State private var currentIndex: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(url.lastPathComponent).font(.headline)
                Spacer()
                Text("Page \(currentIndex + 1) of \(pdfDocument?.pageCount ?? 0)")
            }.padding(8)

            HStack(spacing: 0) {
                PDFPageListView(document: pdfDocument, selectedIndex: $currentIndex)
                    .frame(width: 180)
                    .background(.quaternary)
                Divider()
                if let doc = pdfDocument, let page = doc.page(at: currentIndex) {
                    CropOverlayPDFView(page: page, trims: Binding(get: { model.trims(for: currentIndex) }, set: { model.setTrims($0, for: currentIndex) }))
                        .background(Color(nsColor: .windowBackgroundColor))
                } else {
                    ContentUnavailableView("No page", systemImage: "doc")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            _ = url.startAccessingSecurityScopedResource()
            self.pdfDocument = PDFDocument(url: url)
            if (self.pdfDocument?.pageCount ?? 0) > 0 { self.currentIndex = 0 }
        }
        .onDisappear {
            url.stopAccessingSecurityScopedResource()
        }
    }
}

private struct PDFPageListView: View {
    let document: PDFDocument?
    @Binding var selectedIndex: Int

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                if let doc = document {
                    ForEach(0..<(doc.pageCount), id: \.self) { i in
                        Button(action: { selectedIndex = i }) {
                            HStack(alignment: .top, spacing: 8) {
                                if let thumb = doc.page(at: i)?.thumbnail(of: NSSize(width: 120, height: 160), for: .mediaBox) {
                                    Image(nsImage: thumb)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 120)
                                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(selectedIndex == i ? Color.accentColor : .clear, lineWidth: 3))
                                }
                                Text("Page \(i + 1)")
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }.padding(8)
        }
    }
}

// A PDFKit-backed view that shows a single page and lets the user drag a rectangle to set trims.
struct CropOverlayPDFView: NSViewRepresentable {
    let page: PDFPage
    @Binding var trims: EdgeTrims

    func makeNSView(context: Context) -> CropOverlayPDFNSView {
        let v = CropOverlayPDFNSView()
        v.configure(page: page, trims: trims)
        v.onTrimsChanged = { self.trims = $0 }
        return v
    }

    func updateNSView(_ nsView: CropOverlayPDFNSView, context: Context) {
        nsView.configure(page: page, trims: trims)
    }
}

final class CropOverlayPDFNSView: NSView {
    private let pdfView = PDFView()
    private let overlay = OverlayView()
    private var page: PDFPage?
    var onTrimsChanged: ((EdgeTrims) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        pdfView.autoScales = true
        addSubview(pdfView)
        addSubview(overlay)
        overlay.isHidden = false
        overlay.wantsLayer = true
        overlay.onFinish = { [weak self] rectInView in
            guard let self, let page = self.page else { return }
            // Clamp rect to page bounds in view coordinates
            let pageBoundsInView = self.pageBoundsInView()
            let clamped = rectInView.intersection(pageBoundsInView)
            guard !clamped.isEmpty else { return }
            // Convert to page space and compute trims
            let pageRect = self.pdfView.convert(clamped, to: page)
            let media = page.bounds(for: .mediaBox)
            let left = max(0, pageRect.minX - media.minX)
            let right = max(0, media.maxX - pageRect.maxX)
            let bottom = max(0, pageRect.minY - media.minY)
            let top = max(0, media.maxY - pageRect.maxY)
            let trims = EdgeTrims(left: left, right: right, top: top, bottom: bottom)
            self.overlay.currentRect = clamped
            self.onTrimsChanged?(trims)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        pdfView.frame = bounds
        overlay.frame = bounds
        overlay.needsDisplay = true
    }

    func configure(page: PDFPage, trims: EdgeTrims) {
        if self.page !== page {
            let doc = PDFDocument()
            doc.insert(page, at: 0)
            pdfView.document = doc
            pdfView.go(to: page)
            self.page = page
        }
        // Draw existing trims as a selection rectangle
        if let page = self.page {
            let media = page.bounds(for: .mediaBox)
            let visible = CGRect(x: media.minX + trims.left,
                                 y: media.minY + trims.bottom,
                                 width: media.width - trims.left - trims.right,
                                 height: media.height - trims.top - trims.bottom)
            let rInView = pdfView.convert(visible, from: page)
            overlay.currentRect = rInView
            overlay.needsDisplay = true
        }
    }

    private func pageBoundsInView() -> CGRect {
        guard let page else { return .zero }
        let media = page.bounds(for: .mediaBox)
        return pdfView.convert(media, from: page)
    }

    // Transparent overlay that captures mouse and draws the selection rectangle
    private final class OverlayView: NSView {
        var onFinish: ((CGRect) -> Void)?
        var currentRect: CGRect? { didSet { needsDisplay = true } }
        private var dragStart: CGPoint?

        override var acceptsFirstResponder: Bool { true }
        override func hitTest(_ point: NSPoint) -> NSView? { return self } // capture events over pdfView

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            guard let r = currentRect else { return }
            NSColor.systemBlue.setStroke()
            let path = NSBezierPath(rect: r)
            path.lineWidth = 2
            path.stroke()
            NSColor.systemBlue.withAlphaComponent(0.15).setFill()
            r.fill()
        }

        override func mouseDown(with event: NSEvent) {
            dragStart = convert(event.locationInWindow, from: nil)
            currentRect = CGRect(origin: dragStart!, size: .zero)
        }

        override func mouseDragged(with event: NSEvent) {
            guard let start = dragStart else { return }
            let cur = convert(event.locationInWindow, from: nil)
            currentRect = CGRect(x: min(start.x, cur.x),
                                 y: min(start.y, cur.y),
                                 width: abs(cur.x - start.x),
                                 height: abs(cur.y - start.y))
        }

        override func mouseUp(with event: NSEvent) {
            guard let rect = currentRect else { return }
            onFinish?(rect)
        }
    }
}

