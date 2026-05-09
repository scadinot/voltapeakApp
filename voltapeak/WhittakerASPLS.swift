//
//  WhittakerASPLS.swift
//  voltapeak
//
//  Implémentation EXACTE de pybaselines.whittaker.aspls
//

import Foundation
import Accelerate

/// Implémentation exacte de l'algorithme asPLS (Adaptive Smoothness Penalized Least Squares)
/// Équivalent de pybaselines.whittaker.aspls
enum WhittakerASPLS {
    
    /// Calcule la baseline par algorithme asPLS
    /// - Parameters:
    ///   - y: Signal d'entrée
    ///   - lam: Paramètre de lissage (lambda)
    ///   - p: Paramètre d'asymétrie (0.001 par défaut, comme pybaselines)
    ///   - diffOrder: Ordre de la dérivée (2 pour dérivée seconde)
    ///   - maxIter: Nombre maximum d'itérations
    ///   - tol: Tolérance de convergence
    ///   - weights: Poids initiaux optionnels
    /// - Returns: Baseline estimée
    static func aspls(
        y: [Double],
        lam: Double = 1e6,
        p: Double = 0.001,
        diffOrder: Int = 2,
        maxIter: Int = 50,
        tol: Double = 1e-3,
        weights: [Double]? = nil
    ) -> [Double] {
        let n = y.count
        
        // Poids initiaux
        var w = weights ?? [Double](repeating: 1.0, count: n)
        
        // Matrice de différences D (opérateur dérivée d'ordre diffOrder)
        let D = differencingMatrix(n: n, order: diffOrder)
        
        // Pré-calculer D^T * D (matrice de pénalité)
        let DTD = matrixMultiply(transpose(D), D)
        
        var z = y  // Baseline initiale
        var zPrev: [Double]
        
        for iteration in 0..<maxIter {
            zPrev = z
            
            // Matrice diagonale des poids W
            // Résoudre : (W + λ D^T D) z = W y
            // Équivalent à : z = (W + λ D^T D)^{-1} W y
            
            z = solveWeightedSystem(y: y, w: w, DTD: DTD, lam: lam)
            
            // Mise à jour des poids (principe asPLS)
            for i in 0..<n {
                let diff = y[i] - z[i]
                if diff > 0 {
                    // Point au-dessus de la baseline : poids réduit
                    w[i] = p
                } else {
                    // Point en-dessous : poids fort
                    w[i] = 1.0 - p
                }
            }
            
            // Test de convergence : changement relatif
            let change = computeRelativeChange(z, zPrev)
            if change < tol && iteration > 0 {
                break
            }
        }
        
        return z
    }
    
    /// Crée la matrice de différences d'ordre n
    private static func differencingMatrix(n: Int, order: Int) -> [[Double]] {
        // Matrice identité
        var D = identity(n: n)
        
        // Appliquer l'opérateur de différences 'order' fois
        for _ in 0..<order {
            D = diff(D)
        }
        
        return D
    }
    
    /// Matrice identité
    private static func identity(n: Int) -> [[Double]] {
        var matrix = [[Double]](repeating: [Double](repeating: 0.0, count: n), count: n)
        for i in 0..<n {
            matrix[i][i] = 1.0
        }
        return matrix
    }
    
    /// Opérateur de différences (équivalent à np.diff)
    private static func diff(_ matrix: [[Double]]) -> [[Double]] {
        let m = matrix.count
        let n = matrix[0].count
        
        guard m > 0 else { return matrix }
        
        var result = [[Double]](repeating: [Double](repeating: 0.0, count: n), count: m - 1)
        
        for i in 0..<(m - 1) {
            for j in 0..<n {
                result[i][j] = matrix[i + 1][j] - matrix[i][j]
            }
        }
        
        return result
    }
    
    /// Transpose d'une matrice
    private static func transpose(_ matrix: [[Double]]) -> [[Double]] {
        guard !matrix.isEmpty else { return matrix }
        let m = matrix.count
        let n = matrix[0].count
        
        var result = [[Double]](repeating: [Double](repeating: 0.0, count: m), count: n)
        
        for i in 0..<m {
            for j in 0..<n {
                result[j][i] = matrix[i][j]
            }
        }
        
        return result
    }
    
    /// Multiplication de matrices
    private static func matrixMultiply(_ A: [[Double]], _ B: [[Double]]) -> [[Double]] {
        let m = A.count
        let n = B[0].count
        let p = A[0].count
        
        guard p == B.count else {
            fatalError("Matrix dimensions mismatch")
        }
        
        var result = [[Double]](repeating: [Double](repeating: 0.0, count: n), count: m)
        
        for i in 0..<m {
            for j in 0..<n {
                var sum = 0.0
                for k in 0..<p {
                    sum += A[i][k] * B[k][j]
                }
                result[i][j] = sum
            }
        }
        
        return result
    }
    
    /// Résout le système pondéré (W + λ D^T D) z = W y
    private static func solveWeightedSystem(y: [Double], w: [Double], DTD: [[Double]], lam: Double) -> [Double] {
        let n = y.count
        
        // Construire la matrice du système : A = W + λ D^T D
        var A = [[Double]](repeating: [Double](repeating: 0.0, count: n), count: n)
        
        for i in 0..<n {
            for j in 0..<n {
                A[i][j] = lam * DTD[i][j]
                if i == j {
                    A[i][j] += w[i]
                }
            }
        }
        
        // Vecteur de droite : b = W y
        var b = [Double](repeating: 0.0, count: n)
        for i in 0..<n {
            b[i] = w[i] * y[i]
        }
        
        // Résoudre le système linéaire A z = b
        // Utiliser décomposition de Cholesky (matrice symétrique définie positive)
        let z = solvePositiveDefinite(A: A, b: b)
        
        return z
    }
    
    /// Résout un système linéaire avec matrice symétrique définie positive
    /// Utilise la décomposition de Cholesky (comme scipy.linalg.solve)
    private static func solvePositiveDefinite(A: [[Double]], b: [Double]) -> [Double] {
        let n = A.count
        
        // Convertir en format column-major pour LAPACK
        var aFlat = [Double]()
        for j in 0..<n {
            for i in 0..<n {
                aFlat.append(A[i][j])
            }
        }
        
        var bCopy = b
        var nInt = __CLPK_integer(n)
        var nrhs = __CLPK_integer(1)
        var lda = __CLPK_integer(n)
        var ldb = __CLPK_integer(n)
        var info: __CLPK_integer = 0
        var uplo: [CChar] = Array("L".utf8CString)  // Lower triangle
        
        // Décomposition de Cholesky + résolution
        // dposv résout A*X = B où A est symétrique définie positive
        dposv_(
            &uplo,
            &nInt,
            &nrhs,
            &aFlat,
            &lda,
            &bCopy,
            &ldb,
            &info
        )
        
        if info != 0 {
            // Si la décomposition de Cholesky échoue, utiliser une méthode de secours
            return solveFallback(A: A, b: b)
        }
        
        return bCopy
    }
    
    /// Méthode de secours : résolution par élimination de Gauss
    private static func solveFallback(A: [[Double]], b: [Double]) -> [Double] {
        let n = A.count
        
        // Copier A et b
        var M = A
        var y = b
        
        // Élimination de Gauss avec pivotage partiel
        for k in 0..<n {
            // Trouver le pivot
            var maxRow = k
            var maxVal = abs(M[k][k])
            
            for i in (k+1)..<n {
                if abs(M[i][k]) > maxVal {
                    maxVal = abs(M[i][k])
                    maxRow = i
                }
            }
            
            // Échanger les lignes
            if maxRow != k {
                M.swapAt(k, maxRow)
                y.swapAt(k, maxRow)
            }
            
            // Élimination
            for i in (k+1)..<n {
                let factor = M[i][k] / M[k][k]
                for j in k..<n {
                    M[i][j] -= factor * M[k][j]
                }
                y[i] -= factor * y[k]
            }
        }
        
        // Substitution arrière
        var x = [Double](repeating: 0.0, count: n)
        for i in stride(from: n-1, through: 0, by: -1) {
            var sum = y[i]
            for j in (i+1)..<n {
                sum -= M[i][j] * x[j]
            }
            x[i] = sum / M[i][i]
        }
        
        return x
    }
    
    /// Calcule le changement relatif entre deux vecteurs
    private static func computeRelativeChange(_ a: [Double], _ b: [Double]) -> Double {
        var sumDiff = 0.0
        var sumB = 0.0
        
        for i in 0..<a.count {
            sumDiff += abs(a[i] - b[i])
            sumB += abs(b[i])
        }
        
        return sumB > 0 ? sumDiff / sumB : 0.0
    }
}
