//  PerPageTrimModel.swift
//  PraxPDF - Prax=1219-6

import Foundation
import CoreGraphics
import Combine

struct EdgeTrims: Codable, Hashable {
    var left: CGFloat
    var right: CGFloat
    var top: CGFloat
    var bottom: CGFloat

    static let zero = EdgeTrims(left: 0, right: 0, top: 0, bottom: 0)
}

final class PerPageTrimModel: ObservableObject {
    // Keyed by page index in the source PDF
    @Published var trims: [Int: EdgeTrims] = [:]

    func trims(for index: Int) -> EdgeTrims { trims[index] ?? .zero }
    func setTrims(_ value: EdgeTrims, for index: Int) { trims[index] = value }
}
