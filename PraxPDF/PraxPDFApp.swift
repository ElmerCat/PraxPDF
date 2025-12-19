//
//  PraxPDFApp.swift
//  PraxPDF - Prax=1219-6
//
//  Created by Elmer Cat on 12/15/25.
//

import SwiftUI
import AppKit

@main
struct PraxPDFApp: App {
    @State private var previewModel = PreviewModel()
    @StateObject private var pdfPreviewModel = PDFPreviewModel()

    init() {
        // Prevent macOS from creating tabbed windows for this app
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        // Main single window
        Window("PraxPDF", id: "main") {
            ContentView(pdfPreviewModel: pdfPreviewModel)
        }
        .defaultPosition(.center)
        .defaultSize(width: 1100, height: 750)
        .windowResizability(.automatic)

        // Preview window (secondary)
        UtilityWindow("Preview", id: "preview") {
            VStack(spacing: 0) {
                WindowFrameAutosave(name: "PreviewWindowFrame")
                    .frame(width: 0, height: 0)
                ApplyAutosavedFrame(name: "PreviewWindowFrame")
                    .frame(width: 0, height: 0)
                PreviewWindowView(previewModel: pdfPreviewModel)
            }
        }
        .defaultPosition(.center)
        .defaultSize(width: 800, height: 1000)
        .windowResizability(.automatic)
    }
}

struct ApplyAutosavedFrame: NSViewRepresentable {
    let name: String
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            // Ensure window is resizable so AppKit can apply the saved size
            window.styleMask.insert(.resizable)
            // Apply the autosaved frame if present
            window.setFrameUsingName(name, force: true)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

