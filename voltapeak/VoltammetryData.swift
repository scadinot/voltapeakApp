//
//  VoltammetryData.swift
//  voltapeak
//
//  Created by Stéphane Cadinot on 09/05/2026.
//

import Foundation

/// Point de données d'un voltampérogramme (Potentiel, Courant)
struct VoltammetryPoint: Identifiable {
    let id = UUID()
    let potential: Double  // Potentiel en volts
    let current: Double    // Courant en ampères
}

/// Résultats de l'analyse d'un voltampérogramme SWV
struct VoltammetryAnalysis {
    let rawData: [VoltammetryPoint]
    let smoothedSignal: [Double]
    let baseline: [Double]
    let correctedSignal: [Double]
    let peakPotential: Double
    let peakCurrent: Double
    let fileName: String
}

/// Configuration de lecture de fichier SWV
struct SWVFileConfiguration {
    enum ColumnSeparator: String, CaseIterable {
        case tab = "\t"
        case comma = ","
        case semicolon = ";"
        case space = " "
        
        var displayName: String {
            switch self {
            case .tab: return "Tabulation"
            case .comma: return "Virgule"
            case .semicolon: return "Point-virgule"
            case .space: return "Espace"
            }
        }
    }
    
    enum DecimalSeparator: String, CaseIterable {
        case point = "."
        case comma = ","
        
        var displayName: String {
            switch self {
            case .point: return "Point"
            case .comma: return "Virgule"
            }
        }
    }
    
    var columnSeparator: ColumnSeparator = .tab
    var decimalSeparator: DecimalSeparator = .point
    var encoding: String.Encoding = .isoLatin1
}
