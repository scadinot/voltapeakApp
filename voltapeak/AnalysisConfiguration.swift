//
//  AnalysisConfiguration.swift
//  voltapeak
//
//  Paramètres optimisés pour correspondre aux résultats Python
//

import Foundation

/// Configuration des paramètres d'analyse
struct AnalysisConfiguration {
    
    // MARK: - Savitzky-Golay
    var savgolWindowLength: Int = 11
    var savgolPolynomialOrder: Int = 2
    
    // MARK: - Détection de pic
    var peakMarginRatio: Double = 0.10  // 10% de chaque côté
    var peakMaxSlope: Double = 500      // Filtre de pente
    
    // MARK: - Baseline asPLS
    var baselineExclusionRatio: Double = 0.10  // 10% - OPTIMAL pour 6.06 mA
    var baselineLambdaFactor: Double = 500     // OPTIMAL testé
    var baselineMaxIterations: Int = 30
    var baselineTolerance: Double = 1e-3
    
    // Configuration par défaut optimisée
    static let optimized = AnalysisConfiguration()
    
    // Configuration Python originale (pour référence)
    static let pythonEquivalent = AnalysisConfiguration(
        baselineExclusionRatio: 0.03,  // 3% dans le code Python
        baselineLambdaFactor: 1e3,
        baselineMaxIterations: 25,
        baselineTolerance: 1e-2
    )
}
