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
            
            // Étape 2 : Traitement des données (tri, inversion)
            let (potentials, currents) = SWVFileReader.processData(rawPoints)
            
            // Étape 3 : Lissage Savitzky-Golay
            let smoothed = SignalProcessing.savitzkyGolayFilter(currents, windowLength: 11, polynomialOrder: 2)
            
            // Étape 4 : Détection du pic brut
            let (peakPotential, _) = SignalProcessing.detectPeak(
                signal: smoothed,
                potentials: potentials,
                marginRatio: 0.10,
                maxSlope: 500
            )
            
            // Étape 5 : Estimation de la baseline (asPLS)
            let (baseline, _) = SignalProcessing.calculateBaseline(
                signal: smoothed,
                potentials: potentials,
                peakPotential: peakPotential,
                exclusionWidthRatio: 0.03,
                lambda: 1e3
            )
            
            // Étape 6 : Signal corrigé = lissé - baseline
            let corrected = zip(smoothed, baseline).map { $0 - $1 }
            
            // Étape 7 : Détection du pic sur le signal corrigé
            let (correctedPeakPotential, correctedPeakCurrent) = SignalProcessing.detectPeak(
                signal: corrected,
                potentials: potentials,
                marginRatio: 0.10,
                maxSlope: 500
            )
            
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
