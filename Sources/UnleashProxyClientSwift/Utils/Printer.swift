//
//  File.swift
//  
//
//  Created by Daniel Chick on 11/2/22.
//

import Foundation

class Printer {
    private static let queue = DispatchQueue(label: "com.unleash.printer")
    private static var _showPrintStatements = false
    
    static var showPrintStatements: Bool {
        get {
            return queue.sync { _showPrintStatements }
        }
        set {
            queue.sync { _showPrintStatements = newValue }
        }
    }
    
    static func printMessage(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        if showPrintStatements {
            print(items, separator: separator, terminator: terminator)
        }
    }
}
