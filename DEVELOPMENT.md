# Guide développeur

Ce document est le guide développeur de `voltapeakApp`. Pour la
**méthodologie de validation** (comment vérifier la parité bit-exact avec
la référence Python), voir [VALIDATION.md](VALIDATION.md). Pour les
**détails algorithmiques** (Savitzky-Golay, asPLS, etc.), voir
[ALGORITHMS.md](ALGORITHMS.md).

`voltapeakApp` est la **référence canonique** des fonctions d'analyse de
la famille `voltapeak*` ; toute modification d'algorithme doit être
propagée ensuite vers
[`voltapeak_batchApp`](https://github.com/scadinot/voltapeak_batchApp) et
[`voltapeak_loopsApp`](https://github.com/scadinot/voltapeak_loopsApp).

## Prérequis

| Outil | Version |
|---|---|
| **macOS** | 14.0+ (Sonoma) |
| **Xcode** | 15.0+ |
| **Python** (uniquement pour validation) | 3.11+ avec `numpy`, `scipy`, `pybaselines`, `pandas`, `matplotlib` |

Toutes les bibliothèques Swift utilisées proviennent du SDK macOS
(SwiftUI, Charts, Foundation, AppKit, UniformTypeIdentifiers,
Observation). **Aucun Swift Package Manager.**

## Build et lancement

```bash
git clone https://github.com/scadinot/voltapeakApp.git
cd voltapeakApp
open voltapeak.xcodeproj
# ⌘R pour compiler et lancer
```

En ligne de commande :

```bash
xcodebuild -project voltapeak.xcodeproj \
           -scheme voltapeak \
           -configuration Release \
           build
```

### Resets utiles

| Symptôme | Action |
|---|---|
| Code modifié mais comportement inchangé | Product → Clean Build Folder (⌘⇧K) |
| Icône Dock incorrecte / placeholder blanc | Supprimer `~/Library/Developer/Xcode/DerivedData/voltapeak-*` |
| Permissions sandbox cassées (fichier introuvable) | Vérifier Signing & Capabilities → App Sandbox → User Selected File (Read Only) |
| Erreurs assets / warnings xcassets | Vérifier `Assets.xcassets/AppIcon.appiconset/Contents.json` (10 entrées mac uniquement) |

## Structure du projet

Voir [ARCHITECTURE.md](ARCHITECTURE.md) pour la vue d'ensemble.

```
voltapeak/
├── README.md
├── ARCHITECTURE.md
├── ALGORITHMS.md
├── VALIDATION.md
├── DEVELOPMENT.md       # ce fichier
├── DISTRIBUTION.md
├── CHANGELOG.md
├── .gitignore
├── voltapeak.xcodeproj/ # projet Xcode
└── voltapeak/           # sources Swift + assets
    ├── *.swift          # 9 fichiers core
    └── Assets.xcassets/ # AppIcon + AccentColor
```

## Conventions de code

| Aspect | Convention |
|---|---|
| Langue commentaires / UI | **Français** |
| Indentation | 4 espaces |
| Casing types | `PascalCase` |
| Casing fonctions / variables | `camelCase` |
| Constantes statiques | `camelCase` (Swift style, pas SCREAMING_CASE) |
| Organisation interne | Sections `// MARK: - Section` pour la navigation Xcode |
| Documentation d'API | Triple-slash `///` avec balises `- Parameters`, `- Returns`, `- Throws` |
| Acronymes scientifiques | Conservés en minuscules : `aspls`, `savgol`, etc. |

Les fichiers Swift sont écrits en français pour la cohérence avec l'UI et
les commentaires existants. C'est un projet francophone assumé.

## Ajouter une fonctionnalité

### Exemple : ajouter un nouvel export (PDF, PNG, etc.)

1. **Modèle** : aucune modification de `VoltammetryData.swift` nécessaire
   (les données sont déjà là).
2. **ViewModel** (`VoltapeakViewModel.swift`) : ajouter une méthode
   `exportToXXX() -> Data?` qui sérialise `currentAnalysis`.
3. **UI** (`ContentView.swift`) :
   - Ajouter un bouton dans la `toolbarSection` (mimer le pattern
     `exportCSV`/`exportXLSX`).
   - Ajouter une fonction `private func exportXXX()` avec `NSSavePanel`.
   - Définir un `UTType` adapté (ou utiliser un type prédéfini comme
     `.pdf`).
4. **Test manuel** : ⌘R, charger un fichier, cliquer le nouveau bouton,
   vérifier le fichier produit.

### Exemple : changer un paramètre d'algorithme

Les paramètres scientifiques sont hardcodés dans
`VoltapeakViewModel.analyzeFile` :

```swift
let lambdaFactor = 1e3
let lam = lambdaFactor * Double(n * n)
let exclusionWidthRatio = 0.03
// ...
WhittakerASPLS.aspls(
    y: smoothed,
    lam: lam,
    diffOrder: 2,
    maxIter: 25,
    tol: 1e-2,
    weights: initialWeights
)
```

Pour les rendre configurables dynamiquement :
- Étendre `SWVFileConfiguration` avec des champs `lambdaFactor`, `tol`,
  `maxIter`.
- Ajouter une section "Paramètres avancés" dans `configurationSection`.
- Passer `viewModel.config.lambdaFactor` au lieu de `1e3`.

## Mise à jour des fonctions d'analyse

`voltapeakApp` est la **source de vérité** des fonctions d'analyse. Toute
modification numérique se fait ici en premier, validée bit-exact contre
la référence Python (cf. [VALIDATION.md](VALIDATION.md)), puis propagée :

1. Modifier `SavitzkyGolay.swift`, `WhittakerASPLS.swift`,
   `SignalProcessing.swift`, `SWVFileReader.swift` ou
   `VoltammetryData.swift` selon le besoin.
2. Re-vérifier la parité Python via les snippets de debug
   (cf. [VALIDATION.md](VALIDATION.md) § « Comment reproduire »).
3. Propager le fichier modifié tel quel vers
   [`voltapeak_batchApp/voltapeak_batch/`](https://github.com/scadinot/voltapeak_batchApp)
   et
   [`voltapeak_loopsApp/voltapeak_loops/`](https://github.com/scadinot/voltapeak_loopsApp)
   (la version `loops` ajoute uniquement `Sendable`).
4. Ajouter une entrée dans [CHANGELOG.md](CHANGELOG.md) de chaque repo.

## Débugger

### Méthodologie compare-and-fix (validée pour le portage)

Voir [VALIDATION.md](VALIDATION.md). Résumé :

1. Insérer `print(...)` aux mêmes points dans Python et Swift, **même
   format de sortie**.
2. Lancer les deux pipelines sur le même fichier.
3. Diff visuel des blocs de log.
4. Si divergence, patcher Swift, relancer.

C'est la méthode utilisée pour identifier les 10 bugs corrigés lors du
portage.

### Logs console Xcode

Le `VoltapeakViewModel.analyzeFile` émet déjà des `print` à chaque étape
avec emojis :

```
📖 Fichier lu : 85 points
📊 Données traitées
🔄 Signal lissé
🎯 Pic brut détecté
📉 Calcul baseline asPLS
   asPLS convergé après 9 itérations (max=26)
✅ Signal corrigé
🎯 Pic corrigé détecté : -0.27310833 V, 6.932097255347445 mA
```

Visible dans la console Xcode lors du run (View → Debug Area → Show
Debug Area).

### Inspection des données

Pour examiner un tableau intermédiaire (signal lissé, baseline, etc.) :

```swift
print("smoothed.count = \(smoothed.count)")
print("smoothed[0..5] = \(smoothed.prefix(5))")
print("smoothed stats : min=\(smoothed.min()!), max=\(smoothed.max()!), sum=\(smoothed.reduce(0,+))")
```

Format précis avec `String(format: "%.6e", v)` pour la comparaison Python.

## Tests

**État actuel** : aucun test unitaire automatisé. La validation a été
faite manuellement via la méthodologie compare-and-fix (voir
[VALIDATION.md](VALIDATION.md)).

**Dette technique consciente.** Pistes pour ajouter des tests :

1. **Tests unitaires algorithmiques** (priorité haute) :
   - Vérifier la somme des coefficients SG (= 1.0).
   - Vérifier la convergence asPLS sur un signal synthétique (gaussienne
     + bruit + dérive linéaire).
   - Vérifier le gradient numpy sur un cas analytique.
2. **Tests d'intégration** :
   - Charger un fichier de test fixe → vérifier que le pic final est
     `−0.273 V ± ε, 6.932 mA ± ε`.
3. **Tests UI** : moins prioritaires car SwiftUI Charts a son propre
   rendu.

Pour démarrer : créer une cible `voltapeakTests` dans Xcode, framework
XCTest.

## Limitations connues

| Limitation | Conséquence | Workaround |
|---|---|---|
| Pas de toolbar zoom/pan sur le chart | Vue figée au domaine du fichier | Aucun — limitation SwiftUI Charts |
| Pas d'export PNG/PDF du graphique | Impossible de sauvegarder une figure | Capture d'écran (⇧⌘4), ou utiliser [`voltapeak_batchApp`](https://github.com/scadinot/voltapeak_batchApp) qui rend en PNG 300 dpi |
| Un fichier à la fois | Pas de traitement batch | Voir [`voltapeak_batchApp`](https://github.com/scadinot/voltapeak_batchApp) ou [`voltapeak_loopsApp`](https://github.com/scadinot/voltapeak_loopsApp) |
| Paramètres scientifiques hardcodés | Pas d'ajustement fin via UI | Modifier `VoltapeakViewModel.analyzeFile` |
| `lambdaFactor = 1e3` empirique | Inadapté pour des datasets très différents de SWV typique (~85 points) | Modifier dans le code |
| Pas de validation Numbers app | Excel/Numbers ouvrent bien le .xlsx mais comportement non testé exhaustivement | Tester sur ses fichiers métier |
| Mode `'interp'` SG limité à window=11 | Pour window ≠ 11, fallback simple (moyenne mobile) | Étendre `boundaryCoeffs` |

## Ressources externes

- [Apple SwiftUI documentation](https://developer.apple.com/documentation/swiftui)
- [Apple Charts framework](https://developer.apple.com/documentation/charts)
- [scipy.signal documentation](https://docs.scipy.org/doc/scipy/reference/signal.html)
- [pybaselines repo](https://github.com/derb12/pybaselines)
- [Zhang et al. 2020 paper (asPLS)](https://www.tandfonline.com/doi/full/10.1080/00387010.2020.1734588)
- [`voltapeak_batchApp`](https://github.com/scadinot/voltapeak_batchApp) — variante batch multi-électrodes
- [`voltapeak_loopsApp`](https://github.com/scadinot/voltapeak_loopsApp) — variante batch loops/dosage hiérarchique
