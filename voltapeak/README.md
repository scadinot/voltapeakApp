# Voltapeak - Analyseur de voltampérogrammes SWV pour macOS

Application macOS native en Swift pour l'analyse de voltampérogrammes issus de mesures de voltampérométrie à ondes carrées (Square Wave Voltammetry - SWV).

## 🎯 Fonctionnalités

Voltapeak est une conversion Swift/macOS de l'outil Python original, offrant :

### Traitement du signal
- **Lecture de fichiers texte** : Import de fichiers `.txt` avec configuration du séparateur de colonnes et décimal
- **Lissage Savitzky-Golay** : Atténuation du bruit haute fréquence sans déformation des pics
- **Détection automatique de pics** : Identification du pic anodique avec protection des bords
- **Estimation de baseline (asPLS)** : Algorithme adaptatif de soustraction de ligne de base
- **Signal corrigé** : Soustraction de la baseline pour analyse précise

### Visualisation
- **Graphique interactif** : Affichage simultané de toutes les courbes :
  - Signal brut (gris, transparence)
  - Signal lissé (bleu)
  - Baseline estimée (orange, tiretée)
  - Signal corrigé (vert)
  - Marqueur de pic (rose)
- **Légende claire** avec code couleur
- **Statistiques** : Position et amplitude du pic corrigé

### Export
- **Export CSV** : Exportation complète des données traitées

## 📋 Format de fichier attendu

```
Potentiel (V)    Courant (A)
-0.500000        -1.234e-06
-0.495000        -1.189e-06
...
```

- **Encodage** : ISO Latin-1 (compatible potentiostats francophones)
- **En-tête** : Première ligne ignorée automatiquement
- **Séparateurs** : Configurables (tabulation, virgule, point-virgule, espace)
- **Décimal** : Point ou virgule selon la locale

## 🚀 Utilisation

1. **Lancer l'application**
2. **Configurer les paramètres** :
   - Séparateur de colonnes (par défaut : Tabulation)
   - Séparateur décimal (par défaut : Point)
3. **Cliquer sur "Parcourir"** et sélectionner un fichier `.txt`
4. **L'analyse se lance automatiquement** et affiche :
   - Toutes les courbes superposées
   - Position et amplitude du pic détecté
5. **Exporter** les résultats au format CSV si nécessaire

## 🔬 Algorithmes implémentés

### 1. Lissage Savitzky-Golay
Filtre polynomial local qui :
- Préserve la forme et l'amplitude des pics
- Atténue le bruit haute fréquence
- Fenêtre adaptative (11 points par défaut)
- Polynôme d'ordre 2

### 2. Détection de pic robuste
- **Protection des bords** : Ignore 10% de chaque extrémité du signal
- **Filtre de pente** : Rejette les fronts parasites (pente > 500)
- **Maximum local** : Détection du sommet réel du pic

### 3. Estimation de baseline (asPLS simplifié)
- **Zone d'exclusion** : 3% de l'étendue autour du pic détecté
- **Poids adaptatifs** : Faible poids (0.001) dans la zone du pic
- **Fit polynomial pondéré** : Estimation lisse de la tendance de fond

### 4. Correction et redetection
- Soustraction de la baseline du signal lissé
- Nouvelle détection de pic sur le signal corrigé
- Résultat plus précis, débarrassé de l'effet de fond

## 🛠 Architecture du code

```
voltapeak/
├── voltapeakApp.swift          # Point d'entrée de l'application
├── ContentView.swift            # Interface principale SwiftUI
├── VoltammetryData.swift        # Structures de données
├── SWVFileReader.swift          # Lecture et parsing des fichiers
├── SignalProcessing.swift       # Algorithmes de traitement du signal
└── VoltapeakViewModel.swift     # Logique métier et orchestration
```

### Composants clés

- **VoltammetryPoint** : Structure représentant un point (potentiel, courant)
- **VoltammetryAnalysis** : Résultat complet d'une analyse
- **SWVFileConfiguration** : Configuration de lecture des fichiers
- **SignalProcessing** : Algorithmes (Savitzky-Golay, détection de pics, baseline)
- **VoltapeakViewModel** : Orchestre le pipeline complet d'analyse

## 📊 Différences avec la version Python

### Avantages de la version Swift/macOS

✅ **Interface native macOS** : Look & feel macOS moderne  
✅ **Performances** : Swift compilé vs Python interprété  
✅ **Intégration système** : Dialogs natifs, gestion fichiers macOS  
✅ **Swift Charts** : Graphiques natifs haute performance  
✅ **Async/Await** : Traitement asynchrone moderne  
✅ **Type safety** : Sécurité des types à la compilation  

### Limitations actuelles

⚠️ **Algorithmes simplifiés** :
- asPLS : Version simplifiée (fit polynomial vs itératif complet)
- Savitzky-Golay : Coefficients approximés

Ces algorithmes donnent de bons résultats pour des signaux SWV typiques mais peuvent être affinés pour des cas extrêmes.

## 🔮 Améliorations futures

### Court terme
- [ ] Zoom et navigation dans le graphique
- [ ] Paramètres d'analyse configurables (fenêtre SG, seuils, etc.)
- [ ] Sauvegarde/chargement de configurations

### Moyen terme
- [ ] Implémentation complète de asPLS itératif
- [ ] Coefficients exacts de Savitzky-Golay
- [ ] Analyse batch (plusieurs fichiers)
- [ ] Export multi-format (PDF, PNG des graphiques)

### Long terme
- [ ] Détection de plusieurs pics
- [ ] Calibration et quantification
- [ ] Base de données des analyses
- [ ] Support d'autres techniques (CV, DPV, etc.)

## 📝 Licence

Ce projet est une conversion Swift du projet Python original [voltapeak](https://github.com/scadinot/voltapeak).

## 👨‍💻 Auteur

Stéphane Cadinot - 2026

## 🙏 Remerciements

- Projet Python original : voltapeak
- Bibliothèques Python : numpy, scipy, pybaselines, pandas, matplotlib
- Frameworks Apple : SwiftUI, Swift Charts, Accelerate
