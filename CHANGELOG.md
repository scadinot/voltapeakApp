# Changelog

Toutes les modifications notables de `voltapeakApp` sont listées ici.
Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/)
et la numérotation respecte
[Semantic Versioning](https://semver.org/lang/fr/).

Pour le contexte famille `voltapeak*`, voir les CHANGELOG des dépôts
frères :
[`voltapeak_batchApp`](https://github.com/scadinot/voltapeak_batchApp/blob/main/CHANGELOG.md),
[`voltapeak_loopsApp`](https://github.com/scadinot/voltapeak_loopsApp/blob/main/CHANGELOG.md).

## [1.0.0] — 2026-05-13 — Portage bit-exact Python → Swift

Cette version marque l'achèvement du portage de l'outil Python
`voltapeak` vers une application macOS native, avec une équivalence
numérique stricte à la 6ᵉ décimale. C'est aussi la **version qui établit
la référence canonique des fonctions d'analyse** pour la famille
`voltapeak*`.

### Ajouté

- **Application macOS SwiftUI native** : interface complète avec file
  picker sandboxé, chart interactif, export.
- **Export Excel `.xlsx`** : générateur autonome (`XLSXWriter.swift`,
  ~220 lignes) avec mini-ZIP store-only + OOXML, **aucune dépendance
  externe**.
- **Export CSV** : format compatible Excel/Numbers avec 5 colonnes
  (Potentiel, Courant brut, Signal lissé, Baseline, Signal corrigé).
- **Visualisation** : `VoltammogramChartView` (SwiftUI Charts) avec
  4 séries (brut, lissé, baseline tiretée, corrigé) + marqueur de pic
  magenta + ligne verticale.
- **Configuration** : sélection du séparateur de colonnes
  (Tab/Virgule/Point-virgule/Espace) et décimal (Point/Virgule).
- **Documentation complète** : README, ARCHITECTURE, ALGORITHMS,
  VALIDATION, DEVELOPMENT, DISTRIBUTION, CHANGELOG.

### Algorithmes

- **Savitzky-Golay scipy-exact** :
  - Coefficients centrés
    `[−36, 9, 44, 69, 84, 89, 84, 69, 44, 9, −36] / 429` (somme = 1).
  - 10 jeux de coefficients de bord pour mode `'interp'`
    (`pos ∈ [0..4]` et `[6..10]`).
  - Équivalent à `scipy.signal.savgol_filter(window=11, polyorder=2)`.
- **Gradient numpy 2ᵉ ordre non-uniforme** :
  - Formule
    `−hs·y[i−1]/(hd·(hd+hs)) + (hs−hd)·y[i]/(hd·hs) + hd·y[i+1]/(hs·(hd+hs))`.
  - Bords en différence finie 1ᵉʳ ordre.
- **asPLS Zhang 2020 complet** (réécriture totale) :
  - Vecteur α adaptatif (`α = |résidu| / max(|résidu|)`).
  - Poids sigmoïdaux (`w = expit(−(k/σ)·(d − σ))` avec
    `σ = std(résidus négatifs, ddof=1)`).
  - Système asymétrique `(W + λ·diag(α)·D^T·D) z = W·y`, résolu par
    Gauss avec pivotage partiel.
  - Paramètres alignés Python : `λ = 1e3·n²`, `k = 0.5`, `tol = 1e-2`,
    `max_iter = 25`.
  - Zone d'exclusion `[xPeak ± 0.03·range]` avec poids initial `0.001`.

### Corrections critiques

Voir [VALIDATION.md](VALIDATION.md) pour les détails complets des 10
bugs identifiés et corrigés. Les plus significatifs :

- **Mauvais algorithme asPLS** : l'ancienne implémentation utilisait en
  réalité asLS d'Eilers (`w = p si y>z, 1−p sinon`) au lieu d'asPLS de
  Zhang. Résultat : ~5.4 mA au lieu de 6.93 mA (écart de 22 %).
- **Coefficients Savitzky-Golay invalides** : l'ancienne table sommait à
  1.244 au lieu de 1.0, ce qui amplifiait le signal lissé de 24 %.
- **Bords du lissage par extrapolation linéaire** au lieu du polyfit
  local scipy `'interp'`.
- **Paramètres asPLS divergents** : `lam=1e6` constant (au lieu de
  `1e3·n²`), `tol=1e-3`, `max_iter=50`, `weights=nil` (pas de zone
  d'exclusion).

### Améliorations UI

- **Parité visuelle matplotlib** : couleurs alignées sur la palette
  **tab10** (C0 bleu, C1 orange, C2 vert, C3 rouge, magenta pour le
  pic).
- **Domaines X/Y contraints** au domaine des données (plus d'extension
  automatique aux nombres ronds).
- **Bug rendu Charts résolu** : ajout du paramètre `series:` sur
  `LineMark` (sans lequel SwiftUI Charts désature les lignes en gris
  pâle).
- **Icônes app** : asset catalog nettoyé (10 entrées Mac uniquement,
  7 PNG, plus de bloat iOS).

### Supprimé / Ménage

- 4 fichiers Swift orphelins supprimés (`VoltapeakViewModelExact`,
  `SignalProcessingImproved`, `SavitzkyGolay` doublon,
  `AnalysisConfiguration` + 3 résidus dans `voltapeak.xcodeproj/`).
- Code mort supprimé dans `SignalProcessing.swift` :
  `savitzkyGolayFilter` simplifié, `calculateBaseline` simplifié,
  `polynomialFit`, `import Accelerate`.
- Code mort supprimé dans `VoltapeakViewModel.swift` : méthode `reset()`
  jamais appelée.
- Code mort supprimé dans `WhittakerASPLS.swift` : `solveWeightedSystem`,
  `solvePositiveDefinite` (utilisait `dposv_` LAPACK déprécié macOS
  13.3+).
- Asset catalog : 12 PNG iOS-only supprimés, `Contents.json` réécrit
  pour Mac uniquement.
- `.gitignore` créé (patterns macOS + Xcode + SwiftPM).
- Plusieurs `.DS_Store` purgés.
- DerivedData Xcode nettoyé pour forcer rebuild propre.

### Compatibilité

- macOS 14.0+ (Sonoma) requis (`Charts` framework + macro `@Observable`).
- Universal binary (Intel + Apple Silicon).
- App Sandbox activé (`user-selected.read-only`).

### Notes de validation

Pipeline numérique validé bit-exact à la 6ᵉ décimale contre la référence
Python (`scipy`, `pybaselines`, `numpy`) sur le fichier
`BT16Mb-T16TAC_04_SWV_C08.txt` (n=85). Méthodologie compare-and-fix
documentée dans [VALIDATION.md](VALIDATION.md). Ce document est la
**référence canonique** de validation numérique pour la famille
`voltapeak*` ; les deux apps batch reprennent les fonctions d'analyse à
l'identique et héritent de cette validation par construction.

### Crédits

Algorithmes — portages directs des bibliothèques Python de référence :

- **scipy** (`scipy.signal.savgol_filter`) — lissage Savitzky-Golay.
- **pybaselines** (`pybaselines.whittaker.aspls`) — baseline asPLS Zhang
  2020.
- **numpy** (`np.gradient`) — gradient 2ᵉ ordre non-uniforme.
- **matplotlib** — palette **tab10** pour parité visuelle.

---

## Historique antérieur (avant ce changelog)

Le projet a connu plusieurs itérations avant cette version `1.0.0` :

- Implémentations multiples concurrentes (`VoltapeakViewModel` vs
  `VoltapeakViewModelExact`, `SignalProcessing` vs
  `SignalProcessingImproved`, etc.) — toutes consolidées en une seule.
- Tentatives successives d'implémenter asPLS qui produisaient ~5.4 mA
  au lieu de 6.93 mA.
- Confusion historique entre `asls` (Eilers) et `aspls` (Zhang) —
  résolue par référence directe au code source `pybaselines`.

Le présent CHANGELOG reflète l'état **après** consolidation.
