import SwiftUI
import AppKit

/// A SwiftUI view modifier that sets an autosave name on the containing NSWindow.
/// This enables AppKit to persist the window's frame automatically.
struct WindowAutosaveName: ViewModifier {
    let autosaveName: String

    func body(content: Content) -> some View {
        content
            .background(
                WindowAccessor { window in
                    window?.setFrameAutosaveName(autosaveName)
                }
            )
    }
}

/// A helper view to access the containing NSWindow of a SwiftUI view.
private struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow?) -> ()

    func makeNSView(context: Context) -> NSView {
        let nsView = NSView()
        DispatchQueue.main.async {
            self.callback(nsView.window)
        }
        return nsView
    }

    func updateNSView(_ nsView: NSView, context: Context) { }
}

public extension View {
    /// Sets the autosave name for the containing NSWindow to enable automatic frame persistence.
    /// - Parameter name: The autosave name used by AppKit to save and restore the window frame.
    /// - Returns: A view that sets the autosave name on its containing NSWindow.
    func windowAutosaveName(_ name: String) -> some View {
        self.modifier(WindowAutosaveName(autosaveName: name))
    }
}
