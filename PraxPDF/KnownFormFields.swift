//
//  KnownFormFields.swift
//  PraxPDF - Prax=1219-7
//

import Foundation

enum KnownFormFields {
    static let all: Set<String> = [
        "PcardHolderName", "DocumentNumber", "Date", "Amount",
        "Vendor", "GLAccount", "CostObject", "Description"
    ]
}
