# voltapeakApp — analyse SWV (macOS / Swift)

**Application macOS native (SwiftUI) d'analyse de voltampérogrammes SWV
(Square Wave Voltammetry).** Portage bit-exact (à la 6ᵉ décimale) depuis
l'outil Python d'origine.

`voltapeakApp` est la **référence canonique** des fonctions d'analyse SWV
de la famille `voltapeak*` : Savitzky-Golay scipy-exact, détection de pic,
asPLS Zhang 2020. Les applications batch
[`voltapeak_batchApp`](https://github.com/scadinot/voltapeak_batchApp) et
[`voltapeak_loopsApp`](https://github.com/scadinot/voltapeak_loopsApp)
reprennent ces fonctions sans modification et ajoutent leur orchestration
multi-fichiers.

## Famille de projets

| Repo | Rôle |
|---|---|
| [`voltapeakApp`](https://github.com/scadinot/voltapeakApp) | **App GUI mono-fichier**, référence canonique des algorithmes *(ce repo)* |
| [`voltapeak_batchApp`](https://github.com/scadinot/voltapeak_batchApp) | App batch multi-fichiers avec **agrégation multi-électrodes** |
| [`voltapeak_loopsApp`](https://github.com/scadinot/voltapeak_loopsApp) | App batch multi-fichiers avec **agrégation loops/dosage hiérarchique** |

## Statut

✅ **Pipeline numérique bit-exact avec la référence Python** (à la 6ᵉ décimale).
Pic corrigé sur le fichier de validation `BT16Mb-T16TAC_04_SWV_C08.txt` :
**−0.273 V, 6.932 mA** (cible Python : 6.93 mA).

Méthodologie + bugs corrigés : voir [VALIDATION.md](VALIDATION.md).

## À quoi sert cet outil ?

Lors d'expériences de voltampérométrie à onde carrée, on mesure un courant
en fonction du potentiel. Le signal utile — un pic centré sur le potentiel
caractéristique de l'espèce électroactive — est superposé à une **ligne de
base** lentement variable. L'analyse quantitative nécessite donc de
soustraire cette ligne de base pour ne garder que le pic.

`voltapeakApp` charge un fichier `.txt` produit par un potentiostat, lisse
le signal, détecte le pic, estime la baseline par asPLS et soustrait
celle-ci pour obtenir le courant net du pic. L'interface SwiftUI native
macOS permet d'inspecter visuellement chaque étape du pipeline et
d'exporter les résultats.

## Fonctionnalités

- Chargement de fichiers `.txt` SWV avec séparateurs configurables (tabulation, virgule, point-virgule, espace ; décimale point ou virgule)
- Lissage Savitzky-Golay (coefficients scipy exacts, fenêtre 11, ordre 2, bords `'interp'`)
- Détection de pic robuste (margin 10 %, filtre de pente)
- Baseline asPLS (algorithme Zhang 2020 complet : α adaptatif, poids sigmoïdaux, zone d'exclusion)
- Visualisation interactive (SwiftUI Charts, couleurs alignées sur matplotlib **tab10**)
- Export **CSV** et **Excel `.xlsx`** (générateur xlsx autonome, aucune dépendance)

## Prérequis

- **macOS 14** ou supérieur (framework `Charts`)
- **Xcode 15** ou supérieur
- Aucune dépendance Swift Package Manager — toutes les bibliothèques utilisées (SwiftUI, Charts, Foundation, AppKit, UniformTypeIdentifiers) sont fournies par le SDK.

## Build et lancement

### Depuis Xcode

```bash
git clone https://github.com/scadinot/voltapeakApp.git
cd voltapeakApp
open voltapeak.xcodeproj
# ⌘R pour compiler et lancer
```

### Depuis la ligne de commande

```bash
xcodebuild -project voltapeak.xcodeproj \
           -scheme voltapeak \
           -configuration Release \
           build
```

## Utilisation

1. **Ouvrir un fichier `.txt`** via le bouton *Parcourir*.
2. Régler le séparateur de colonnes et la décimale dans le panneau de configuration.
3. Le pipeline s'exécute automatiquement : signal brut → lissage → détection de pic → baseline asPLS → signal corrigé.
4. Inspecter visuellement les 4 courbes superposées (brut, lissé, baseline, corrigé) + marqueur du pic.
5. Exporter en **CSV** ou **XLSX** depuis le menu *Fichier*.

## Paramètres de l'algorithme

Identiques aux deux applications batch de la famille — détails mathématiques
dans [ALGORITHMS.md](ALGORITHMS.md) :

| Paramètre | Valeur | Rôle |
|---|---|---|
| `windowLength` (Savitzky-Golay) | **11** | largeur de la fenêtre de lissage |
| `polynomialOrder` (Savitzky-Golay) | **2** | ordre du polynôme local |
| `marginRatio` | **0,10** | fraction des bords exclue pour la détection de pic |
| `maxSlope` | **500** (`nil` pour désactiver) | plafond de pente `|dI/dV|` |
| `exclusionWidthRatio` | **0,03** | demi-largeur d'exclusion asPLS (fraction de l'étendue) |
| `lambdaFactor` | **1 000** | rigidité de la baseline : λ effectif = `lambdaFactor · n²` |
| `diffOrder` (asPLS) | **2** | ordre de la différence pénalisée |
| `tol` (asPLS) | **1e-2** | tolérance de convergence (sur les poids) |
| `maxIter` (asPLS) | **25** | nombre maximal d'itérations |
| `asymmetricCoef` (asPLS) | **0,5** | coefficient `k` du papier asPLS |

## Documentation complémentaire

| Document | Contenu |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Structure du projet, pipeline, fichiers Swift, modèles de données, concurrence |
| [ALGORITHMS.md](ALGORITHMS.md) | Algorithmes numériques (Savitzky-Golay, détection de pic, asPLS Zhang 2020) |
| [VALIDATION.md](VALIDATION.md) | Méthodologie de validation, parité avec la référence Python |
| [DEVELOPMENT.md](DEVELOPMENT.md) | Guide développeur : build, debug, conventions, ajout de features |
| [DISTRIBUTION.md](DISTRIBUTION.md) | Signature, notarisation Apple, création de DMG, CI |
| [CHANGELOG.md](CHANGELOG.md) | Historique des versions (Keep-a-Changelog) |

## Crédits & licence

Algorithmes — portages directs des bibliothèques Python de référence :

- **scipy** (`scipy.signal.savgol_filter`) — lissage Savitzky-Golay
- **pybaselines** (`pybaselines.whittaker.aspls`) — baseline asPLS Zhang 2020
- **numpy** (`np.gradient`) — gradient 2ᵉ ordre non-uniforme
- **matplotlib** — palette **tab10** pour parité visuelle

Références bibliographiques détaillées dans [ALGORITHMS.md](ALGORITHMS.md).

© 2026 Stéphane Cadinot.
