//
//  PraxPDFApp.swift
//  PraxPDF - Prax=1219-7
//
//  Created by Elmer Cat on 12/15/25.
//

import SwiftUI
import AppKit

@main
struct PraxPDFApp: App {
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
    }
}

