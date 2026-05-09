//
//  VoltageMonitor.swift
//  voltapeak
//
//  Created by Stéphane Cadinot on 09/05/2026.
//

import Foundation
import Observation

/// Gère la surveillance et l'enregistrement des lectures de voltage
@Observable
class VoltageMonitor {
    var readings: [VoltageReading] = []
    var isMonitoring: Bool = false
    var currentVoltage: Double = 0.0
    var peakVoltage: Double = 0.0
    var minimumVoltage: Double = Double.infinity
    
    private var monitoringTask: Task<Void, Never>?
    
    /// Démarre la surveillance du voltage
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        peakVoltage = 0.0
        minimumVoltage = Double.infinity
        
        monitoringTask = Task {
            while !Task.isCancelled && isMonitoring {
                await simulateReading()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
    
    /// Arrête la surveillance du voltage
    func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
    }
    
    /// Réinitialise toutes les données
    func reset() {
        stopMonitoring()
        readings.removeAll()
        currentVoltage = 0.0
        peakVoltage = 0.0
        minimumVoltage = Double.infinity
    }
    
    /// Simule une lecture de voltage (à remplacer par de vraies données)
    private func simulateReading() async {
        // Simulation - remplacez ceci par votre source de données réelle
        let voltage = Double.random(in: 3.0...5.0)
        let current = Double.random(in: 0.1...2.0)
        
        let reading = VoltageReading(
            voltage: voltage,
            current: current
        )
        
        await MainActor.run {
            self.readings.append(reading)
            self.currentVoltage = voltage
            
            if voltage > self.peakVoltage {
                self.peakVoltage = voltage
            }
            
            if voltage < self.minimumVoltage {
                self.minimumVoltage = voltage
            }
            
            // Garde seulement les 100 dernières lectures
            if self.readings.count > 100 {
                self.readings.removeFirst()
            }
        }
    }
    
    /// Exporte les données en CSV
    func exportToCSV() -> String {
        var csv = "Timestamp,Voltage,Current,Power\n"
        
        for reading in readings {
            let timestamp = ISO8601DateFormatter().string(from: reading.timestamp)
            let power = reading.calculatedPower ?? 0.0
            csv += "\(timestamp),\(reading.voltage),\(reading.current ?? 0.0),\(power)\n"
        }
        
        return csv
    }
}
