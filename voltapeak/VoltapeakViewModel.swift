//
//  VoltapeakViewModel.swift
//  voltapeak
//
//  ViewModel avec implémentation EXACTE des algorithmes Python
//  - Savitzky-Golay : coefficients scipy exacts
//  - asPLS : pybaselines.whittaker.aspls (décomposition de Cholesky)
//

import Foundation
import Observation

/// ViewModel principal de l'application Voltapeak
/// Utilise les implémentations exactes de scipy et pybaselines
@Observable
class VoltapeakViewModel {
    
    var config = SWVFileConfiguration()
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
            
            // Étape 3 : Lissage Savitzky-Golay EXACT (scipy.signal.savgol_filter)
            let smoothed = SavitzkyGolay.filter(currents, windowLength: 11, polynomialOrder: 2)
            print("🔄 Signal lissé (Savitzky-Golay scipy)")
            print("   Courant lissé min: \(smoothed.min() ?? 0) A, max: \(smoothed.max() ?? 0) A")
            
            // Étape 4 : Détection du pic brut
            let (peakPotential, peakCurrent) = SignalProcessing.detectPeak(
                signal: smoothed,
                potentials: potentials,
                marginRatio: 0.10,
                maxSlope: 500
            )
            print("🎯 Pic brut détecté : \(peakPotential) V, \(peakCurrent * 1e3) mA")
            
            // Étape 5 : Baseline asPLS EXACT (pybaselines.whittaker.aspls)
            print("📉 Calcul baseline asPLS (implémentation EXACTE pybaselines)...")

            let n = smoothed.count
            // Paramètres Python : lambdaFactor=1e3, mis à l'échelle par n²
            let lambdaFactor = 1e3
            let lam = lambdaFactor * Double(n * n)

            // Zone d'exclusion autour du pic (ratio 3 % de l'étendue de potentiel)
            let exclusionWidthRatio = 0.03
            let potentialRange = potentials.last! - potentials.first!
            let exclusionWidth = exclusionWidthRatio * potentialRange
            let exclusionMin = peakPotential - exclusionWidth
            let exclusionMax = peakPotential + exclusionWidth

            // Poids initiaux : 1.0 partout sauf 0.001 dans la zone du pic
            var initialWeights = [Double](repeating: 1.0, count: n)
            for i in 0..<n {
                if potentials[i] > exclusionMin && potentials[i] < exclusionMax {
                    initialWeights[i] = 0.001
                }
            }

            print("   Paramètres: lam=\(lam) (= \(lambdaFactor) × n²), n=\(n), exclusion=[\(exclusionMin), \(exclusionMax)] V")

            let baseline = WhittakerASPLS.aspls(
                y: smoothed,
                lam: lam,
                diffOrder: 2,
                maxIter: 25,
                tol: 1e-2,
                weights: initialWeights
            )

            print("   Baseline min: \(baseline.min() ?? 0) A, max: \(baseline.max() ?? 0) A")
            
            // Étape 6 : Signal corrigé = lissé - baseline
            let corrected = zip(smoothed, baseline).map { $0 - $1 }
            print("✅ Signal corrigé")
            print("   Corrigé min: \(corrected.min() ?? 0) A, max: \(corrected.max() ?? 0) A")
            
            // Étape 7 : Détection du pic sur le signal corrigé
            let (correctedPeakPotential, correctedPeakCurrent) = SignalProcessing.detectPeak(
                signal: corrected,
                potentials: potentials,
                marginRatio: 0.10,
                maxSlope: 500
            )
            print("🎯 Pic corrigé détecté : \(correctedPeakPotential) V, \(correctedPeakCurrent * 1e3) mA")
            
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
