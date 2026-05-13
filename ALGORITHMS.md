# Algorithmes numériques

Ce document détaille les algorithmes mathématiques utilisés dans
`voltapeakApp` et leur correspondance avec la référence Python (`scipy`,
`numpy`, `pybaselines`). Tous les détails permettent de reproduire le calcul
à la 6ᵉ décimale.

Ce document est la **référence canonique** pour la chaîne d'analyse SWV. Les
applications batch
[`voltapeak_batchApp`](https://github.com/scadinot/voltapeak_batchApp) et
[`voltapeak_loopsApp`](https://github.com/scadinot/voltapeak_loopsApp)
reprennent ce pipeline à l'identique (sections 1-7) et y ajoutent une
orchestration multi-fichiers (sections 8+).

## 1. Lecture du fichier SWV

**Implémentation :** `SWVFileReader.readFile(at:config:)`

- **Encodage** : ISO Latin-1 (les potentiostats francophones produisent des entêtes avec accents)
- **Format attendu** :
  ```
  [Entête — 1 ligne, ignorée]
  potentiel<sep>courant
  potentiel<sep>courant
  ...
  ```
- **Séparateurs configurables** : tabulation, virgule, point-virgule, espace
- **Décimale configurable** : point ou virgule
- **Filtrage anticipé** : les lignes à courant nul sont écartées dès la lecture (le Python les filtre dans `processData`, mais le résultat est identique car la somme des zéros est nulle)

## 2. Traitement des données

**Implémentation :** `SWVFileReader.processData(_:)`

Trois opérations en chaîne :

1. **Tri** par potentiel croissant (le fichier peut être en scan retour)
2. **Inversion de signe** du courant : `signal = -current`
   - Convention SWV cathodique : le courant mesuré est négatif
   - L'inversion permet à `argmax` de trouver le sommet du pic comme un maximum
3. **Pas de filtrage** ici (déjà fait dans `readFile`)

Sortie : `(potentials: [Double], signal: [Double])`, tableaux alignés et triés.

## 3. Lissage Savitzky-Golay

**Implémentation :** `SavitzkyGolay.filter(_:windowLength:polynomialOrder:)`

Équivalent strict à `scipy.signal.savgol_filter(signal, 11, 2, mode='interp')`.

### Principe

Pour chaque point, on ajuste localement un polynôme de degré 2 (parabole) sur
une fenêtre de 11 points et on évalue ce polynôme à la position centrale. Cela
atténue le bruit haute fréquence tout en préservant la position et l'amplitude
du pic.

### Coefficients centraux (mode `dot`, position 5, symétrique)

Pour les points où une fenêtre complète est disponible (indices `5..n-6`), la
convolution centrée utilise :

```
coeffs = [−36, 9, 44, 69, 84, 89, 84, 69, 44, 9, −36] / 429
```

Somme = `429 / 429 = 1` (préservation des constantes).

### Bords : mode `'interp'`

Aux bords du signal (5 premiers et 5 derniers points), scipy mode `'interp'`
n'extrapole pas mais ajuste un polynôme de degré 2 sur les 11 premiers (resp.
derniers) points et évalue ce polynôme à la position du point cherché.

Cela donne **10 jeux de coefficients spécifiques** pour `pos ∈ {0, 1, 2, 3, 4, 6, 7, 8, 9, 10}`
— obtenus avec `scipy.signal.savgol_coeffs(11, 2, pos=p, use='dot')` et codés
en dur dans `SavitzkyGolay.boundaryCoeffs`.

### Référence

Savitzky, A., & Golay, M. J. E. (1964). *Smoothing and Differentiation of Data
by Simplified Least Squares Procedures*. **Analytical Chemistry**, 36(8),
1627-1639.

## 4. Détection de pic

**Implémentation :** `SignalProcessing.detectPeak(signal:potentials:marginRatio:maxSlope:)`

### Étape 1 : exclusion des bords

`margin = floor(n × marginRatio)` (avec `marginRatio = 0.10` par défaut, soit 10 %)

La recherche du pic se fait uniquement dans `signal[margin ..< n-margin]`. Cela
évite de détecter les artefacts de démarrage/arrêt du potentiostat.

### Étape 2 : filtre de pente

Si `maxSlope` est fourni (500 par défaut), on calcule le gradient numérique et
on ne garde comme candidats que les indices où `|gradient| < maxSlope`.

### Gradient numpy 2ᵉ ordre non-uniforme

`numpy.gradient(y, x)` utilise pour les pas non-uniformes (intérieur) :

```
hd = x[i] − x[i−1]                                 (pas gauche)
hs = x[i+1] − x[i]                                  (pas droite)
grad[i] = −hs / (hd·(hd+hs)) · y[i−1]
       + (hs − hd) / (hd·hs) · y[i]
       + hd / (hs·(hd+hs)) · y[i+1]
```

Aux bords : différence finie 1ᵉʳ ordre (`grad[0] = (y[1]−y[0])/(x[1]−x[0])`,
`grad[n−1]` symétrique).

Cette formulation est plus précise que la simple différence centrée
`(y[i+1]−y[i−1])/(x[i+1]−x[i−1])` quand les pas ne sont pas égaux.

### Étape 3 : argmax

Parmi les candidats (filtrés ou pas), `argmax(signal)` donne l'indice du
sommet. Si aucun candidat ne passe le filtre, le premier point de la zone de
recherche est retourné (repli défensif).

### Référence

Documentation numpy : `numpy.gradient` — *second order accurate central differences in the interior points*.

## 5. Estimation de baseline asPLS Zhang 2020

**Implémentation :** `WhittakerASPLS.aspls(y:lam:diffOrder:maxIter:tol:weights:alpha:asymmetricCoef:)`

Équivalent strict à `pybaselines.whittaker.aspls`.

### Principe

L'asPLS (**a**daptive **s**moothness **p**enalized **l**east **s**quares)
ajuste une courbe lisse sous le signal en minimisant :

```
||W·(y − z)||² + λ · z^T · D^T · diag(α) · D · z
```

où :
- `y` est le signal (lissé) d'entrée
- `z` est la baseline cherchée
- `W = diag(w)` matrice diagonale des poids (chaque point pondéré séparément)
- `D` matrice de différences finies d'ordre 2 (pénalise la courbure)
- `α` vecteur de pénalité adaptative locale (clé de l'asPLS)
- `λ` paramètre de lissage global

### Système linéaire résolu à chaque itération

```
(W + λ · diag(α) · D^T·D) · z = W · y
```

⚠️ La matrice **n'est pas symétrique** à cause de `diag(α)` à gauche (et pas
`D^T·diag(α)·D` comme dans certaines présentations du papier). Cette forme
reproduit exactement `pybaselines` qui multiplie le penalty banded par alpha
par broadcast. Le solveur Swift utilise une élimination de Gauss avec
pivotage partiel (`solveFallback`), pas une décomposition de Cholesky.

`D^T·D` est pentadiagonal (différences d'ordre 2) et construit directement
par `WhittakerASPLS.buildDTD(n:diffOrder:)`.

### Mise à jour itérative

À chaque itération :

1. **Solve** : `z = solveFallback(A, w·y)` où `A = W + λ·diag(α)·D^T·D`
2. **Résidus** : `d = y − z`
3. **Sortie anticipée** : si `card(d < 0) < 2`, on arrête (comme `pybaselines`)
4. **Mise à jour des poids** (sigmoïde) :
   ```
   neg = d[d < 0]
   σ = std(neg, ddof=1)
   w_new[i] = expit(−(k/σ) · (d[i] − σ))  =  1 / (1 + exp((k/σ)·(d[i] − σ)))
   ```
   où `k = asymmetric_coef = 0.5` (défaut pybaselines). Si `σ = 0`, on arrête.
5. **Convergence** : si `Σ|w − w_new| / Σ|w_new| < tol`, on s'arrête.
6. **Mise à jour de α** :
   ```
   α[i] = |d[i]| / max(|d|)
   ```
   Les points à fort résidu (pic) reçoivent un α proche de 1 → pénalité forte
   → la baseline reste lisse à cet endroit. Les points à faible résidu (zone
   baseline) ont α proche de 0 → pénalité faible → la baseline suit le
   signal.

### Paramètres utilisés

| Paramètre | Valeur | Origine |
|---|---|---|
| `lam` (lissage) | `1e3 × n²` (≈ 7.225e6 pour n=85) | Mise à l'échelle empirique du Python (voltapeak.py) |
| `asymmetric_coef` (k) | `0.5` | Défaut pybaselines |
| `tol` | `1e-2` | Voltapeak Python |
| `max_iter` | `25` | Voltapeak Python |
| `diff_order` | `2` | Défaut |

### Zone d'exclusion autour du pic

Avant l'appel à `aspls`, le `VoltapeakViewModel` construit un vecteur de
poids initiaux :

```swift
weights = [Double](repeating: 1.0, count: n)
exclusionWidth = 0.03 × (potentials.last − potentials.first)
for i où potentials[i] ∈ [xPeak − exclusionWidth, xPeak + exclusionWidth]:
    weights[i] = 0.001
```

Cela évite que la baseline ne « remonte » vers le sommet du pic dès la
première itération. Le sigmoid update prend ensuite le relais pour maintenir
les poids bas dans cette zone.

### Référence

Zhang, F., Tang, X., Tong, A., Wang, B., & Wang, J. (2020). *Baseline
correction for infrared spectra using adaptive smoothness parameter penalized
least squares method*. **Spectroscopy Letters**, 53(3), 222-233.

Implémentation Python de référence : [`pybaselines.whittaker.aspls`](https://github.com/derb12/pybaselines).

### asPLS vs asLS — différence essentielle

| Aspect | asLS (Eilers 2005) | asPLS (Zhang 2020) |
|---|---|---|
| Pénalité | constante `λ` partout | adaptative `λ · α[i]` |
| Poids | binaire : `p` si `y > z`, `1−p` sinon | sigmoïde basée sur `std(résidus négatifs)` |
| Convergence | sur la baseline | sur les poids |
| Paramètre clé | `p` (asymétrie, ~0.01) | `k` (asymetric_coef, 0.5) |

Une version précédente du port Swift implémentait **asLS** (par erreur). Le
résultat divergeait de ~22 % du Python. Le port actuel reproduit asPLS
exactement.

## 6. Signal corrigé

```
corrected[i] = smoothed[i] − baseline[i]
```

Opération élément par élément, triviale.

## 7. Re-détection du pic

Le pic final est obtenu en réappliquant `detectPeak` sur le signal corrigé. La
position du pic peut légèrement changer par rapport à la détection brute
(étape 4) — le signal corrigé étant plus « net » sans la dérive de la
baseline.

C'est cette deuxième détection qui produit la valeur affichée à l'écran :
**−0.273 V, 6.932 mA** pour le fichier de référence
`BT16Mb-T16TAC_04_SWV_C08.txt`.

## Pseudocode complet

```
read SWV file → DataFrame
processData → potentials[], signal[]   # tri + inversion signe

smoothed = savgol_filter(signal, 11, 2, mode='interp')

(xPeak, yPeak) = detectPeak(smoothed, potentials, margin=0.10, maxSlope=500)

weights = ones(n)
weights[ potentials ∈ [xPeak ± 0.03·range] ] = 0.001
baseline = aspls(smoothed, lam=1e3·n², weights=weights, max_iter=25, tol=1e-2, k=0.5)

corrected = smoothed − baseline

(xFinal, yFinal) = detectPeak(corrected, potentials, margin=0.10, maxSlope=500)
```

Avec `n = 85` points et le fichier de référence, ce pipeline converge en 9
itérations asPLS et produit un pic à **−0.273 V, 6.932 mA**, bit-exact avec
la référence Python.
