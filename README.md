# voltapeakApp

> Analyse interactive de voltampérogrammes SWV — un fichier à la fois. Application macOS.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Swift 5.0](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org)
[![macOS 26.1+](https://img.shields.io/badge/macOS-26.1+-blue.svg)](https://www.apple.com/macos/)
[![CI](https://github.com/scadinot/voltapeakApp/actions/workflows/build-artifact.yml/badge.svg)](https://github.com/scadinot/voltapeakApp/actions/workflows/build-artifact.yml)
[![Release](https://github.com/scadinot/voltapeakApp/actions/workflows/release.yml/badge.svg)](https://github.com/scadinot/voltapeakApp/actions/workflows/release.yml)

## À propos

`voltapeakApp` est une application macOS native (SwiftUI) qui applique le [pipeline scientifique](#pipeline-scientifique) SWV à un fichier `.txt` SWV chargé interactivement, puis produit une visualisation graphique et un export CSV ou XLSX.

C'est l'application de référence de la suite : les implémentations Swift des algorithmes y sont définies puis reprises à l'identique par les deux autres outils.

Implémentations Swift natives — aucune dépendance externe.

## Écosystème voltapeak

Cette application fait partie d'une suite de 3 outils macOS dédiés à l'analyse de signaux de voltampérométrie à ondes carrées (SWV) :

- **[voltapeakApp](https://github.com/scadinot/voltapeakApp)** — analyseur interactif fichier-par-fichier (source de vérité des algorithmes).
- **[voltapeak_batchApp](https://github.com/scadinot/voltapeak_batchApp)** — traitement par lot multi-électrodes, agrégation Excel par canal (`*_C<NN>.txt`).
- **[voltapeak_loopsApp](https://github.com/scadinot/voltapeak_loopsApp)** — traitement par lot pour expériences en boucles ou dosages (`*_loopZZ.txt`, `ZZ_<concentration>_*`).

Les 3 applications partagent le même pipeline scientifique et les mêmes implémentations Swift natives des algorithmes Savitzky-Golay et Whittaker asPLS.

## Pipeline scientifique

Le pipeline de traitement SWV est identique sur les 3 applications :

1. **Lecture** du fichier `.txt` (2 colonnes Potentiel / Courant, séparateurs et encodage configurables, ISO Latin-1 par défaut).
2. **Tri** par potentiel croissant et **inversion du signe** du courant.
3. **Lissage** Savitzky-Golay (fenêtre = 11, ordre = 2).
4. **Détection brute du pic** sur le signal lissé (marge 10 %, pente max = 500) pour fixer la fenêtre d'exclusion baseline.
5. **Correction de baseline** par Whittaker asPLS (λ = 1e3·n², exclusion 3 %, tolérance 1e-2, max 25 itérations, solveur LAPACK banded `dgbsv` en O(n)).
6. **Signal corrigé** = signal lissé − baseline.
7. **Détection finale du pic** sur le signal corrigé.

## Format des fichiers

| Aspect                | Valeur |
|-----------------------|--------|
| Type d'entrée         | 1 fichier `.txt` (2 colonnes Potentiel V / Courant A, encodage et séparateurs configurables, ISO Latin-1 par défaut) |
| Convention de nommage | Aucune contrainte (fichier libre) |
| Sortie principale     | CSV ou XLSX (5 colonnes : V, I_brut, lissé, baseline, corrigé) |
| Sorties optionnelles  | — |

## Prérequis

- macOS 26.1 ou supérieur
- Xcode 16 ou supérieur (objectVersion = 77)
- Swift 5.0

Aucune dépendance externe : tout repose sur les frameworks Apple (SwiftUI, AppKit, Accelerate, Charts, Foundation, Observation).

## Build & exécution

Avec Xcode : ouvrir `voltapeak.xcodeproj` et lancer (⌘R).

En ligne de commande :

```bash
xcodebuild build \
  -project voltapeak.xcodeproj \
  -scheme voltapeak
```

Aucune dépendance externe à installer.

## Tests

Suite de tests Swift `Testing` (syntaxe `@Suite` / `@Test`) couvrant `SavitzkyGolay`, `WhittakerASPLS` et `SignalProcessing`.

```bash
xcodebuild test \
  -scheme voltapeak \
  -destination 'platform=macOS'
```

## CI/CD

| Workflow              | Déclencheur            | Action                          | Artefact |
|-----------------------|------------------------|---------------------------------|----------|
| `swift.yml`           | push `main`, PR        | Build + test + analyze          | Aucun (statut CI) |
| `build-artifact.yml`  | push `main`, manuel    | Archive `.app` non signée       | Artefact GitHub Actions |
| `release.yml`         | tag `v*` ou `[0-9]*`   | Archive + zip `.app`            | Release GitHub |

## Algorithmes & références

- **Savitzky-Golay** : implémentation Swift native dont les coefficients sont alignés sur `scipy.signal.savgol_coeffs`.
- **Whittaker asPLS** (Adaptive Smoothness Penalized Least Squares) : port Swift de `pybaselines.whittaker.aspls`, résolu par un solveur LAPACK banded `dgbsv` (O(n)) pour rester tractable jusqu'à 10 000 points.
  - Référence : Zhang, F., et al. (2020). *Baseline correction for Raman spectra using an improved asymmetric least squares method.*

Les détails d'implémentation (paramètres, garde-fous, conventions de signe) sont préservés à l'identique entre les 3 applications.

## Licence

[MIT](LICENSE) — Copyright (c) 2026 Stéphane Cadinot.
