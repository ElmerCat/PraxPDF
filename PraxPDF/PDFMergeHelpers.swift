//
//  PDFMergeHelpers.swift
//  PraxPDF - Prax=1219-7
//

import Foundation
import UniformTypeIdentifiers
import CoreGraphics

func isPDF(_ url: URL) -> Bool {
    if let type = UTType(filenameExtension: url.pathExtension) {
        return type.conforms(to: .pdf)
    }
    return url.pathExtension.lowercased() == "pdf"
}

struct PDFGeometry {
    /// Compute the visible rect in page space given media box and trims.
    static func visibleRect(media: CGRect, trims: EdgeTrims, seamTop: CGFloat, seamBottom: CGFloat) -> CGRect {
        let minX = media.minX + trims.left
        let maxX = media.maxX - trims.right
        let minY = media.minY + trims.bottom + seamBottom
        let maxY = media.maxY - trims.top - seamTop
        let w = max(0, maxX - minX)
        let h = max(0, maxY - minY)
        return CGRect(x: minX, y: minY, width: w, height: h)
    }
}

extension PDFGeometry {
    /// Computes the final canvas size for the merged PDF using the same rules as the merge routine.
    static func canvasSize(for pageRects: [CGRect], trims: [Int: EdgeTrims], trimTop: CGFloat, trimBottom: CGFloat, interPageGap: CGFloat) -> CGSize {
        var maxVisibleWidth: CGFloat = 0
        var totalVisibleHeight: CGFloat = 0
        let count = pageRects.count
        for i in 0..<count {
            let per = trims[i] ?? .zero
            let seamTop: CGFloat = (i == 0) ? 0 : trimTop
            let seamBottom: CGFloat = (i == count - 1) ? 0 : trimBottom
            let vis = visibleRect(media: pageRects[i], trims: per, seamTop: seamTop, seamBottom: seamBottom)
            maxVisibleWidth = max(maxVisibleWidth, vis.width)
            totalVisibleHeight += vis.height
        }
        let internalSeams = max(0, count - 1)
        let gapsTotal = interPageGap * CGFloat(internalSeams)
        return CGSize(width: maxVisibleWidth, height: totalVisibleHeight + gapsTotal)
    }
}
