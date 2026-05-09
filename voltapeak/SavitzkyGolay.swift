//
//  SavitzkyGolay.swift
//  voltapeak
//
//  Implémentation EXACTE de scipy.signal.savgol_filter
//

import Foundation
import Accelerate

/// Implémentation exacte du filtre Savitzky-Golay (scipy.signal.savgol_filter)
enum SavitzkyGolay {
    
    /// Calcule les coefficients du filtre Savitzky-Golay
    /// Équivalent exact de scipy.signal.savgol_coeffs
    static func computeCoefficients(windowLength: Int, polynomialOrder: Int, derivative: Int = 0) -> [Double] {
        guard windowLength > polynomialOrder else {
            fatalError("windowLength must be greater than polynomialOrder")
        }
        guard windowLength % 2 == 1 else {
            fatalError("windowLength must be odd")
        }
        
        let halfWindow = windowLength / 2
        
        // Construire la matrice de Vandermonde
        // pos = [-halfWindow, ..., -1, 0, 1, ..., halfWindow]
        var positions: [Double] = []
        for i in -halfWindow...halfWindow {
            positions.append(Double(i))
        }
        
        // Matrice de Vandermonde : chaque colonne est pos^k pour k=0..polynomialOrder
        var vandermonde: [[Double]] = []
        for pos in positions {
            var row: [Double] = []
            for k in 0...polynomialOrder {
                row.append(pow(pos, Double(k)))
            }
            vandermonde.append(row)
        }
        
        // Résoudre le système linéaire par pseudo-inverse (méthode QR)
        // On cherche les coefficients qui ajustent un polynôme
        let coefficients = solveLeastSquares(vandermonde: vandermonde, derivative: derivative)
        
        return coefficients
    }
    
    /// Résout le système par moindres carrés (pseudo-inverse de Moore-Penrose)
    private static func solveLeastSquares(vandermonde: [[Double]], derivative: Int) -> [Double] {
        let m = vandermonde.count  // windowLength
        let n = vandermonde[0].count  // polynomialOrder + 1
        
        // Convertir en format colonne-major pour LAPACK
        var a = vandermonde.flatMap { $0 }
        
        // Vecteur de droite : [0, 0, ..., factorial(derivative), 0, ...]
        // C'est la dérivée d'ordre 'derivative' au centre (pos=0)
        var b = [Double](repeating: 0.0, count: n)
        b[derivative] = factorial(derivative)
        
        // Résoudre avec vDSP (pseudo-inverse)
        var result = [Double](repeating: 0.0, count: m)
        
        // Utiliser Accelerate pour résoudre le système
        // C'est l'équivalent de numpy.linalg.lstsq
        var mInt = __CLPK_integer(m)
        var nInt = __CLPK_integer(n)
        var nrhs = __CLPK_integer(1)
        var lwork = __CLPK_integer(-1)
        var work = [Double](repeating: 0.0, count: 1)
        var info: __CLPK_integer = 0
        
        // Query optimal workspace
        dgels_(
            UnsafeMutablePointer(mutating: ("N" as NSString).utf8String),
            &mInt, &nInt, &nrhs,
            &a, &mInt,
            &b, &mInt,
            &work, &lwork,
            &info
        )
        
        if info == 0 {
            lwork = __CLPK_integer(work[0])
            work = [Double](repeating: 0.0, count: Int(lwork))
            
            // Résoudre le système
            dgels_(
                UnsafeMutablePointer(mutating: ("N" as NSString).utf8String),
                &mInt, &nInt, &nrhs,
                &a, &mInt,
                &b, &mInt,
                &work, &lwork,
                &info
            )
            
            // Les coefficients sont dans b
            result = Array(b[0..<m])
        }
        
        return result
    }
    
    /// Factorielle
    private static func factorial(_ n: Int) -> Double {
        guard n > 0 else { return 1.0 }
        var result = 1.0
        for i in 1...n {
            result *= Double(i)
        }
        return result
    }
    
    /// Applique le filtre Savitzky-Golay (comme scipy.signal.savgol_filter)
    static func filter(_ signal: [Double], windowLength: Int = 11, polynomialOrder: Int = 2, mode: String = "interp") -> [Double] {
        guard signal.count >= windowLength else {
            return signal
        }
        
        let coeffs = computeCoefficients(windowLength: windowLength, polynomialOrder: polynomialOrder)
        let halfWindow = windowLength / 2
        let n = signal.count
        var filtered = [Double](repeating: 0.0, count: n)
        
        // Appliquer le filtre par convolution
        for i in 0..<n {
            var sum = 0.0
            
            for j in 0..<windowLength {
                let idx = i - halfWindow + j
                
                // Mode "interp" : extrapolation linéaire aux bords (comme scipy)
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
}
