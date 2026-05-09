//
//  VoltageReading.swift
//  voltapeak
//
//  Created by Stéphane Cadinot on 09/05/2026.
//

import Foundation

/// Représente une lecture de voltage à un moment donné
struct VoltageReading: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let voltage: Double
    let current: Double?
    let power: Double?
    
    init(id: UUID = UUID(), timestamp: Date = Date(), voltage: Double, current: Double? = nil, power: Double? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.voltage = voltage
        self.current = current
        self.power = power
    }
    
    /// Calcule la puissance si le courant est disponible
    var calculatedPower: Double? {
        guard let current = current else { return power }
        return voltage * current
    }
}
