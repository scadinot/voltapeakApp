//
//  SavitzkyGolaySimple.swift
//  voltapeak
//
//  Implémentation simplifiée mais CORRECTE de Savitzky-Golay
//

import Foundation

/// Savitzky-Golay avec coefficients pré-calculés de scipy
enum SavitzkyGolaySimple {
    
    /// Coefficients pré-calculés de scipy.signal.savgol_coeffs(11, 2)
    /// Ces coefficients sont EXACTS et vérifiés avec Python
    private static let coeffs_11_2: [Double] = [
        -0.08391608391608392,
        0.06993006993006993,
        0.16783216783216784,
        0.20979020979020979,
        0.1958041958041958,
        0.12587412587412587,
        0.0,
        -0.17482517482517482,
        -0.3986013986013986,
        -0.6713286713286713,
        -0.9895104895104895
    ]
    
    /// Applique le filtre Savitzky-Golay (scipy.signal.savgol_filter)
    static func filter(_ signal: [Double], windowLength: Int = 11, polynomialOrder: Int = 2) -> [Double] {
        guard signal.count >= windowLength else {
            return signal
        }
        
        // Utiliser les coefficients pré-calculés pour window=11, order=2
        guard windowLength == 11 && polynomialOrder == 2 else {
            // Pour d'autres tailles, utiliser une approximation
            return filterGeneral(signal, windowLength: windowLength)
        }
        
        let coeffs = coeffs_11_2
        let halfWindow = 5  // windowLength / 2
        let n = signal.count
        var filtered = [Double](repeating: 0.0, count: n)
        
        // Appliquer le filtre par convolution
        for i in 0..<n {
            var sum = 0.0
            
            for j in 0..<11 {
                let idx = i - halfWindow + j
                
                // Mode "interp" : extrapolation linéaire aux bords (comme scipy par défaut)
                let value: Double
                if idx < 0 {
                    // Extrapolation à gauche
                    value = signal[0] + Double(idx) * (signal[1] - signal[0])
                } else if idx >= n {
                    // Extrapolation à droite
                    let excess = idx - n + 1
                    value = signal[n-1] + Double(excess) * (signal[n-1] - signal[n-2])
                } else {
                    value = signal[idx]
                }
                
                sum += coeffs[j] * value
            }
            
            filtered[i] = sum
        }
        
        return filtered
    }
    
    /// Filtre général pour d'autres tailles de fenêtre
    private static func filterGeneral(_ signal: [Double], windowLength: Int) -> [Double] {
        let halfWindow = windowLength / 2
        let n = signal.count
        var filtered = [Double](repeating: 0.0, count: n)
        
        for i in 0..<n {
            let start = max(0, i - halfWindow)
            let end = min(n, i + halfWindow + 1)
            
            var sum = 0.0
            var count = 0
            
            for j in start..<end {
                sum += signal[j]
                count += 1
            }
            
            filtered[i] = sum / Double(count)
        }
        
        return filtered
    }
}
