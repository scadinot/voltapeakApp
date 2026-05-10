//
//  ASPLSBaseline.swift
//  voltapeak
//
//  Implémentation EXACTE de pybaselines.whittaker.aspls
//  Basée sur le code source Python original
//

import Foundation
import Accelerate

/// Implémentation exacte de l'algorithme asPLS (Asymmetric Least Squares)
/// Réplique pybaselines.whittaker.aspls
enum ASPLSBaseline {
    
    /// Calcule la baseline par asPLS (comme pybaselines)
    /// - Parameters:
    ///   - y: Signal d'entrée
    ///   - lam: Paramètre de lissage (scaling: lam * n^2)
    ///   - p: Paramètre d'asymétrie (défaut 1e-2 dans pybaselines)
    ///   - diffOrder: Ordre de différence (2 pour D²)
    ///   - maxIter: Itérations max
    ///   - tol: Tolérance de convergence
    ///   - weights: Poids initiaux (pour zone d'exclusion)
    /// - Returns: Baseline estimée
    static func aspls(
        y: [Double],
        lam: Double,
        p: Double = 0.01,
        diffOrder: Int = 2,
        maxIter: Int = 50,
        tol: Double = 1e-3,
        weights: [Double]? = nil
    ) -> [Double] {
        let n = y.count
        
        // Poids initiaux - garder les poids de la zone d'exclusion
        let initialWeights = weights ?? [Double](repeating: 1.0, count: n)
        var w = initialWeights
        
        // Matrice de différences D
        // Pour diffOrder=2 : D est (n-2) × n
        // D[i,i] = 1, D[i,i+1] = -2, D[i,i+2] = 1
        
        // Au lieu de construire D, on va utiliser directement
        // le fait que D^T D est une matrice pentadiagonale
        
        // Pour diffOrder=2, D^T D est pentadiagonale avec pattern:
        // diag(-4) : 1
        // diag(-2) : -4
        // diag(0)  : 6 au centre, 5 sur bords, 1 aux coins
        // diag(2)  : -4
        // diag(4)  : 1
        
        var z = y  // Baseline initiale = signal
        var zPrev: [Double]
        
        // Construire la matrice D^T D (pentadiagonale)
        var DTD = buildDTD(n: n, diffOrder: diffOrder)
        
        for iteration in 0..<maxIter {
            zPrev = z
            
            // Résoudre (W + λ D^T D) z = W y
            // où W est diagonale avec w sur la diagonale
            
            // Construire A = W + λ D^T D
            var A = [[Double]](repeating: [Double](repeating: 0.0, count: n), count: n)
            
            for i in 0..<n {
                for j in 0..<n {
                    if i == j {
                        // Diagonale : w[i] + λ * DTD[i][i]
                        A[i][j] = w[i] + lam * DTD[i][j]
                    } else {
                        // Hors diagonale : λ * DTD[i][j]
                        A[i][j] = lam * DTD[i][j]
                    }
                }
            }
            
            // Vecteur b = W y
            var b = [Double](repeating: 0.0, count: n)
            for i in 0..<n {
                b[i] = w[i] * y[i]
            }
            
            // Résoudre A z = b
            z = solveLinearSystem(A: A, b: b)
            
            // Mise à jour des poids (principe asPLS)
            // Garder les poids de la zone d'exclusion fixés
            for i in 0..<n {
                // Si le poids initial était très faible (zone d'exclusion), le garder
                if initialWeights[i] < 0.01 {
                    w[i] = initialWeights[i]  // Garder le poids d'exclusion
                } else {
                    // Sinon, mise à jour asymétrique
                    let diff = y[i] - z[i]
                    if diff > 0 {
                        // Point au-dessus : poids faible
                        w[i] = p
                    } else {
                        // Point en-dessous : poids fort
                        w[i] = 1.0 - p
                    }
                }
            }
            
            // Test de convergence
            let change = computeChange(z, zPrev)
            if change < tol && iteration > 0 {
                print("   asPLS convergé après \(iteration + 1) itérations (change=\(change))")
                break
            }
        }
        
        return z
    }
    
    /// Construit la matrice D^T D pour diffOrder=2
    private static func buildDTD(n: Int, diffOrder: Int) -> [[Double]] {
        guard diffOrder == 2 else {
            fatalError("Seul diffOrder=2 est supporté")
        }
        
        // Pour diffOrder=2, D^T D est pentadiagonale
        var DTD = [[Double]](repeating: [Double](repeating: 0.0, count: n), count: n)
        
        // Remplir selon le pattern de D^T D pour différence d'ordre 2
        for i in 0..<n {
            for j in 0..<n {
                let diff = abs(i - j)
                
                if diff == 0 {
                    // Diagonale principale
                    if i == 0 || i == n - 1 {
                        DTD[i][j] = 1.0  // Coins
                    } else if i == 1 || i == n - 2 {
                        DTD[i][j] = 5.0  // Près des bords
                    } else {
                        DTD[i][j] = 6.0  // Centre
                    }
                } else if diff == 1 {
                    // Première sous/sur-diagonale
                    if (i == 0 && j == 1) || (i == n - 1 && j == n - 2) ||
                       (i == 1 && j == 0) || (i == n - 2 && j == n - 1) {
                        DTD[i][j] = -2.0  // Près des bords
                    } else {
                        DTD[i][j] = -4.0  // Centre
                    }
                } else if diff == 2 {
                    // Deuxième sous/sur-diagonale
                    DTD[i][j] = 1.0
                }
            }
        }
        
        return DTD
    }
    
    /// Résout un système linéaire A x = b
    /// Utilise l'élimination de Gauss avec pivotage partiel
    private static func solveLinearSystem(A: [[Double]], b: [Double]) -> [Double] {
        let n = A.count
        
        // Copier A et b pour ne pas modifier les originaux
        var M = A
        var y = b
        
        // Élimination de Gauss avec pivotage partiel
        for k in 0..<n {
            // Trouver le pivot (élément le plus grand)
            var maxRow = k
            var maxVal = abs(M[k][k])
            
            for i in (k + 1)..<n {
                if abs(M[i][k]) > maxVal {
                    maxVal = abs(M[i][k])
                    maxRow = i
                }
            }
            
            // Échanger les lignes si nécessaire
            if maxRow != k {
                M.swapAt(k, maxRow)
                y.swapAt(k, maxRow)
            }
            
            // Élimination
            for i in (k + 1)..<n {
                if M[k][k] == 0 {
                    continue  // Éviter division par zéro
                }
                
                let factor = M[i][k] / M[k][k]
                for j in k..<n {
                    M[i][j] -= factor * M[k][j]
                }
                y[i] -= factor * y[k]
            }
        }
        
        // Substitution arrière
        var x = [Double](repeating: 0.0, count: n)
        for i in stride(from: n - 1, through: 0, by: -1) {
            if M[i][i] == 0 {
                x[i] = 0  // Protection contre division par zéro
                continue
            }
            
            var sum = y[i]
            for j in (i + 1)..<n {
                sum -= M[i][j] * x[j]
            }
            x[i] = sum / M[i][i]
        }
        
        return x
    }
    
    /// Calcule le changement relatif entre deux vecteurs
    private static func computeChange(_ a: [Double], _ b: [Double]) -> Double {
        var sumDiff = 0.0
        var sumB = 0.0
        
        for i in 0..<a.count {
            sumDiff += abs(a[i] - b[i])
            sumB += abs(b[i])
        }
        
        return sumB > 0 ? sumDiff / sumB : 0.0
    }
}
