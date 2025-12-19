//
//  SavePanelRepresentable.swift
//  PraxPDF - Prax=1219-7

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SavePanelRepresentable: NSViewControllerRepresentable {
    typealias NSViewControllerType = NSViewController

    let suggestedURL: URL
    let onCompletion: (URL?) -> Void

    func makeNSViewController(context: Context) -> NSViewController {
        let controller = NSViewController()
        DispatchQueue.main.async {
            presentSavePanel(from: controller.view.window)
        }
        return controller
    }

    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {
        // no-op
    }

    private func presentSavePanel(from window: NSWindow?) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.allowsOtherFileTypes = false
        panel.allowedContentTypes = [.pdf]
        panel.level = .modalPanel

        // Pre-fill name and directory from suggestedURL
        panel.directoryURL = suggestedURL.deletingLastPathComponent()
        panel.nameFieldStringValue = suggestedURL.lastPathComponent

        let completion: (NSApplication.ModalResponse) -> Void = { response in
            if response == .OK {
                onCompletion(panel.url)
            } else {
                onCompletion(nil)
            }
        }

        if let window {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            // Fallback if no window is available
            completion(panel.runModal())
        }
    }
}
