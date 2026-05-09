//
//  VoltapeakViewModel.swift
//  voltapeak
//
//  Created by Stéphane Cadinot on 09/05/2026.
//

import Foundation
import Observation

/// ViewModel principal de l'application Voltapeak
@Observable
class VoltapeakViewModel {
    
    var config = SWVFileConfiguration()
    var analysisConfig = AnalysisConfiguration.optimized  // Configuration optimisée
    var currentAnalysis: VoltammetryAnalysis?
    var isProcessing = false
    var errorMessage: String?
    
    /// Analyse un fichier SWV complet
    /// - Parameter url: URL du fichier à analyser
    func analyzeFile(at url: URL) async {
        await MainActor.run {
            isProcessing = true
            errorMessage = nil
        }
        
        do {
            // Étape 1 : Lecture du fichier
            let rawPoints = try SWVFileReader.readFile(at: url, config: config)
            print("📖 Fichier lu : \(rawPoints.count) points")
            
            // Étape 2 : Traitement des données (tri, inversion)
            let (potentials, currents) = SWVFileReader.processData(rawPoints)
            print("📊 Données traitées")
            print("   Potentiel min: \(potentials.first ?? 0) V, max: \(potentials.last ?? 0) V")
            print("   Courant min: \(currents.min() ?? 0) A, max: \(currents.max() ?? 0) A")
            
            // Étape 3 : Lissage Savitzky-Golay AMÉLIORÉ
            let smoothed = SignalProcessingImproved.savitzkyGolayFilter(
                currents,
                windowLength: analysisConfig.savgolWindowLength,
                polynomialOrder: analysisConfig.savgolPolynomialOrder
            )
            print("🔄 Signal lissé")
            print("   Courant lissé min: \(smoothed.min() ?? 0) A, max: \(smoothed.max() ?? 0) A")
            
            // Étape 4 : Détection du pic brut
            let (peakPotential, peakCurrent) = SignalProcessing.detectPeak(
                signal: smoothed,
                potentials: potentials,
                marginRatio: analysisConfig.peakMarginRatio,
                maxSlope: analysisConfig.peakMaxSlope
            )
            print("🎯 Pic brut détecté : \(peakPotential) V, \(peakCurrent * 1e3) mA")
            
            // Étape 5 : Estimation de la baseline (asPLS AMÉLIORÉ avec config optimisée)
            let (baseline, exclusionRange) = SignalProcessingImproved.calculateBaselineASPLS(
                signal: smoothed,
                potentials: potentials,
                peakPotential: peakPotential,
                exclusionWidthRatio: analysisConfig.baselineExclusionRatio,
                lambdaFactor: analysisConfig.baselineLambdaFactor,
                maxIterations: analysisConfig.baselineMaxIterations,
                tolerance: analysisConfig.baselineTolerance
            )
            print("📉 Baseline estimée (lambda=\(analysisConfig.baselineLambdaFactor), exclusion=\(analysisConfig.baselineExclusionRatio*100)%)")
            print("   Baseline min: \(baseline.min() ?? 0) A, max: \(baseline.max() ?? 0) A")
            print("   Zone d'exclusion: [\(exclusionRange.0) V, \(exclusionRange.1) V]")
            
            // DEBUG: Comparer au niveau du pic
            if let peakIdx = potentials.firstIndex(where: { abs($0 - peakPotential) < 0.001 }) {
                print("   Au pic (\(peakPotential) V):")
                print("     Signal lissé: \(smoothed[peakIdx] * 1e3) mA")
                print("     Baseline: \(baseline[peakIdx] * 1e3) mA")
                print("     Différence: \((smoothed[peakIdx] - baseline[peakIdx]) * 1e3) mA")
            }
            
            // Étape 6 : Signal corrigé = lissé - baseline
            let corrected = zip(smoothed, baseline).map { $0 - $1 }
            print("✅ Signal corrigé")
            print("   Corrigé min: \(corrected.min() ?? 0) A, max: \(corrected.max() ?? 0) A")
            
            // Étape 7 : Détection du pic sur le signal corrigé
            let (correctedPeakPotential, correctedPeakCurrent) = SignalProcessing.detectPeak(
                signal: corrected,
                potentials: potentials,
                marginRatio: analysisConfig.peakMarginRatio,
                maxSlope: analysisConfig.peakMaxSlope
            )
            print("🎯 Pic corrigé détecté : \(correctedPeakPotential) V, \(correctedPeakCurrent * 1e3) mA")
            print("   📊 Comparaison avec Python : attendu ~6.93 mA")
            
            // Création du résultat d'analyse
            let analysis = VoltammetryAnalysis(
                rawData: rawPoints,
                smoothedSignal: smoothed,
                baseline: baseline,
                correctedSignal: corrected,
                peakPotential: correctedPeakPotential,
                peakCurrent: correctedPeakCurrent,
                fileName: url.lastPathComponent
            )
            
            await MainActor.run {
                self.currentAnalysis = analysis
                self.isProcessing = false
            }
            
        } catch {
            print("❌ Erreur : \(error)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isProcessing = false
            }
        }
    }
    
    /// Exporte les résultats au format CSV
    /// - Returns: Contenu CSV
    func exportToCSV() -> String? {
        guard let analysis = currentAnalysis else { return nil }
        
        var csv = "Potentiel (V),Courant brut (A),Signal lissé (A),Baseline (A),Signal corrigé (A)\n"
        
        let (potentials, rawCurrents) = SWVFileReader.processData(analysis.rawData)
        
        for i in 0..<potentials.count {
            csv += String(format: "%.6f,%.9f,%.9f,%.9f,%.9f\n",
                         potentials[i],
                         rawCurrents[i],
                         analysis.smoothedSignal[i],
                         analysis.baseline[i],
                         analysis.correctedSignal[i])
        }
        
        return csv
    }
    
    /// Réinitialise l'analyse
    func reset() {
        currentAnalysis = nil
        errorMessage = nil
    }
}
