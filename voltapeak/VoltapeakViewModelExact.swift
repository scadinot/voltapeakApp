//
//  VoltapeakViewModelExact.swift
//  voltapeak
//
//  ViewModel utilisant les algorithmes EXACTS (scipy/pybaselines)
//

import Foundation
import Observation

/// ViewModel avec algorithmes exacts Python
@Observable
class VoltapeakViewModelExact {
    
    var config = SWVFileConfiguration()
    var currentAnalysis: VoltammetryAnalysis?
    var isProcessing = false
    var errorMessage: String?
    
    /// Analyse un fichier SWV avec algorithmes EXACTS
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
            print("🔄 Lissage Savitzky-Golay (coefficients EXACTS scipy)...")
            let smoothed = SavitzkyGolaySimple.filter(
                currents,
                windowLength: 11,
                polynomialOrder: 2
            )
            print("   Signal lissé min: \(smoothed.min() ?? 0) A, max: \(smoothed.max() ?? 0) A")
            
            // Étape 4 : Détection du pic brut (comme Python)
            let (peakPotential, peakCurrent) = SignalProcessing.detectPeak(
                signal: smoothed,
                potentials: potentials,
                marginRatio: 0.10,
                maxSlope: 500
            )
            print("🎯 Pic brut détecté : \(peakPotential) V, \(peakCurrent * 1e3) mA")
            
            // Étape 5 : Baseline asPLS EXACT (pybaselines.whittaker.aspls)
            print("📉 Calcul baseline asPLS (implémentation EXACTE pybaselines)...")
            
            // Préparer les poids avec zone d'exclusion (comme Python)
            let potentialRange = potentials.last! - potentials.first!
            let exclusionWidth = 0.03 * potentialRange
            let exclusionMin = peakPotential - exclusionWidth
            let exclusionMax = peakPotential + exclusionWidth
            
            var weights = [Double](repeating: 1.0, count: smoothed.count)
            for i in 0..<potentials.count {
                if potentials[i] > exclusionMin && potentials[i] < exclusionMax {
                    weights[i] = 0.001
                }
            }
            
            // Appel à asPLS EXACT
            let n = smoothed.count
            let lam = 1e3 * Double(n * n)  // Lambda mis à l'échelle comme Python
            
            let baseline = WhittakerASPLS.aspls(
                y: smoothed,
                lam: lam,
                p: 0.001,           // Paramètre asymétrie (par défaut pybaselines)
                diffOrder: 2,
                maxIter: 25,
                tol: 1e-2,
                weights: weights
            )
            
            print("   Baseline min: \(baseline.min() ?? 0) A, max: \(baseline.max() ?? 0) A")
            print("   Zone d'exclusion: [\(exclusionMin) V, \(exclusionMax) V]")
            
            // DEBUG: Comparer au pic
            if let peakIdx = potentials.firstIndex(where: { abs($0 - peakPotential) < 0.001 }) {
                print("   Au pic (\(peakPotential) V):")
                print("     Signal lissé: \(smoothed[peakIdx] * 1e3) mA")
                print("     Baseline: \(baseline[peakIdx] * 1e3) mA")
                print("     Différence: \((smoothed[peakIdx] - baseline[peakIdx]) * 1e3) mA")
            }
            
            // Étape 6 : Signal corrigé
            let corrected = zip(smoothed, baseline).map { $0 - $1 }
            print("✅ Signal corrigé")
            print("   Corrigé min: \(corrected.min() ?? 0) A, max: \(corrected.max() ?? 0) A")
            
            // Étape 7 : Détection du pic corrigé
            let (correctedPeakPotential, correctedPeakCurrent) = SignalProcessing.detectPeak(
                signal: corrected,
                potentials: potentials,
                marginRatio: 0.10,
                maxSlope: 500
            )
            print("🎯 Pic corrigé détecté : \(correctedPeakPotential) V, \(correctedPeakCurrent * 1e3) mA")
            print("   📊 Python attendu : -0.273 V, 6.93 mA")
            
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
