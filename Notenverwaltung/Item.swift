//
//  Item.swift
//  Notenverwaltung
//
//  Created by Stefan Venekamp on 08.03.26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
