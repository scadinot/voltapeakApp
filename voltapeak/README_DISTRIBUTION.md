# Voltapeak - Analyseur de voltampérogrammes SWV

Version 1.0 - macOS

---

## 🎯 À propos

Voltapeak est une application macOS pour l'analyse de voltampérogrammes issus de mesures de voltampérométrie à ondes carrées (Square Wave Voltammetry - SWV).

**Fonctionnalités :**
- Lecture de fichiers texte SWV (.txt)
- Lissage du signal (Savitzky-Golay)
- Détection automatique des pics
- Correction de ligne de base (asPLS)
- Visualisation graphique interactive
- Export des résultats en CSV

---

## 💾 Installation

### Méthode 1 : Depuis le DMG

1. **Télécharger** `Voltapeak-1.0.dmg`
2. **Double-cliquer** sur le fichier DMG
3. **Glisser** l'icône Voltapeak vers le dossier Applications
4. **Éjecter** le volume Voltapeak
5. **Lancer** Voltapeak depuis /Applications

### Méthode 2 : Application seule

1. **Télécharger** `Voltapeak.app` ou `Voltapeak.zip`
2. **Décompresser** si nécessaire
3. **Glisser** Voltapeak.app vers /Applications (ou autre dossier)
4. **Lancer** l'application

---

## 🚀 Premier lancement

### Si vous voyez : "Voltapeak ne peut pas être ouvert"

macOS bloque parfois les applications téléchargées pour votre sécurité.

**Solution :**
1. **Clic droit** (ou Ctrl+Clic) sur Voltapeak.app
2. Choisir **"Ouvrir"** dans le menu
3. Cliquer **"Ouvrir"** dans la fenêtre qui apparaît
4. Les prochains lancements se feront normalement

### Configuration des permissions

Au premier lancement, Voltapeak demandera l'autorisation d'accéder aux fichiers que vous sélectionnez. C'est normal et nécessaire pour lire vos données SWV.

---

## 📖 Utilisation

### 1. Préparer votre fichier

Voltapeak accepte des fichiers texte (.txt) avec deux colonnes :
```
Potentiel (V)    Courant (A)
-0.500000        -1.234e-06
-0.495000        -1.189e-06
...
```

**Format :**
- Première ligne : en-tête (ignorée)
- Colonnes : Potentiel, Courant
- Séparateur : configurable (tabulation par défaut)

### 2. Configurer les paramètres

Avant d'ouvrir un fichier, vérifiez :
- **Séparateur de colonnes** : Tabulation, Virgule, Point-virgule, ou Espace
- **Séparateur décimal** : Point (.) ou Virgule (,)

### 3. Ouvrir et analyser

1. Cliquer sur **"Parcourir"**
2. Sélectionner votre fichier .txt
3. L'analyse démarre automatiquement

### 4. Interpréter les résultats

Le graphique affiche :
- **Gris** : Signal brut
- **Bleu** : Signal lissé
- **Orange (tirets)** : Ligne de base estimée
- **Vert** : Signal corrigé
- **Point rose** : Pic détecté

Les informations du pic sont affichées en haut (position en V, amplitude en mA).

### 5. Exporter (optionnel)

Cliquer sur **"Exporter CSV"** pour sauvegarder :
- Potentiels
- Courant brut
- Signal lissé
- Baseline
- Signal corrigé

---

## 📋 Configuration requise

- **Système** : macOS 13.0 (Ventura) ou supérieur
- **Architecture** : Intel (x86_64) ou Apple Silicon (M1/M2/M3)
- **Espace disque** : ~10 Mo
- **RAM** : 100 Mo recommandé

---

## 🔬 Algorithmes

### Lissage Savitzky-Golay
Filtre polynomial (ordre 2, fenêtre 11 points) qui atténue le bruit sans déformer les pics.

### Détection de pic
- Protection des bords (10% ignorés)
- Filtre de pente (rejette les fronts parasites)
- Recherche du maximum local

### Correction de baseline (asPLS)
- Estimation adaptative de la ligne de base
- Zone d'exclusion autour du pic (3%)
- Poids faibles dans la zone du pic

---

## ❓ Foire aux questions

### Mon fichier ne s'ouvre pas

**Vérifiez :**
1. Le format : deux colonnes numériques
2. Le séparateur de colonnes (tabulation, virgule, etc.)
3. Le séparateur décimal (. ou ,)
4. L'encodage : ISO Latin-1 recommandé

### L'application ne se lance pas

**Solutions :**
1. Vérifier la version macOS (≥ 13.0)
2. Faire un clic droit → Ouvrir (premier lancement)
3. Vérifier les permissions dans Préférences Système

### Le pic détecté semble incorrect

Les algorithmes sont optimisés pour des voltampérogrammes SWV typiques. Pour des signaux atypiques :
- Vérifier la qualité des données brutes
- S'assurer que le pic est bien visible sur le signal lissé (bleu)

---

## 🆘 Support

### Problèmes d'installation
Consultez les guides fournis avec l'application.

### Problèmes d'utilisation
Vérifiez le format de votre fichier d'entrée.

### Bugs ou suggestions
Contactez le développeur : [votre email ou GitHub]

---

## 📝 Licence

Ce logiciel est fourni "tel quel", sans garantie d'aucune sorte.

Conversion Swift du projet Python original [voltapeak](https://github.com/scadinot/voltapeak).

---

## 👨‍💻 Crédits

**Développement** : Stéphane Cadinot  
**Version** : 1.0  
**Date** : Mai 2026

**Technologies utilisées :**
- SwiftUI (interface)
- Swift Charts (visualisation)
- Accelerate (calculs)

**Basé sur :**
- Projet Python voltapeak original
- Bibliothèques : numpy, scipy, pybaselines

---

## 🔄 Mises à jour

Vérifiez régulièrement pour les nouvelles versions avec :
- Corrections de bugs
- Nouvelles fonctionnalités
- Améliorations de performance

---

## ⚖️ Mentions légales

© 2026 Stéphane Cadinot. Tous droits réservés.

Les noms de produits mentionnés sont des marques déposées de leurs propriétaires respectifs.

---

**Voltapeak 1.0 - Analyse professionnelle de voltampérogrammes SWV pour macOS**
