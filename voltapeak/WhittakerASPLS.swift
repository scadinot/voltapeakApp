//
//  WhittakerASPLS.swift
//  voltapeak
//
//  Implémentation EXACTE de pybaselines.whittaker.aspls
//  Basée sur le code source Python original :
//  https://github.com/derb12/pybaselines/blob/main/pybaselines/whittaker.py
//

import Foundation
import Accelerate

/// Implémentation EXACTE de pybaselines.whittaker.aspls (Zhang 2020)
///
/// Adaptive Smoothness Penalized Least Squares :
/// - vecteur α modulant la pénalité localement : `lhs = diag(α) · (λ·D^TD)`
/// - mise à jour sigmoïdale des poids basée sur `σ = std(résidus négatifs)`
/// - convergence sur le changement relatif des poids (PAS de la baseline)
///
/// Référence Python (pybaselines._Whittaker.aspls) :
/// ```python
/// def aspls(data, lam=1e5, diff_order=2, max_iter=100, tol=1e-3,
///           weights=None, alpha=None, asymmetric_coef=0.5):
///     w = ones(n) if weights is None else weights
///     a = ones(n) if alpha is None else alpha
///     DTD = D.T @ D
///     for i in range(max_iter + 1):
///         lhs = diag(a) @ (lam * DTD)
///         lhs[diag] += w
///         baseline = solve(lhs, w * y)
///         residual = y - baseline
///         neg = residual[residual < 0]
///         if len(neg) < 2: break
///         sigma = std(neg, ddof=1)
///         new_w = expit(-(asymmetric_coef / sigma) * (residual - sigma))
///         if rel_diff(w, new_w) < tol: break
///         w = new_w
///         a = abs(residual) / max(abs(residual))
///     return baseline
/// ```
enum WhittakerASPLS {

    /// Calcule la baseline par algorithme asPLS exact (pybaselines.whittaker.aspls)
    /// - Parameters:
    ///   - y: Signal d'entrée
    ///   - lam: Paramètre de lissage (typiquement `1e3 * n²` chez voltapeak)
    ///   - diffOrder: Ordre de la matrice de différences (défaut 2)
    ///   - maxIter: Nombre max d'itérations (défaut 100 ; voltapeak utilise 25)
    ///   - tol: Tolérance de convergence sur le changement de poids (défaut 1e-3)
    ///   - weights: Poids initiaux ; pour exclure une zone autour du pic, mettre 0.001
    ///   - alpha: Vecteur α initial (défaut ones)
    ///   - asymmetricCoef: Coefficient k du papier asPLS (défaut 0.5 — pybaselines)
    /// - Returns: Baseline estimée
    static func aspls(
        y: [Double],
        lam: Double = 1e5,
        diffOrder: Int = 2,
        maxIter: Int = 100,
        tol: Double = 1e-3,
        weights: [Double]? = nil,
        alpha: [Double]? = nil,
        asymmetricCoef: Double = 0.5
    ) -> [Double] {
        let n = y.count
        var w = weights ?? [Double](repeating: 1.0, count: n)
        var a = alpha ?? [Double](repeating: 1.0, count: n)

        // DTD = D^T @ D où D est la matrice de différences d'ordre `diffOrder`
        let DTD = buildDTD(n: n, diffOrder: diffOrder)

        var baseline = [Double](repeating: 0.0, count: n)
        var iterationsDone = 0

        // pybaselines fait range(max_iter + 1) — donc maxIter + 1 itérations possibles
        for iteration in 0...maxIter {
            iterationsDone = iteration + 1

            // Construit lhs = diag(a) · (λ · DTD), puis ajoute w sur la diagonale
            // lhs[i][j] = λ · DTD[i][j] · a[i]   (a multiplie LIGNE i)
            //          + (w[i] si i==j sinon 0)
            var A = [[Double]](repeating: [Double](repeating: 0.0, count: n), count: n)
            for i in 0..<n {
                let scale = lam * a[i]
                for j in 0..<n {
                    A[i][j] = scale * DTD[i][j]
                }
                A[i][i] += w[i]
            }

            // RHS = w * y (produit élément par élément)
            var b = [Double](repeating: 0.0, count: n)
            for i in 0..<n {
                b[i] = w[i] * y[i]
            }

            // Système non-symétrique (à cause de diag(a) à gauche) → solveur général
            baseline = solveFallback(A: A, b: b)

            // Résidus
            var residual = [Double](repeating: 0.0, count: n)
            var maxAbsRes = 0.0
            for i in 0..<n {
                residual[i] = y[i] - baseline[i]
                let absR = abs(residual[i])
                if absR > maxAbsRes { maxAbsRes = absR }
            }

            // Résidus négatifs pour calculer σ
            var negRes: [Double] = []
            for r in residual where r < 0 {
                negRes.append(r)
            }
            if negRes.count < 2 {
                // Pas assez de résidus négatifs → exit_early (comme pybaselines)
                break
            }

            // σ = std(negRes, ddof=1)
            let negMean = negRes.reduce(0, +) / Double(negRes.count)
            var variance = 0.0
            for r in negRes {
                let d = r - negMean
                variance += d * d
            }
            let sigma = sqrt(variance / Double(negRes.count - 1))
            guard sigma > 0 else { break }

            // new_w[i] = expit(-(k/σ) · (residual[i] - σ))
            //         = 1 / (1 + exp((k/σ) · (residual[i] - σ)))
            var newW = [Double](repeating: 0.0, count: n)
            let kOverSigma = asymmetricCoef / sigma
            for i in 0..<n {
                newW[i] = 1.0 / (1.0 + exp(kOverSigma * (residual[i] - sigma)))
            }

            // Convergence : relative_difference(w, new_w) = sum|w - new_w| / sum|new_w|
            var sumDiff = 0.0
            var sumNewAbs = 0.0
            for i in 0..<n {
                sumDiff += abs(w[i] - newW[i])
                sumNewAbs += abs(newW[i])
            }
            let relDiff = sumNewAbs > 0 ? sumDiff / sumNewAbs : 0.0
            if relDiff < tol { break }

            // Mise à jour pour itération suivante
            w = newW
            if maxAbsRes > 0 {
                for i in 0..<n {
                    a[i] = abs(residual[i]) / maxAbsRes
                }
            }
        }

        print("   asPLS convergé après \(iterationsDone) itérations (max=\(maxIter + 1))")
        return baseline
    }
    
    /// Construit D^T D directement (optimisation)
    /// En Python : D = difference_matrix(n, diff_order); DTD = D.T @ D
    ///
    /// Pour diffOrder=2, D est la matrice de différences secondes (n-2)×n :
    /// D[i,i] = 1, D[i,i+1] = -2, D[i,i+2] = 1
    ///
    /// D^T D résultant est une matrice pentadiagonale n×n
    private static func buildDTD(n: Int, diffOrder: Int) -> [[Double]] {
        guard diffOrder == 2 else {
            fatalError("Seul diffOrder=2 est supporté (comme pybaselines par défaut)")
        }
        
        // Initialiser matrice n×n
        var DTD = [[Double]](repeating: [Double](repeating: 0.0, count: n), count: n)
        
        // Pattern pentadiagonal exact de D^T D pour diffOrder=2
        // Calculé comme suit en Python :
        // D = np.diff(np.eye(n), n=2, axis=0)
        // DTD = D.T @ D
        
        for i in 0..<n {
            for j in 0..<n {
                let dist = abs(i - j)
                
                if dist == 0 {
                    // Diagonale principale
                    if i == 0 || i == n - 1 {
                        DTD[i][j] = 1.0  // Coins
                    } else if i == 1 || i == n - 2 {
                        DTD[i][j] = 5.0  // Près des bords
                    } else {
                        DTD[i][j] = 6.0  // Centre
                    }
                } else if dist == 1 {
                    // Première diagonale (offset ±1)
                    if (i == 0 && j == 1) || (i == 1 && j == 0) ||
                       (i == n - 1 && j == n - 2) || (i == n - 2 && j == n - 1) {
                        DTD[i][j] = -2.0  // Près des bords
                    } else {
                        DTD[i][j] = -4.0  // Centre
                    }
                } else if dist == 2 {
                    // Deuxième diagonale (offset ±2)
                    DTD[i][j] = 1.0
                }
                // dist > 2 : reste à 0
            }
        }
        
        return DTD
    }
    
    /// Résout le système pondéré : (W + λ D^T D) z = W y
    /// En Python : Z = W + lam * DTD; z = spsolve(Z, w * y)
    /// où W = diags(w) est une matrice diagonale
    private static func solveWeightedSystem(y: [Double], w: [Double], DTD: [[Double]], lam: Double) -> [Double] {
        let n = y.count
        
        // Construire la matrice du système : A = W + λ D^T D
        // En Python : Z = diags(w) + lam * DTD
        var A = [[Double]](repeating: [Double](repeating: 0.0, count: n), count: n)
        
        for i in 0..<n {
            for j in 0..<n {
                if i == j {
                    // Diagonale : W[i,i] + λ * DTD[i,i] = w[i] + λ * DTD[i,i]
                    A[i][j] = w[i] + lam * DTD[i][j]
                } else {
                    // Hors diagonale : 0 + λ * DTD[i,j]
                    A[i][j] = lam * DTD[i][j]
                }
            }
        }
        
        // Vecteur de droite : b = W y = w * y (produit élément par élément)
        var b = [Double](repeating: 0.0, count: n)
        for i in 0..<n {
            b[i] = w[i] * y[i]
        }
        
        // Résoudre le système linéaire A z = b
        // Python utilise scipy.sparse.linalg.spsolve (décomposition de Cholesky)
        // On utilise LAPACK dposv_ (décomposition de Cholesky pour matrices symétriques définies positives)
        let z = solvePositiveDefinite(A: A, b: b)
        
        return z
    }
    
    /// Résout un système linéaire avec matrice symétrique définie positive
    /// Utilise la décomposition de Cholesky (comme scipy.linalg.solve en Python)
    ///
    /// En Python : z = scipy.sparse.linalg.spsolve(A, b)
    /// Utilise internalement une factorisation de Cholesky pour matrices symétriques
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
        var uplo: Int8 = 76 // 'L' en ASCII
        
        // Décomposition de Cholesky + résolution
        // DPOSV résout A*X = B où A est symétrique définie positive
        // Équivalent à scipy.linalg.solve avec assume_a='pos'
        dposv_(&uplo, &nInt, &nrhs, &aFlat, &lda, &bCopy, &ldb, &info)
        
        // Si la matrice n'est pas définie positive, utiliser une méthode de secours
        if info != 0 {
            return solveFallback(A: A, b: b)
        }
        
        return bCopy
    }
    
    /// Méthode de secours : résolution par élimination de Gauss avec pivotage partiel
    /// Utilisée si la décomposition de Cholesky échoue
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
    /// En Python : relative_difference = np.sum(abs(z - z_old)) / np.sum(abs(z_old))
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
