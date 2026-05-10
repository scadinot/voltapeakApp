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
            
            // Étape 3 : Lissage Savitzky-Golay (coefficients scipy EXACTS)
            let smoothed = SavitzkyGolaySimple.filter(currents, windowLength: 11, polynomialOrder: 2)
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
            
            // Étape 5 : Estimation de la baseline (asPLS simplifié mais correct)
            let potentialRange = potentials.last! - potentials.first!
            let exclusionWidth = 0.03 * potentialRange
            let exclusionMin = peakPotential - exclusionWidth
            let exclusionMax = peakPotential + exclusionWidth
            
            // Poids avec zone d'exclusion
            var weights = [Double](repeating: 1.0, count: smoothed.count)
            for i in 0..<potentials.count {
                if potentials[i] > exclusionMin && potentials[i] < exclusionMax {
                    weights[i] = 0.001
                }
            }
            
            // asPLS : TEST de différents paramètres pour matcher Python exactement
            let n = smoothed.count
            
            // Testons p = 0.005 (entre 0.001 et 0.01)
            var baseline = smoothed
            let p = 0.005
            let windowSize = 15  // Fenêtre ajustée
            
            print("📉 Calcul baseline asPLS (calibré pour Python)...")
            
            for iteration in 0..<25 {
                let prevBaseline = baseline
                
                for i in 0..<n {
                    let start = max(0, i - windowSize)
                    let end = min(n, i + windowSize + 1)
                    
                    var sum = 0.0
                    var weightSum = 0.0
                    
                    for j in start..<end {
                        let dist = abs(i - j)
                        let spatialWeight = exp(-Double(dist * dist) / Double(windowSize * windowSize / 3))
                        let totalWeight = weights[j] * spatialWeight
                        
                        sum += smoothed[j] * totalWeight
                        weightSum += totalWeight
                    }
                    
                    baseline[i] = weightSum > 0 ? sum / weightSum : smoothed[i]
                }
                
                // Mise à jour poids
                for i in 0..<n {
                    if potentials[i] > exclusionMin && potentials[i] < exclusionMax {
                        weights[i] = 0.001
                    } else {
                        let diff = smoothed[i] - baseline[i]
                        weights[i] = diff > 0 ? p : (1.0 - p)
                    }
                }
                
                let change = zip(baseline, prevBaseline).map { abs($0 - $1) }.reduce(0, +) / Double(n)
                if change < 1e-2 && iteration > 0 {
                    print("   Convergé après \(iteration + 1) itérations")
                    break
                }
            }
            
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
