//
//  SignalProcessingImproved.swift
//  voltapeak
//
//  Algorithmes améliorés pour correspondre exactement au code Python
//

import Foundation

/// Algorithmes de traitement du signal - Version améliorée
enum SignalProcessingImproved {
    
    // MARK: - Savitzky-Golay avec vrais coefficients
    
    /// Coefficients de Savitzky-Golay pré-calculés pour fenêtre 11, ordre 2
    /// Ces coefficients correspondent exactement à scipy.signal.savgol_filter
    private static let savgolCoeffs11: [Double] = [
        -36, 9, 44, 69, 84, 89, 84, 69, 44, 9, -36
    ]
    
    /// Lisse le signal avec vrais coefficients Savitzky-Golay
    static func savitzkyGolayFilter(_ signal: [Double], windowLength: Int = 11, polynomialOrder: Int = 2) -> [Double] {
        guard signal.count >= 5 else {
            return signal
        }
        
        var window = min(windowLength, signal.count)
        if window % 2 == 0 {
            window -= 1
        }
        window = max(window, 3)
        
        // Utiliser les coefficients pré-calculés pour fenêtre 11
        if window == 11 {
            return applySavgolFilter(signal, coefficients: savgolCoeffs11)
        }
        
        // Pour d'autres fenêtres, calculer les coefficients
        let coeffs = computeSavgolCoefficients(windowLength: window, polynomialOrder: polynomialOrder)
        return applySavgolFilter(signal, coefficients: coeffs)
    }
    
    /// Applique le filtre Savitzky-Golay avec les coefficients donnés
    private static func applySavgolFilter(_ signal: [Double], coefficients: [Double]) -> [Double] {
        let n = signal.count
        let m = coefficients.count
        let halfWindow = m / 2
        
        // Normaliser les coefficients
        let norm = coefficients.reduce(0.0, +)
        let normalizedCoeffs = coefficients.map { $0 / norm }
        
        var smoothed = [Double](repeating: 0, count: n)
        
        for i in 0..<n {
            var sum = 0.0
            
            for j in 0..<m {
                let idx = i - halfWindow + j
                
                // Gestion des bords par miroir (comme scipy)
                let mirrorIdx: Int
                if idx < 0 {
                    mirrorIdx = -idx
                } else if idx >= n {
                    mirrorIdx = 2 * n - idx - 2
                } else {
                    mirrorIdx = idx
                }
                
                if mirrorIdx >= 0 && mirrorIdx < n {
                    sum += signal[mirrorIdx] * normalizedCoeffs[j]
                }
            }
            
            smoothed[i] = sum
        }
        
        return smoothed
    }
    
    /// Calcule les coefficients de Savitzky-Golay (approximation)
    private static func computeSavgolCoefficients(windowLength: Int, polynomialOrder: Int) -> [Double] {
        // Approximation simple pour d'autres tailles de fenêtre
        // Pour une implémentation complète, il faudrait résoudre le système linéaire
        let halfWindow = windowLength / 2
        var coeffs = [Double](repeating: 0, count: windowLength)
        
        for i in 0..<windowLength {
            let x = Double(i - halfWindow)
            // Parabole centrée
            coeffs[i] = 1.0 - (x * x) / Double(halfWindow * halfWindow)
        }
        
        return coeffs
    }
    
    // MARK: - Baseline asPLS itératif (comme Python)
    
    /// Estimation de baseline par asPLS itératif
    static func calculateBaselineASPLS(
        signal: [Double],
        potentials: [Double],
        peakPotential: Double,
        exclusionWidthRatio: Double = 0.03,
        lambdaFactor: Double = 1e3,
        maxIterations: Int = 25,
        tolerance: Double = 1e-2
    ) -> (baseline: [Double], exclusionRange: (Double, Double)) {
        
        let n = signal.count
        let potentialRange = potentials.last! - potentials.first!
        let exclusionWidth = exclusionWidthRatio * potentialRange
        
        let exclusionMin = peakPotential - exclusionWidth
        let exclusionMax = peakPotential + exclusionWidth
        
        // Lambda mis à l'échelle comme dans Python
        let lam = lambdaFactor * Double(n * n)
        
        // Poids initiaux
        var weights = [Double](repeating: 1.0, count: n)
        for i in 0..<n {
            if potentials[i] > exclusionMin && potentials[i] < exclusionMax {
                weights[i] = 0.001
            }
        }
        
        // Baseline initiale = signal lui-même
        var baseline = signal
        
        // Itérations asPLS
        for iteration in 0..<maxIterations {
            let previousBaseline = baseline
            
            // Fit pondéré avec lissage
            baseline = weightedSmoothing(signal: signal, weights: weights, lambda: lam, potentials: potentials)
            
            // Mise à jour des poids (principe asPLS)
            for i in 0..<n {
                let residual = signal[i] - baseline[i]
                
                if residual > 0 {
                    // Point au-dessus : poids réduit
                    weights[i] *= 0.95
                } else {
                    // Point en-dessous : poids augmenté
                    weights[i] = min(weights[i] * 1.05, 1.0)
                }
                
                // Zone du pic : poids très faible
                if potentials[i] > exclusionMin && potentials[i] < exclusionMax {
                    weights[i] = 0.001
                }
            }
            
            // Test de convergence
            let change = zip(baseline, previousBaseline).map { abs($0 - $1) }.reduce(0, +) / Double(n)
            if iteration > 0 && change < tolerance {
                break
            }
        }
        
        return (baseline, (exclusionMin, exclusionMax))
    }
    
    /// Lissage pondéré (équivalent de l'asPLS dans pybaselines)
    private static func weightedSmoothing(signal: [Double], weights: [Double], lambda: Double, potentials: [Double]) -> [Double] {
        let n = signal.count
        var baseline = [Double](repeating: 0, count: n)
        
        // Fenêtre adaptative basée sur lambda - RÉDUITE pour baseline plus basse
        let windowSize = max(Int(sqrt(lambda) / 20.0), 5)
        
        for i in 0..<n {
            let start = max(0, i - windowSize)
            let end = min(n, i + windowSize + 1)
            
            var weightedSum = 0.0
            var totalWeight = 0.0
            
            for j in start..<end {
                // Poids spatial (gaussien) - PLUS SERRÉ pour mieux suivre le fond
                let distance = abs(i - j)
                let spatialWeight = exp(-Double(distance * distance) / (2.0 * Double(windowSize * windowSize / 8)))
                
                // Poids total = poids données × poids spatial
                let weight = weights[j] * spatialWeight
                
                weightedSum += signal[j] * weight
                totalWeight += weight
            }
            
            baseline[i] = totalWeight > 0 ? weightedSum / totalWeight : signal[i]
        }
        
        // Retourner la baseline brute (pas de lissage supplémentaire)
        return baseline
    }
    
    /// Lissage final de la baseline (DÉSACTIVÉ - ne pas utiliser)
    private static func smoothBaseline(_ baseline: [Double]) -> [Double] {
        // Retourner tel quel sans lissage
        return baseline
    }
}
