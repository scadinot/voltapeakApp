# voltapeakApp

> Analyse interactive de voltampérogrammes SWV — un fichier à la fois. Application macOS native (SwiftUI).

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Swift 5.0](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org)
[![macOS 26.1+](https://img.shields.io/badge/macOS-26.1+-blue.svg)](https://www.apple.com/macos/)
[![CI](https://github.com/scadinot/voltapeakApp/actions/workflows/swift.yml/badge.svg)](https://github.com/scadinot/voltapeakApp/actions/workflows/swift.yml)
[![Release](https://github.com/scadinot/voltapeakApp/actions/workflows/release.yml/badge.svg)](https://github.com/scadinot/voltapeakApp/actions/workflows/release.yml)

---

## Table des matières

1. [À quoi sert cet outil ?](#à-quoi-sert-cet-outil)
2. [Écosystème voltapeak](#écosystème-voltapeak)
3. [Fonctionnalités](#fonctionnalités)
4. [Prérequis](#prérequis)
5. [Installation](#installation)
6. [Build & lancement](#build--lancement)
7. [Format des fichiers d'entrée](#format-des-fichiers-dentrée)
8. [Utilisation — interface graphique](#utilisation--interface-graphique)
9. [Résultats produits](#résultats-produits)
10. [Chaîne de traitement par fichier](#chaîne-de-traitement-par-fichier)
11. [Paramètres algorithmiques](#paramètres-algorithmiques)
12. [Architecture du code](#architecture-du-code)
13. [Tests](#tests)
14. [CI/CD](#cicd)
15. [Algorithmes & références](#algorithmes--références)
16. [Dépannage](#dépannage)
17. [Feuille de route](#feuille-de-route)
18. [Licence et auteur](#licence-et-auteur)

---

## À quoi sert cet outil ?

La **voltammétrie à vagues carrées** (Square Wave Voltammetry, SWV) est une technique électrochimique qui mesure le courant traversant une électrode en fonction d'un potentiel imposé. Le signal obtenu présente un **pic** caractéristique de l'espèce analysée, superposé à une **ligne de base** (*baseline*) qui dérive lentement avec le potentiel.

Pour exploiter le pic, il faut :

1. **lisser** le signal pour atténuer le bruit de mesure ;
2. **estimer puis soustraire** la ligne de base ;
3. **relever** les coordonnées (tension, courant) du pic corrigé.

`voltapeakApp` automatise ces trois étapes en s'appuyant sur :

- **Savitzky-Golay** pour le lissage (convolution polynomiale locale) ;
- **asPLS Whittaker** (*asymmetric Penalized Least Squares*, port Swift de [`pybaselines.whittaker.aspls`](https://pybaselines.readthedocs.io/)) pour l'estimation robuste de la baseline, avec une pondération réduite autour du pic afin d'éviter que la baseline ne « suive » et n'efface le pic.

> **Convention de signe.** Le pipeline est calibré pour des **SWV cathodiques** : le signe du courant est systématiquement inversé avant la détection de pic, donc le pic doit apparaître **en courant négatif** dans le fichier d'entrée. Un fichier où le pic est déjà en courant positif (orientation anodique) sera mal traité — il faut alors inverser la colonne en amont.

`voltapeakApp` cible l'**exploration interactive d'un seul fichier** : la figure est affichée dans une vue `SwiftUI Charts` zoomable, idéale pour qualifier visuellement un signal, régler l'œil sur la détection ou préparer une figure pour un rapport. Pour le traitement par lot, voir les apps frères [`voltapeak_batchApp`](https://github.com/scadinot/voltapeak_batchApp) et [`voltapeak_loopsApp`](https://github.com/scadinot/voltapeak_loopsApp).

C'est aussi l'**application de référence de la suite Swift** : les implémentations de Savitzky-Golay et de Whittaker asPLS y sont définies, **testées**, et reprises à l'identique par les deux outils par lot.

---

## Écosystème voltapeak

Cette application fait partie d'une suite de 3 outils macOS dédiés à l'analyse de signaux de voltampérométrie à ondes carrées (SWV) :

- **[voltapeakApp](https://github.com/scadinot/voltapeakApp)** — analyseur interactif fichier-par-fichier (source de vérité des algorithmes).
- **[voltapeak_batchApp](https://github.com/scadinot/voltapeak_batchApp)** — traitement par lot multi-électrodes, agrégation Excel par canal (`*_C<NN>.txt`).
- **[voltapeak_loopsApp](https://github.com/scadinot/voltapeak_loopsApp)** — traitement par lot pour expériences en boucles ou dosages (`*_loopZZ.txt`, `ZZ_<concentration>_*`).

Les 3 applications partagent le même pipeline scientifique et les mêmes implémentations Swift natives.

Elles sont des **portages natifs** de leurs équivalents Python ([`scadinot/voltapeak`](https://github.com/scadinot/voltapeak), [`scadinot/voltapeak_batch`](https://github.com/scadinot/voltapeak_batch), [`scadinot/voltapeak_loops`](https://github.com/scadinot/voltapeak_loops)) — avec parité numérique stricte : coefficients Savitzky-Golay identiques à `scipy.signal.savgol_coeffs(11, 2)` et solveur asPLS aligné sur `pybaselines.whittaker.aspls`.

---

## Fonctionnalités

- Lecture interactive d'**un fichier `.txt`** à deux colonnes (potentiel V, courant A).
- **Séparateur de colonnes** (tabulation, virgule, point-virgule, espace) et **séparateur décimal** (point ou virgule) configurables dans l'interface.
- **Lissage** Savitzky-Golay (fenêtre 11, ordre 2) avec coefficients pré-calculés depuis `scipy.signal.savgol_coeffs` — parité numérique stricte.
- **Détection de pic robuste** : exclusion des 10 % de bords du scan et filtre de pente `maxSlope = 500` (rejette les fronts parasites).
- **Estimation de ligne de base asPLS** avec zone d'exclusion ±3 % centrée sur le pic, résolution via solveur LAPACK banded `dgbsv_` (Accelerate, O(n)).
- **Signal corrigé** : `signalLissé − baseline`, suivi d'une re-détection du pic corrigé.
- **Visualisation interactive** via `SwiftUI Charts` : 4 séries superposées (brut / lissé / baseline / corrigé) plus marqueur du pic, palette tab10 alignée sur matplotlib pour parité visuelle Python.
- **Exports** CSV, XLSX (5 colonnes : V, I brut, lissé, baseline, corrigé) et PNG haute résolution (1600×1000, scale 2.0).
- **Raccourcis clavier** via `CommandMenu("Analyse")` : `⌘O` pour ouvrir, `⌘E` pour exporter.
- **Tolérance aux erreurs** : toute exception du pipeline est remontée dans une alerte SwiftUI avec lien d'aide, l'interface ne plante pas.
- **Zéro dépendance externe** : 100 % Swift + frameworks Apple (`SwiftUI`, `Charts`, `Accelerate`, `AppKit`, `Foundation`, `Observation`), y compris le générateur XLSX (mini-ZIP store-only + CRC32 PKZIP maison).

---

## Prérequis

- **macOS 26.1** ou supérieur (Tahoe — cible définie par `MACOSX_DEPLOYMENT_TARGET = 26.1`).
- **Xcode 26** ou supérieur (projet créé avec Xcode 26.2, `LastUpgradeCheck = 2620`, `objectVersion = 77`, support du framework `Testing` / Swift 6).
- **Swift 5.0**.

Aucune dépendance externe : tout repose sur les frameworks Apple (`SwiftUI`, `AppKit`, `Charts`, `Accelerate`, `Foundation`, `Observation`).

---

## Installation

```bash
git clone https://github.com/scadinot/voltapeakApp.git
cd voltapeakApp
open voltapeak.xcodeproj
```

Aucune installation de dépendance, aucun `pod install`, aucun `swift package resolve`.

Pour récupérer une `.app` pré-construite (non signée Developer ID), télécharger l'archive depuis l'onglet [Releases](https://github.com/scadinot/voltapeakApp/releases) du dépôt.

---

## Build & lancement

Avec Xcode : ouvrir `voltapeak.xcodeproj` et lancer (⌘R).

En ligne de commande :

```bash
xcodebuild build \
  -project voltapeak.xcodeproj \
  -scheme voltapeak
```

Le script `voltapeak.xcodeproj/create_dmg.sh` produit un DMG (`hdiutil create -format UDZO`), avec vérifications `codesign` / `stapler` et prompt interactif pour l'agrafage de la notarisation — utile pour préparer une distribution.

---

## Format des fichiers d'entrée

| Caractéristique          | Valeur                                                       |
|--------------------------|--------------------------------------------------------------|
| Extension                | `.txt`                                                       |
| Encodage                 | `ISO Latin-1` (par défaut des potentiostats BioLogic / PalmSens européens) |
| Nombre de colonnes       | ≥ 2 (seules les 2 premières sont lues)                       |
| Première ligne           | en-tête — **ignorée**                                        |
| Colonne 1                | Potentiel en volts (`Double`)                                |
| Colonne 2                | Courant en ampères — **pic attendu en valeur négative** (convention SWV cathodique : le pipeline inverse le signe avant la détection) |
| Séparateur de colonnes   | configurable : tabulation / virgule / point-virgule / espace |
| Séparateur décimal       | configurable : point / virgule                               |
| Nombre maximum de points | **200 000** (garde-fou anti-DoS du solveur asPLS — erreur explicite `FileError.tooManyPoints` au-delà) |

Exemple (tabulation, point décimal) :

```
Potential	Current
-0.500	-1.2e-6
-0.490	-1.1e-6
-0.480	-0.9e-6
...
```

### Aucune contrainte de nommage

Contrairement à [`voltapeak_batchApp`](https://github.com/scadinot/voltapeak_batchApp) et [`voltapeak_loopsApp`](https://github.com/scadinot/voltapeak_loopsApp) qui exigent des motifs précis pour l'agrégation, `voltapeakApp` accepte n'importe quel nom de fichier — c'est une vue mono-fichier strictement isolée.

---

## Utilisation — interface graphique

Au lancement, la fenêtre (1000×700, `.hiddenTitleBar`) contient :

- une **barre titre custom** qui affiche `Voltapeak` et, si chargé, le nom du fichier en cours d'analyse ;
- un cadre **Paramètres de lecture** avec deux `Picker(.segmented)` :
  - *Séparateur de colonnes* : `Tabulation` (défaut), `Virgule`, `Point-virgule`, `Espace`,
  - *Séparateur décimal* : `Point` (défaut) ou `Virgule` ;
- une zone centrale qui affiche soit un placeholder `ContentUnavailableView` (icône `waveform.path.ecg`), soit le graphe une fois l'analyse effectuée ;
- une barre d'actions : **Parcourir** (style `borderedProminent`), **Exporter CSV**, **Exporter Excel**, **Exporter PNG** — désactivés tant qu'aucune analyse n'a été produite.

Workflow :

1. Choisir le séparateur de colonnes (tabulation par défaut — couvre la plupart des exports Autolab / VersaSTAT / BioLogic) et le séparateur décimal.
2. Cliquer sur **Parcourir** (ou `⌘O`) — la boîte de dialogue `fileImporter` s'ouvre filtrée sur `.txt`.
3. Sélectionner le fichier. L'analyse **se lance automatiquement** en `async` (hors MainActor), et le graphe s'affiche dès qu'elle est terminée.
4. Examiner visuellement : signal brut (bleu α=0.5), signal lissé (orange), baseline (vert pointillé), signal corrigé (rouge), marqueur du pic (magenta).
5. Exporter le résultat via les boutons dédiés ou `⌘E` — `NSSavePanel` propose le format choisi.

Pour analyser un autre fichier : recliquer sur **Parcourir** — l'analyse précédente est remplacée.

> L'app fonctionne **App Sandbox désactivé** (accès libre au système de fichiers), mais le code traite quand même `startAccessingSecurityScopedResource()` pour pouvoir réactiver la sandbox sans modification.

---

## Résultats produits

### Visualisation

Le `Chart` SwiftUI superpose 4 `LineMark` plus un `RuleMark` + `PointMark` au pic corrigé. La palette suit `matplotlib.tab10` pour faciliter les comparaisons côte-à-côte avec les graphes Python d'origine.

### Exports

| Format | Contenu                                                                                          |
|--------|--------------------------------------------------------------------------------------------------|
| CSV    | 5 colonnes : `Potential`, `Current_raw`, `Current_smoothed`, `Baseline`, `Current_corrected`     |
| XLSX   | Mêmes 5 colonnes, sortie XLSX 100 % autonome (mini-ZIP + OOXML maison)                          |
| PNG    | Rendu via `ImageRenderer` (`@MainActor`, scale 2.0, 1600×1000) → TIFF → `NSBitmapImageRep` → PNG |

Tous les exports passent par un `NSSavePanel` (filtré sur l'extension cible).

---

## Chaîne de traitement par fichier

```
┌──────────────────────────┐
│ Fichier *.txt (entrée)   │
└────────────┬─────────────┘
             │ SWVFileReader.read()        ISO Latin-1, séparateurs configurables
             ▼
┌──────────────────────────┐
│ [VoltammetryPoint] brut  │
└────────────┬─────────────┘
             │ processData()               tri par potentiel, inversion du signe (-I)
             ▼
┌──────────────────────────┐
│ Signal nettoyé           │
└────────────┬─────────────┘
             │ SavitzkyGolay.apply()       window=11, polyorder=2, coeffs scipy
             ▼
┌──────────────────────────┐
│ Signal lissé             │
└────────────┬─────────────┘
             │ SignalProcessing.detectPeak()   marge 10 %, maxSlope=500
             ▼
┌───────────────────────────┐
│ (x_pic, y_pic) provisoires│
└────────────┬──────────────┘
             │ WhittakerASPLS.baseline()   asPLS, exclusion ±3 %, dgbsv_ banded
             ▼
┌──────────────────────────┐
│ Baseline estimée         │
└────────────┬─────────────┘
             │ signal_corrigé = signal_lissé - baseline
             ▼
┌──────────────────────────┐
│ Signal corrigé           │
└────────────┬─────────────┘
             │ SignalProcessing.detectPeak()   pic final
             ▼
┌──────────────────────────┐
│ VoltammetryAnalysis      │
└────────────┬─────────────┘
             │ @Observable → MainActor.run → SwiftUI Charts
             ▼
┌──────────────────────────┐
│ Vue interactive          │
└──────────────────────────┘
```

---

## Paramètres algorithmiques

Les hyperparamètres sont actuellement **codés en dur** dans le code Swift. Leur exposition dans l'interface graphique est prévue (voir [Feuille de route](#feuille-de-route)).

| Paramètre               | Valeur     | Rôle                                                                                         |
|-------------------------|------------|----------------------------------------------------------------------------------------------|
| `windowLength`          | `11`       | Largeur de la fenêtre Savitzky-Golay (nombre impair de points).                              |
| `polyorder`             | `2`        | Ordre du polynôme ajusté localement par Savitzky-Golay.                                      |
| `marginRatio`           | `0.10`     | Fraction de points exclus aux deux bords lors de la recherche du pic.                        |
| `maxSlope`              | `500`      | Pente absolue maximale tolérée pour un candidat-pic (filtre les fronts).                     |
| `exclusionWidthRatio`   | `0.03`     | Demi-largeur (fraction de la plage de potentiel) de la zone protégée autour du pic.          |
| `lambdaFactor`          | `1e3`      | Facteur multiplicatif du paramètre de lissage Whittaker : `lam = lambdaFactor · n²`.         |
| `diffOrder`             | `2`        | Ordre de différence dans l'ajustement Whittaker (matrice pentadiagonale).                    |
| `tol`                   | `1e-2`     | Tolérance de convergence asPLS (sur Δ poids, pas Δ baseline — comme pybaselines).            |
| `maxIter`               | `25`       | Nombre maximum d'itérations de réajustement des poids (boucle `0...maxIter`).                |
| `maxN`                  | `200 000`  | Nombre maximum de points accepté par le solveur asPLS (garde-fou anti-DoS).                  |

---

## Architecture du code

Source dans `voltapeak/` :

| Fichier                       | Rôle                                                                                                          |
|-------------------------------|---------------------------------------------------------------------------------------------------------------|
| `voltapeakApp.swift`          | `@main struct voltapeakApp: App` — `WindowGroup` 1000×700, `.hiddenTitleBar`, `CommandMenu("Analyse")` (⌘O, ⌘E). |
| `ContentView.swift`           | Vue principale SwiftUI : `fileImporter`, `NSSavePanel`, contrôles, `VoltammogramChartView` (`Charts`).        |
| `VoltapeakViewModel.swift`    | `@Observable class` — orchestre `analyzeFile(at:) async`, expose l'état (`isLoading`, `analysis`, `error`).   |
| `VoltammetryData.swift`       | Modèles : `VoltammetryPoint`, `VoltammetryAnalysis`, `SWVFileConfiguration` (enums `ColumnSeparator` / `DecimalSeparator`). |
| `SWVFileReader.swift`         | Lecture `.txt` (ISO Latin-1), `FileManager` + `String(contentsOf:encoding:)`, tri + inversion du signe, erreurs `FileError`. |
| `SavitzkyGolay.swift`         | 11 jeux de coefficients pré-calculés depuis `scipy.signal.savgol_coeffs(11, 2)` (bord gauche pos 0-4, centre pos 5, bord droit pos 6-10). Fallback moyenne glissante pour autres tailles. |
| `WhittakerASPLS.swift`        | `enum WhittakerASPLS` — port Swift de `pybaselines.whittaker.aspls`, matrice pentadiagonale `D^T D` en format LAPACK banded (KL=KU=2, LDAB=7), résolution via `dgbsv_` (Accelerate). |
| `SignalProcessing.swift`      | `detectPeak()` (marge + filtre de pente), `gradient()` (reproduit `numpy.gradient` pour pas non uniformes). Contient aussi une SG/asPLS simplifiée legacy (non utilisée). |
| `XLSXWriter.swift`            | Génération XLSX 100 % autonome : OOXML minimal + mini-ZIP store-only (méthode 0) + CRC32 PKZIP (polynôme `0xEDB88320`). |
| `Assets.xcassets/`            | `AccentColor`, `AppIcon` (PNG 16…1024 px).                                                                    |

Chaînage des appels (vue → ViewModel → services) :

```
voltapeakApp
 └── ContentView
      ├── Picker (séparateurs) → VoltapeakViewModel.config
      ├── Bouton Parcourir / ⌘O → fileImporter → VoltapeakViewModel.analyzeFile(at:) [async]
      │     ├── SWVFileReader.read(url:, config:)
      │     ├── SWVFileReader.processData(_:)            tri + inversion -I
      │     ├── SavitzkyGolay.apply(_:)
      │     ├── SignalProcessing.detectPeak(_:)          (signal lissé)
      │     ├── WhittakerASPLS.baseline(_:peakIndex:)    dgbsv_ banded LAPACK
      │     ├── SignalProcessing.detectPeak(_:)          (signal corrigé)
      │     └── await MainActor.run { self.analysis = … }
      ├── VoltammogramChartView (Charts)
      └── Boutons Export / ⌘E → NSSavePanel → CSV / XLSXWriter / ImageRenderer
```

---

## Tests

Suite **Swift `Testing`** (`import Testing`, syntaxe `@Suite` / `@Test` / `#expect`) — pas XCTest. Nécessite Xcode 26 / Swift 6.

| Fichier                          | Couverture |
|----------------------------------|------------|
| `SavitzkyGolayTests.swift`       | 7 tests : longueur préservée, signal constant / linéaire / quadratique (l'ordre 2 doit reproduire affine + quadratique), réduction de variance haute fréquence ≥10×, signal court, déterminisme. |
| `WhittakerASPLSTests.swift`      | 6 tests : longueur préservée, signal constant / linéaire (intérieur tol 5e-2), gaussien (résidu > 1 sur pic d'amplitude 5, baseline ≈ vraie ligne loin du pic), signal court, déterminisme. |
| `SignalProcessingTests.swift`    | 5 tests : SG legacy, `detectPeak` sur gaussienne, respect de la marge (ignore pic en zone exclue), `calculateBaseline` finitude + longueur, exclusion contient bien le pic. |
| `TestHelpers.swift`              | Helpers : `linspace`, `gaussian`, `expectArrayApproxEqual`, `variance` (correction de Bessel). |

Exécution :

```bash
xcodebuild test \
  -scheme voltapeak \
  -destination 'platform=macOS'
```

---

## CI/CD

| Workflow              | Déclencheur                | Action                                      | Artefact                    |
|-----------------------|----------------------------|---------------------------------------------|-----------------------------|
| `swift.yml`           | `push` / `pull_request` sur `main` | `xcodebuild clean build analyze` + `xcodebuild test` (Debug, macOS) sur runner `macos-26`, sortie `xcpretty` | Statut CI (pas d'artefact) |
| `build-artifact.yml`  | `push` sur `main`, `workflow_dispatch` | `xcodebuild archive` Release **non signé** (`CODE_SIGN_IDENTITY="-"`) | `voltapeak-unsigned-<sha>` (`.app` via `actions/upload-artifact@v4`) |
| `release.yml`         | tag `v*` ou `[0-9]*`       | `xcodebuild archive` + `ditto` → zip + `gh release create --generate-notes` | `voltapeak-<TAG>.zip` (release GitHub) |

> Les `.app` produites sont **ad-hoc signed** (`CODE_SIGN_IDENTITY="-"`) — ni signature Developer ID, ni notarisation. Au premier lancement, Gatekeeper bloque : faire un clic droit → *Ouvrir*, puis confirmer.

---

## Algorithmes & références

- **Savitzky-Golay** : implémentation Swift native avec **coefficients pré-calculés** depuis `scipy.signal.savgol_coeffs(window_length=11, polyorder=2)`. Les 11 jeux de coefficients (bord gauche pos 0-4, centre symétrique pos 5, bord droit pos 6-10) reproduisent `mode='interp'` de scipy **bit-pour-bit** sur le cas (11, 2).
- **Whittaker asPLS** (*Adaptive Smoothness Penalized Least Squares*) : port Swift de [`pybaselines.whittaker.aspls`](https://pybaselines.readthedocs.io/en/latest/api/whittaker/index.html#pybaselines.whittaker.aspls), résolu par un solveur **LAPACK banded `dgbsv_`** (Accelerate, KL=KU=2, LDAB=7) en O(n) — au lieu de O(n³) d'un Gauss dense — ce qui rend tractable des signaux jusqu'à 200 000 points. Itération `0...maxIter` (reproduction de `range(max_iter+1)` Python), convergence sur Δ poids (et non Δ baseline), mise à jour sigmoïde `expit(-(k/σ)·(r-σ))` avec `σ = std(résidus négatifs, ddof=1)`, `α[i] = |r[i]| / max|r|`.
  - Référence : Zhang, F., et al. (2020). *Baseline correction for Raman spectra using an improved asymmetric least squares method.*

Les détails d'implémentation (paramètres, garde-fous, conventions de signe) sont préservés à l'identique entre les 3 applications Swift et leurs origines Python.

---

## Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| Alerte « Fichier non lisible » avec bouton *Aide* | Encodage UTF-8 alors que l'app attend ISO Latin-1 | Convertir l'encodage en amont (`iconv -f UTF-8 -t ISO-8859-1 fichier.txt > fichier.iso.txt`). |
| Alerte « Trop peu de points » | Moins de ~11 lignes de données après filtrage | Vérifier que le séparateur de colonnes est correct (sinon tout est lu comme une seule colonne). |
| Graphique vide ou ligne horizontale | Mauvais séparateur décimal (toute la colonne courant lue à 0) | Basculer entre *Point* et *Virgule*. |
| Pic « inversé » ou détecté loin du sommet visible | Fichier avec pic déjà en courant positif (orientation anodique) | Pré-inverser la colonne courant — le pipeline attend une convention cathodique (cf. [Format des fichiers d'entrée](#format-des-fichiers-dentrée)). |
| Alerte « Trop de points » (`FileError.tooManyPoints`) | Fichier > 200 000 lignes (garde-fou anti-DoS asPLS) | Décimer le signal en amont. |
| Premier lancement bloqué par Gatekeeper | `.app` non signée Developer ID | Clic droit sur l'app → *Ouvrir* → confirmer. |
| Pic marqué clairement décalé du sommet visible | Filtre de pente `maxSlope=500` trop strict, fronts détectés | Exposition de `maxSlope` dans l'UI prévue en feuille de route. |
| Bouton d'erreur *Aide* | L'alerte pointe vers la doc App Sandbox Apple — utile si la sandbox a été réactivée et bloque l'accès au fichier choisi. |  |

---

## Feuille de route

Voir [`ROADMAP.md`](ROADMAP.md) pour l'ensemble des évolutions prévues (à venir : exposition des hyperparamètres dans l'UI, signature Developer ID, etc.).

---

## Licence et auteur

- **Auteur** : Stéphane Cadinot ([@scadinot](https://github.com/scadinot)).
- **Licence** : [MIT](LICENSE) — Copyright (c) 2026 Stéphane Cadinot.

Pour toute question ou contribution, ouvrir une *issue* sur le dépôt GitHub.
