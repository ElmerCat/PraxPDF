//
//  WindowFrameAutosave.swift
//  PraxPDF - Prax=1219-7

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

struct WindowAutosaveAndRestore: NSViewRepresentable {
    let name: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.styleMask.insert(.resizable)
            window.setFrameAutosaveName(name)
            window.setFrameUsingName(name, force: true)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
