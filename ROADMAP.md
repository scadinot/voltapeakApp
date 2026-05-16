# ROADMAP — voltapeakApp

Évolutions planifiées, regroupées en **vagues de priorité**. L'ordre des vagues est indicatif : un item peut être avancé si une demande utilisateur le rend prioritaire. Aucun item n'a de date d'engagement — le projet reste en usage interne GROUPE TRACE et avance par opportunité.

> Cette feuille de route est partagée entre les trois applications [`voltapeakApp`](https://github.com/scadinot/voltapeakApp), [`voltapeak_batchApp`](https://github.com/scadinot/voltapeak_batchApp) et [`voltapeak_loopsApp`](https://github.com/scadinot/voltapeak_loopsApp) : les items marqués **(commun)** s'appliquent aux trois et bénéficieront idéalement de la même implémentation (cf. Vague 6 — mutualisation du noyau scientifique dans un package `VoltapeakCore`).

---

## Table des matières

1. [Vague 1 — Hygiène & robustesse](#vague-1--hygiène--robustesse)
2. [Vague 2 — Configurabilité](#vague-2--configurabilité)
3. [Vague 3 — Fonctionnalités utilisateur](#vague-3--fonctionnalités-utilisateur)
4. [Vague 4 — Qualité logicielle](#vague-4--qualité-logicielle)
5. [Vague 5 — Distribution](#vague-5--distribution)
6. [Vague 6 — Extensions scientifiques](#vague-6--extensions-scientifiques)
7. [Contribuer](#contribuer)

---

## Vague 1 — Hygiène & robustesse

Items qui éliminent des pièges connus ou des limitations documentées dans le [`README`](README.md).

- **Encodage configurable** *(commun)* — l'encodage de lecture est aujourd'hui figé à `ISO Latin-1`. Exposer dans l'UI une bascule `Latin-1 / UTF-8 / UTF-8 BOM`, avec auto-détection optionnelle (heuristique BOM + fallback Latin-1).
- **Support du pic anodique** *(commun)* — `SWVFileReader.processData` inverse systématiquement le signe du courant. Ajouter dans la GUI une case à cocher *« Pic en courant positif (anodique) »* qui désactive l'inversion.
- **Affinage des erreurs `FileError`** *(commun)* — enrichir les `LocalizedError` (`tooManyPoints`, `tooFewPoints`, `encodingError`, `permissionDenied`) avec des suggestions actionnables dans le bouton *Aide* de l'alerte (lien direct vers la section *Dépannage* du README).
- **Persistance du dernier fichier ouvert** *(spécifique voltapeakApp)* — au relancement, proposer de recharger le `.txt` analysé en fin de session précédente (stocké dans `UserDefaults` via un *security-scoped bookmark*, compatible avec une éventuelle réactivation de l'App Sandbox).

---

## Vague 2 — Configurabilité

Exposer dans l'UI ce qui est aujourd'hui codé en dur.

- **Exposition des hyperparamètres** *(commun)* — section « Paramètres avancés » repliable, avec sliders / `Stepper` SwiftUI pour :
  - `windowLength` (Savitzky-Golay)
  - `polyorder`
  - `marginRatio`
  - `maxSlope`
  - `exclusionWidthRatio`
  - `lambdaFactor`
- **Profils de paramètres** *(commun)* — sauvegarde / rechargement de jeux de paramètres nommés (JSON dans `~/Library/Application Support/voltapeak/profiles/`), pour basculer rapidement entre différentes campagnes.

---

## Vague 3 — Fonctionnalités utilisateur

- **Export PNG automatique** — case à cocher pour enregistrer automatiquement un PNG à côté du fichier d'entrée, sans passer par `NSSavePanel`.
- **Comparaison de plusieurs fichiers superposés** — sélectionner 2 à 5 fichiers et tracer leurs signaux corrigés sur le même `Chart` SwiftUI pour comparer (sans pipeline batch complet).
- **Affichage des coordonnées du curseur** — annotation interactive au survol via `chartXSelection` / `chartYSelection` pour lire facilement (V, A) à n'importe quel point de la courbe.
- **Onglet Tableau** — vue alternative au graphe affichant les 5 colonnes (`Potential`, brut, lissé, baseline, corrigé) dans un `Table` SwiftUI triable et copiable.

---

## Vague 4 — Qualité logicielle

- **Tests Swift `Testing` étendus** *(commun)* — `voltapeakApp` héberge déjà la suite de référence (`SavitzkyGolayTests`, `WhittakerASPLSTests`, `SignalProcessingTests`). Étendre la couverture à `SWVFileReader` (parse de fichiers de référence avec séparateurs / encodages variés) et `XLSXWriter` (lecture-écriture round-trip).
- **CI multi-repo unifiée** *(commun)* — étendre le workflow `swift.yml` (build + test + analyze) à `voltapeak_batchApp` et `voltapeak_loopsApp` ; ajouter `swift-format` ou `swiftlint` en pré-commit + CI.
- **App Sandbox réactivée** *(commun)* — actuellement `ENABLE_APP_SANDBOX = NO`. Repasser à `YES` avec entitlements `com.apple.security.files.user-selected.read-write` + `com.apple.security.files.bookmarks.app-scope` ; tester la régression sur `startAccessingSecurityScopedResource` (déjà appelé dans le code).
- **Tests UI XCUITest** *(commun)* — vérifier que le pipeline end-to-end (drag-drop d'un fichier de référence → affichage du graphe ou lancement du lot → présence du XLSX agrégé) ne régresse pas.

---

## Vague 5 — Distribution

- **Signature Developer ID + notarisation** *(commun)* — actuellement `CODE_SIGN_IDENTITY="-"` (ad-hoc). Configurer la signature Developer ID Application + agrafer la notarisation Apple dans le workflow `release.yml` (le script `voltapeak.xcodeproj/create_dmg.sh` esquisse déjà l'agrafe). Élimine le clic droit → *Ouvrir* au premier lancement.
- **Distribution Mac App Store** *(commun)* — pré-requis : Sandbox réactivée (Vague 4) + entitlements minimaux. Ajouter un schéma de release App Store séparé.
- **Mode CLI** *(commun)* — target Xcode `voltapeak-cli` (executable) qui prend les mêmes arguments que la GUI (fichier ou dossier + options) et produit les sorties sans afficher de fenêtre. Utile pour scripts d'intégration externes.
- **Découpage en SwiftPM modules** *(commun)* — créer un package `VoltapeakCore` partagé (cf. Vague 6) et plusieurs targets dans chaque app (`...Algorithms`, `...IO`, `...UI`). Pré-requis pour la mutualisation.

---

## Vague 6 — Extensions scientifiques

- **Mutualisation `VoltapeakCore`** *(commun)* — extraire les implémentations actuellement dupliquées entre les 3 apps (`SavitzkyGolay`, `WhittakerASPLS`, `SignalProcessing`, `SWVFileReader`, `XLSXWriter` / `ZIPStore` / `XLSXBoilerplate`, `VoltammetryData`) dans un Swift Package partagé `VoltapeakCore`. Élimine la duplication actuelle (3 copies à maintenir manuellement) et garantit que les correctifs scientifiques se propagent automatiquement.
- **Détection multi-pics** *(commun)* — repérer plusieurs maxima locaux significatifs et tous les annoter (`PointMark` multiples sur le graphe), au lieu du seul maximum global.
- **Métriques de qualité du fit** *(commun)* — afficher SNR, résidus baseline (RMSE), FWHM du pic dans l'UI / exports, pour qualifier objectivement la détection.
- **Support d'autres techniques voltammétriques** *(commun)* — DPV (*Differential Pulse Voltammetry*), CV (*Cyclic Voltammetry*) : pipelines adaptés mais réutilisant le noyau de lissage / baseline.

---

## Contribuer

- Pour proposer une évolution non listée : ouvrir une *issue* sur le dépôt avec le label `enhancement`.
- Pour signaler un bug : ouvrir une *issue* avec le label `bug` et joindre un fichier `.txt` reproductible si possible.
- Les contributions externes (pull requests) sont les bienvenues — préférer une discussion préalable en issue pour les changements architecturaux.
