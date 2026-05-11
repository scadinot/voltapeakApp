# Voltapeak

Analyse de voltampérogrammes SWV (Square Wave Voltammetry) — application macOS native, portée bit-exact depuis l'outil Python d'origine.

## Objectif

Voltapeak charge un fichier `.txt` produit par un potentiostat, lisse le signal, détecte le pic anodique, estime la ligne de base par asPLS et soustrait celle-ci pour obtenir le courant net du pic. Tout cela dans une interface SwiftUI native macOS.

## Statut

✅ **Pipeline numérique bit-exact avec la référence Python** (à la 6ᵉ décimale).
Pic corrigé : **−0.273 V, 6.932 mA** (cible Python : 6.93 mA).

Validation détaillée : voir [VALIDATION.md](VALIDATION.md).

## Fonctionnalités

- Chargement de fichiers `.txt` SWV avec séparateurs configurables (tabulation, virgule, point-virgule, espace ; décimale point ou virgule)
- Lissage Savitzky-Golay (coefficients scipy exacts, fenêtre 11, ordre 2, bords `'interp'`)
- Détection de pic robuste (margin 10 %, filtre de pente)
- Baseline asPLS (algorithme Zhang 2020 complet : α adaptatif, poids sigmoïdaux, zone d'exclusion)
- Visualisation interactive (SwiftUI Charts, couleurs alignées sur matplotlib)
- Export **CSV** et **Excel `.xlsx`** (générateur xlsx autonome, aucune dépendance)

## Build rapide

Prérequis : **Xcode 15+**, **macOS 14+** (framework Charts).

```bash
open voltapeak.xcodeproj
```

Puis ⌘R dans Xcode pour compiler et lancer.

Aucune dépendance Swift Package Manager — toutes les bibliothèques utilisées (SwiftUI, Charts, Foundation, AppKit, UniformTypeIdentifiers) sont fournies par le SDK.

## Structure

8 fichiers Swift core + 1 pour l'export Excel :

```
voltapeak/
├── voltapeakApp.swift          # Entry point @main
├── ContentView.swift           # UI + VoltammogramChartView
├── VoltapeakViewModel.swift    # Orchestration pipeline (@Observable)
├── VoltammetryData.swift       # Modèles de données
├── SWVFileReader.swift         # I/O fichier SWV
├── SavitzkyGolay.swift         # Lissage scipy-exact
├── SignalProcessing.swift      # Détection de pic + gradient numpy
├── WhittakerASPLS.swift        # Baseline asPLS Zhang 2020
└── XLSXWriter.swift            # Export .xlsx (mini-ZIP + OOXML)
```

Détails dans [ARCHITECTURE.md](ARCHITECTURE.md).

## Documentation

| Document | Contenu |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Structure du projet, pipeline, rôle de chaque fichier |
| [ALGORITHMS.md](ALGORITHMS.md) | Algorithmes numériques détaillés (SG, gradient, asPLS) avec références |
| [VALIDATION.md](VALIDATION.md) | Méthodologie compare-and-fix, 10 bugs corrigés, résultats bit-exact |
| [DEVELOPMENT.md](DEVELOPMENT.md) | Guide développeur : build, debug, conventions, ajout de features |
| [DISTRIBUTION.md](DISTRIBUTION.md) | Archive, DMG, notarisation Apple |
| [CHANGELOG.md](CHANGELOG.md) | Historique des versions |

## Crédits & références

Les algorithmes sont des portages directs de :
- **scipy** (`scipy.signal.savgol_filter`) — lissage Savitzky-Golay
- **pybaselines** (`pybaselines.whittaker.aspls`) — baseline asPLS Zhang 2020
- **numpy** (`np.gradient`) — gradient 2ᵉ ordre non-uniforme
- **matplotlib** — palette tab10 pour parité visuelle

Références bibliographiques dans [ALGORITHMS.md](ALGORITHMS.md).

## Licence

© 2026 Stéphane Cadinot.
