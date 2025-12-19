//
//  WindowFrameAutosave.swift
//  PraxPDF - Prax=1219-6

import SwiftUI
import AppKit

/// A tiny helper that installs an autosave name on the containing NSWindow so
/// AppKit persists and restores the window's size and position across launches.
struct WindowFrameAutosave: NSViewRepresentable {
    let name: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // Defer until the view is attached to a window
        DispatchQueue.main.async {
            if let window = view.window {
                window.setFrameAutosaveName(name)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // No-op
    }
}

