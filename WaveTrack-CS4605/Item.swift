//
//  Item.swift
//  WaveTrack-CS4605
//
//  Created by Minhnie on 2/19/25.
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
