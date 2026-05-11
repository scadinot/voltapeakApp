# Validation numérique

Ce document décrit la méthodologie utilisée pour valider que le port Swift reproduit la référence Python à la 6ᵉ décimale, et résume les bugs identifiés/corrigés au cours du processus.

## Méthodologie : compare-and-fix itératif

Pour chaque méthode du pipeline Python, on a procédé en 5 étapes :

1. **Inventaire** : identifier le mapping Python → Swift (fonction, fichier, ligne)
2. **Logging** : insérer des snippets `print(...)` aux mêmes points en Python et Swift, **avec un format strictement identique** :
   ```
   === <method> DEBUG (Python|Swift) ===
   first5    : [...]
   last5     : [...]
   stats     : min=... max=... sum=...
   <params spécifiques à la méthode>
   ===
   ```
3. **Exécution** : lancer les deux pipelines sur le même fichier d'entrée (`BT16Mb-T16TAC_04_SWV_C08.txt`, n=85 points)
4. **Diff** : comparer visuellement les blocs de logs côte à côte
5. **Correction** : si divergence, patcher le Swift, supprimer les debug, passer à la méthode suivante. Sinon, supprimer les debug et passer à la suivante.

Le fichier d'entrée contient 85 paires (potentiel, courant) avec un pic anodique attendu autour de −0.273 V.

## Pipeline validé étape par étape

| # | Méthode Python | Équivalent Swift | Statut |
|---|---|---|---|
| 1 | `readFile` | `SWVFileReader.readFile` | ✅ bit-exact (sum bit-exact, Swift filtre les zéros en amont sans impact) |
| 2 | `processData` | `SWVFileReader.processData` | ✅ bit-exact |
| 3 | `smoothSignal` | `SavitzkyGolay.filter` | ✅ bit-exact **après fix** |
| 4 | `getPeakValue` | `SignalProcessing.detectPeak` | ✅ bit-exact **après fix** |
| 5 | `calculateSignalBaseLine` | `WhittakerASPLS.aspls` + orchestration ViewModel | ✅ bit-exact **après réécriture complète** |
| 6 | `plotSignalAnalysis` | `VoltammogramChartView` | ✅ parité visuelle (couleurs matplotlib, domaines contraints) |
| 7 | `processAndPlotSingleFile` | `VoltapeakViewModel.analyzeFile` | ✅ orchestration équivalente |

## Métriques finales

| Métrique | Python | Swift | Écart |
|---|---|---|---|
| n (points) | 85 | 85 | 0 |
| Pic position | −0.273108 V | −0.273108 V | 0 |
| Pic amplitude | 6.932097 mA | 6.932097 mA | 0 |
| Itérations asPLS | 9 | 9 | 0 |
| Baseline min | 6.046788e-03 A | 6.046788e-03 A | 0 |
| Baseline max | 6.362728e-03 A | 6.362728e-03 A | 0 |
| Baseline sum | 5.297770e-01 | 5.297770e-01 | 0 |

**Tous les champs sortants** des 5 fonctions numériques matchent à la 6ᵉ décimale entre Python et Swift sur ce fichier de référence.

## 10 bugs corrigés au cours de la validation

### Lissage Savitzky-Golay

| # | Bug | Localisation | Symptôme |
|---|---|---|---|
| 1 | Coefficients centraux invalides (somme = 1.244 ≠ 1.0) | `SavitzkyGolaySimple.swift` | Signal lissé multiplié par ~1.24 partout |
| 2 | Extrapolation linéaire aux bords au lieu de mode `'interp'` scipy | `SavitzkyGolaySimple.swift` | 5 premiers et 5 derniers points lissés très divergents |

### Détection de pic

| # | Bug | Localisation | Symptôme |
|---|---|---|---|
| 3 | Gradient simple `(y[i+1]−y[i−1])/(x[i+1]−x[i−1])` au lieu de la formule numpy 2ᵉ ordre non-uniforme | `SignalProcessing.gradient` | Slopes divergents à la 4ᵉ décimale (sans impact pic ici, mais incorrect) |

### Baseline asPLS — fondamentalement faux

| # | Bug | Localisation | Symptôme |
|---|---|---|---|
| 4 | **Mauvais algorithme** : `w = p si y>z, 1−p sinon` (Eilers asLS) implémenté à la place de `pybaselines.whittaker.aspls` | `WhittakerASPLS.aspls` (ancien) | Baseline traverse le pic, résultat ~5.4 mA au lieu de 6.93 mA (22 % d'écart) |
| 5 | Pas de vecteur α (adaptive smoothness) | `WhittakerASPLS.aspls` | Pénalité uniforme partout — pas d'effet adaptatif Zhang |
| 6 | Convergence sur la baseline au lieu des poids | `WhittakerASPLS.aspls` | Critère d'arrêt différent → nombre d'itérations différent |
| 7 | `lam = 1e6` constant au lieu de `lam = 1e3 × n²` | `VoltapeakViewModel` | Lissage ne s'adapte pas à la densité d'échantillonnage |
| 8 | `weights = nil` passé à `aspls` au lieu d'un vecteur avec zone d'exclusion à 0.001 dans `[xPeak ± 0.03·range]` | `VoltapeakViewModel` | Le pic « tirait » la baseline vers le haut |
| 9 | `tol = 1e-3`, `maxIter = 50` (au lieu de `1e-2`, `25` du Python) | `VoltapeakViewModel` | Sur-convergence, plus d'itérations que Python |
| 10 | `p = 0.01` (asymétrie asLS) au lieu d'`asymmetric_coef = 0.5` (k de asPLS) | `VoltapeakViewModel` | Confusion entre deux algorithmes pourtant nommés similairement |

## Résultats : avant / après

| Métrique | Avant fix (asLS déguisé) | Après fix (asPLS Zhang) | Cible Python |
|---|---|---|---|
| Pic amplitude | ~5.4 mA | **6.932 mA** | 6.93 mA |
| Convergence | ~3 itérations | **9 itérations** | 9 itérations |
| Baseline tendance | quasi linéaire | légère courbure réaliste | identique |
| Erreur relative | ~22 % | **< 0.05 %** | — |

## Comment reproduire

### Préparer le fichier de test

Le fichier `BT16Mb-T16TAC_04_SWV_C08.txt` doit être chargé dans les deux applications. Format attendu :

```
[Entête potentiostat]
-0.150183	-1.886996e-02
-0.150183	0.000000e+00
-0.153131	0.000000e+00
-0.153131	-7.658059e-03
...
```

(170 lignes au total, dont 85 avec courant non nul = signal utile.)

### Injecter les snippets debug

Pour chaque méthode à valider, ajouter avant le `return` :

**Python (`__main__.py`)** :
```python
print(f"=== <method> DEBUG (Python) ===")
print(f"first5 : {[f'{v:.6e}' for v in output[:5]]}")
print(f"last5  : {[f'{v:.6e}' for v in output[-5:]]}")
print(f"stats  : min={output.min():.6e} max={output.max():.6e} sum={output.sum():.6e}")
```

**Swift (méthode correspondante)** :
```swift
print("=== <method> DEBUG (Swift) ===")
print("first5 : \(output.prefix(5).map { String(format: \"%.6e\", $0) })")
print("last5  : \(output.suffix(5).map { String(format: \"%.6e\", $0) })")
print("stats  : min=\(...) max=\(...) sum=\(...)")
```

### Lancer et comparer

1. Python : `python -m voltapeak`, charger le fichier, lire la console
2. Swift : Xcode ⌘R, charger le fichier, lire la console Xcode
3. Diff visuel des deux blocs de logs

### Critère de bit-exact

Tous les champs (`first5`, `last5`, `stats`) doivent matcher à la 6ᵉ décimale. Si l'un diverge :
- Analyser l'algorithme correspondant
- Patcher le Swift
- Relancer
- Une fois bit-exact, retirer les debug et passer à la méthode suivante

## État de la validation

✅ **Toutes les méthodes numériques validées bit-exact** sur le fichier de référence.

⚠️ **Limitations connues** :
- La validation est faite **sur un seul fichier** de référence. D'autres fichiers SWV pourraient révéler des cas particuliers (n très petit/grand, signal très bruité, pic en bord, etc.)
- Pas de tests unitaires automatisés à ce jour — la validation est manuelle/interactive
- Précision en virgule flottante : les écarts sub-10⁻⁶ ne sont pas distingués (la `print` debug formate à 6 décimales)
