# Architecture

## Pipeline

Le cœur fonctionnel de Voltapeak est une chaîne de 7 étapes, orchestrée par `VoltapeakViewModel.analyzeFile(at:)` :

```
┌──────────────┐   ┌─────────────┐   ┌──────────────┐   ┌──────────────┐
│ 1. Lire .txt │ → │ 2. Process  │ → │ 3. Lisser    │ → │ 4. Pic brut  │
│  (latin-1)   │   │ (tri, signe)│   │  (SG scipy)  │   │  (margin+slp)│
└──────────────┘   └─────────────┘   └──────────────┘   └──────────────┘
                                                                │
                                                                ▼
┌──────────────┐   ┌─────────────┐   ┌──────────────┐   ┌──────────────┐
│ 8. Affichage │ ← │ 7. Pic final│ ← │ 6. Corriger  │ ← │ 5. Baseline  │
│ (SwiftUI)    │   │  (re-detect)│   │ (lissé − bl) │   │ (asPLS Zhang)│
└──────────────┘   └─────────────┘   └──────────────┘   └──────────────┘
```

Détails numériques de chaque étape dans [ALGORITHMS.md](ALGORITHMS.md).

## Fichiers Swift core

| Fichier | Rôle | Symboles publics |
|---|---|---|
| `voltapeakApp.swift` | Entry point `@main`, fenêtre principale, menu macOS | `voltapeakApp` |
| `ContentView.swift` | UI principale (toolbar, configuration, chart, file picker, export) | `ContentView`, `VoltammogramChartView`, `LegendItem` |
| `VoltapeakViewModel.swift` | Orchestration du pipeline, état de l'analyse, export CSV/XLSX | `VoltapeakViewModel` (`@Observable`) |
| `VoltammetryData.swift` | Modèles de données partagés | `VoltammetryPoint`, `VoltammetryAnalysis`, `SWVFileConfiguration` |
| `SWVFileReader.swift` | Lecture et parsing du fichier `.txt` SWV | `SWVFileReader` (méthodes `readFile`, `processData`) |
| `SavitzkyGolay.swift` | Filtre de lissage Savitzky-Golay scipy-exact (window=11, ordre=2) | `SavitzkyGolay.filter(_:windowLength:polynomialOrder:)` |
| `SignalProcessing.swift` | Détection de pic + gradient numpy 2ᵉ ordre non-uniforme | `SignalProcessing.detectPeak(signal:potentials:marginRatio:maxSlope:)` |
| `WhittakerASPLS.swift` | Algorithme asPLS Zhang 2020 (α adaptatif, sigmoïde, exclusion) | `WhittakerASPLS.aspls(...)` |
| `XLSXWriter.swift` | Génération de fichiers `.xlsx` (mini-ZIP store-only + XML OOXML) | `XLSXWriter.write(analysis:potentials:rawCurrents:)` |

**9 fichiers Swift au total.** Aucun fichier de test pour le moment.

## Dépendances

### Frameworks Apple (SDK)

| Framework | Utilisation |
|---|---|
| `SwiftUI` | UI déclarative |
| `Charts` | Graphique du voltampérogramme |
| `Foundation` | Types de base, `URL`, `Data`, `String` |
| `AppKit` (`NSSavePanel`, `NSWorkspace`) | Boîtes de dialogue natives macOS |
| `UniformTypeIdentifiers` | Types MIME pour file importer / save panel |
| `Observation` (macro `@Observable`) | Réactivité ViewModel → UI |

### Dépendances externes

**Aucune.** Pas de Swift Package Manager, pas de CocoaPods, pas de Carthage. Tous les algorithmes scientifiques sont implémentés directement à partir des spécifications mathématiques.

L'export `.xlsx` est généré **sans bibliothèque tierce** : le `XLSXWriter` implémente un mini-ZIP store-only (compression method = 0) en pur Swift, avec calcul CRC32 PKZIP, suffisant pour produire un OOXML valide.

## Modèles de données

```swift
struct VoltammetryPoint: Identifiable {
    let id = UUID()
    let potential: Double  // volts
    let current: Double    // ampères
}

struct VoltammetryAnalysis {
    let rawData: [VoltammetryPoint]
    let smoothedSignal: [Double]
    let baseline: [Double]
    let correctedSignal: [Double]
    let peakPotential: Double
    let peakCurrent: Double
    let fileName: String
}

struct SWVFileConfiguration {
    var columnSeparator: ColumnSeparator = .tab    // \t , ; espace
    var decimalSeparator: DecimalSeparator = .point // . ou ,
    var encoding: String.Encoding = .isoLatin1
}
```

## Choix de design

### Réactivité : `@Observable` plutôt que `ObservableObject`

Le ViewModel utilise la nouvelle macro `@Observable` (iOS 17 / macOS 14) qui :
- Évite `@Published` sur chaque propriété
- Réduit le boilerplate
- Permet une observation granulaire automatique

```swift
@Observable
class VoltapeakViewModel {
    var currentAnalysis: VoltammetryAnalysis?
    var isProcessing = false
    // ...
}
```

### MainActor isolation pour les MAJ d'UI

`analyzeFile(at:)` est `async`, le travail lourd s'exécute hors du main thread. Les mutations d'état observées sont remontées dans `await MainActor.run { ... }` pour garantir un rendu cohérent.

### File picker : `.fileImporter` plutôt que `NSOpenPanel`

`ContentView` utilise `.fileImporter` (SwiftUI natif) plutôt que d'invoquer directement `NSOpenPanel`. Avantages :
- Intégration sandbox automatique (security-scoped resource)
- API déclarative

L'export en revanche utilise `NSSavePanel` (AppKit) car `.fileExporter` SwiftUI a des limitations connues (notamment pour des données binaires comme `.xlsx`).

### Export `.xlsx` sans dépendance

`XLSXWriter.swift` (~220 lignes) construit :
1. Les 5 fichiers XML OOXML minimaux (`[Content_Types].xml`, `_rels/.rels`, `xl/workbook.xml`, `xl/_rels/workbook.xml.rels`, `xl/worksheets/sheet1.xml`)
2. Un conteneur ZIP store-only (compression method = 0) avec signatures `PK\003\004` (Local File Header), `PK\001\002` (Central Directory), `PK\005\006` (End of Central Directory)
3. CRC32 PKZIP (polynôme inversé `0xEDB88320`)

Le fichier produit est ouvert sans warning par Excel, Numbers, Google Sheets et LibreOffice.

## Compatibilité

- **macOS 14.0+** (Sonoma) — exigé par `Charts` framework et `@Observable`
- **Architectures** : Universal (Intel x86_64 + Apple Silicon arm64)
- **App Sandbox** activé avec entitlement `com.apple.security.files.user-selected.read-only`

## Hors-scope (volontairement)

- Pas de gestion batch (un fichier à la fois)
- Pas de toolbar zoom/pan sur le chart (SwiftUI Charts n'en fournit pas nativement)
- Pas d'export PNG/PDF du graphique
- Pas de tests unitaires (dette technique consciente)
- Pas de monitoring temps réel (les fichiers `VoltageMonitor*` du template Xcode initial ont été supprimés)
