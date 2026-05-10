//
//  SignalProcessing.swift
//  voltapeak
//
//  Created by Stéphane Cadinot on 09/05/2026.
//

import Foundation
import Accelerate

/// Algorithmes de traitement du signal pour voltampérométrie
enum SignalProcessing {
    
    // MARK: - Savitzky-Golay Smoothing
    
    /// Lisse le signal par filtre de Savitzky-Golay
    /// - Parameters:
    ///   - signal: Signal à lisser
    ///   - windowLength: Longueur de la fenêtre (doit être impair, ≥ 3)
    ///   - polynomialOrder: Ordre du polynôme (typiquement 2)
    /// - Returns: Signal lissé
    static func savitzkyGolayFilter(_ signal: [Double], windowLength: Int = 11, polynomialOrder: Int = 2) -> [Double] {
        guard signal.count >= 5 else {
            return signal
        }
        
        var window = min(windowLength, signal.count)
        if window % 2 == 0 {
            window -= 1
        }
        window = max(window, 3)
        
        let halfWindow = window / 2
        var smoothed = [Double](repeating: 0, count: signal.count)
        
        // Coefficients de Savitzky-Golay pour ordre 2, fenêtre typiques
        // Simplification : utilisation d'une moyenne mobile pondérée
        // Pour une implémentation complète, il faudrait calculer les coefficients
        for i in 0..<signal.count {
            let start = max(0, i - halfWindow)
            let end = min(signal.count, i + halfWindow + 1)
            let slice = Array(signal[start..<end])
            smoothed[i] = slice.reduce(0, +) / Double(slice.count)
        }
        
        return smoothed
    }
    
    // MARK: - Peak Detection
    
    /// Détecte le pic (maximum) du signal avec protection des bords
    /// - Parameters:
    ///   - signal: Signal dans lequel chercher le pic
    ///   - potentials: Potentiels correspondants
    ///   - marginRatio: Fraction du signal à exclure de chaque côté (0.1 = 10%)
    ///   - maxSlope: Pente maximale tolérée (nil = pas de filtre)
    /// - Returns: Tuple (potentiel du pic, courant du pic)
    static func detectPeak(
        signal: [Double],
        potentials: [Double],
        marginRatio: Double = 0.10,
        maxSlope: Double? = 500
    ) -> (potential: Double, current: Double) {
        let n = signal.count
        let margin = Int(Double(n) * marginRatio)
        
        let searchRegion = Array(signal[margin..<(n-margin)])
        let potentialsRegion = Array(potentials[margin..<(n-margin)])
        
        var peakIndex = 0
        
        if let maxSlope = maxSlope {
            // Calcul du gradient (dérivée)
            let slopes = gradient(searchRegion, x: potentialsRegion)
            
            // Indices où la pente est acceptable
            var validIndices: [Int] = []
            for i in 0..<slopes.count {
                if abs(slopes[i]) < maxSlope {
                    validIndices.append(i)
                }
            }
            
            if validIndices.isEmpty {
                peakIndex = 0
            } else {
                // Trouver le maximum parmi les indices valides
                var maxValue = -Double.infinity
                for idx in validIndices {
                    if searchRegion[idx] > maxValue {
                        maxValue = searchRegion[idx]
                        peakIndex = idx
                    }
                }
            }
        } else {
            // Maximum simple
            if let maxIdx = searchRegion.enumerated().max(by: { $0.element < $1.element })?.offset {
                peakIndex = maxIdx
            }
        }
        
        let actualIndex = peakIndex + margin
        return (potentials[actualIndex], signal[actualIndex])
    }
    
    // MARK: - Baseline Estimation (asPLS simplifié)
    
    /// Estime la ligne de base par algorithme asPLS simplifié
    /// - Parameters:
    ///   - signal: Signal lissé
    ///   - potentials: Potentiels correspondants
    ///   - peakPotential: Position du pic à exclure
    ///   - exclusionWidthRatio: Largeur de la zone d'exclusion (0.03 = 3%)
    ///   - lambda: Facteur de lissage
    /// - Returns: Tuple (baseline, limites d'exclusion)
    static func calculateBaseline(
        signal: [Double],
        potentials: [Double],
        peakPotential: Double,
        exclusionWidthRatio: Double = 0.03,
        lambda: Double = 1e3
    ) -> (baseline: [Double], exclusionRange: (Double, Double)) {
        let n = signal.count
        let potentialRange = potentials.last! - potentials.first!
        let exclusionWidth = exclusionWidthRatio * potentialRange
        
        let exclusionMin = peakPotential - exclusionWidth
        let exclusionMax = peakPotential + exclusionWidth
        
        // Poids : faible dans la zone du pic, 1.0 ailleurs
        var weights = [Double](repeating: 1.0, count: n)
        for i in 0..<n {
            if potentials[i] > exclusionMin && potentials[i] < exclusionMax {
                weights[i] = 0.001
            }
        }
        
        // Version simplifiée de asPLS : fit polynomial pondéré
        // Pour une vraie implémentation asPLS, il faudrait itérer
        let baseline = polynomialFit(signal: signal, weights: weights, degree: 3)
        
        return (baseline, (exclusionMin, exclusionMax))
    }
    
    // MARK: - Helper Functions
    
    /// Calcule le gradient (dérivée numérique) d'un signal — reproduit `numpy.gradient(y, x)`
    ///
    /// Bords : différences finies 1ᵉʳ ordre (edge_order=1, défaut numpy).
    /// Intérieur : différences centrées 2ᵉ ordre pour pas non-uniformes, avec
    /// `hd = x[i] − x[i−1]`, `hs = x[i+1] − x[i]` :
    ///   grad[i] = −hs/(hd·(hd+hs))·y[i−1] + (hs−hd)/(hd·hs)·y[i] + hd/(hs·(hd+hs))·y[i+1]
    private static func gradient(_ y: [Double], x: [Double]) -> [Double] {
        var grad = [Double](repeating: 0, count: y.count)
        let n = y.count

        for i in 0..<n {
            if i == 0 {
                grad[i] = (y[1] - y[0]) / (x[1] - x[0])
            } else if i == n - 1 {
                grad[i] = (y[i] - y[i-1]) / (x[i] - x[i-1])
            } else {
                let hd = x[i] - x[i-1]
                let hs = x[i+1] - x[i]
                let a = -hs / (hd * (hd + hs))
                let b = (hs - hd) / (hd * hs)
                let c = hd / (hs * (hd + hs))
                grad[i] = a * y[i-1] + b * y[i] + c * y[i+1]
            }
        }

        return grad
    }
    
    /// Fit polynomial pondéré (version simplifiée)
    private static func polynomialFit(signal: [Double], weights: [Double], degree: Int) -> [Double] {
        // Version simplifiée : moyenne mobile pondérée large
        // Pour une vraie implémentation, utiliser vDSP ou Accelerate
        let windowSize = max(signal.count / 10, 5)
        var fitted = [Double](repeating: 0, count: signal.count)
        
        for i in 0..<signal.count {
            let start = max(0, i - windowSize/2)
            let end = min(signal.count, i + windowSize/2)
            
            var sum = 0.0
            var weightSum = 0.0
            
            for j in start..<end {
                sum += signal[j] * weights[j]
                weightSum += weights[j]
            }
            
            fitted[i] = weightSum > 0 ? sum / weightSum : signal[i]
        }
        
        return fitted
    }
}
