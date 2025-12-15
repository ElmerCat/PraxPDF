import Observation
import Foundation

/// An observable model used to share the selected URL and visibility state across windows.
@Observable
public final class PreviewModel {
    /// The currently selected URL.
    public var selectedURL: URL?
    
    /// A Boolean value indicating whether the preview is visible.
    public var isVisible: Bool = false
    
    /// Creates a new instance of `PreviewModel`.
    public init() {}
}
