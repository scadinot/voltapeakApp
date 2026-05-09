# 🚀 Guide complet : Distribuer Voltapeak

## 📖 Table des matières

1. [Préparation rapide (5 min)](#préparation-rapide)
2. [Méthode simple - Sans signature](#méthode-simple)
3. [Méthode avancée - Avec notarisation](#méthode-avancée)
4. [Création du package de distribution](#package-de-distribution)

---

## Préparation rapide

### ✅ Checklist avant de commencer

- [ ] Xcode installé et à jour
- [ ] Projet Voltapeak ouvert dans Xcode
- [ ] App Sandbox configuré (User Selected File)
- [ ] Version et numéro de build définis

### Configuration de la version

1. Dans Xcode, sélectionner le **projet** voltapeak
2. Onglet **"General"**
3. Modifier :
   - **Version** : 1.0 (numéro de version publique)
   - **Build** : 1 (numéro de build interne)

---

## Méthode simple

### 🎯 Pour distribution interne ou tests

Cette méthode est la plus rapide et ne nécessite pas de compte Apple Developer payant.

### Étape 1 : Archiver l'application (2 min)

1. Dans Xcode, menu **Product** → **Scheme** → Sélectionner **voltapeak**
2. Menu **Product** → **Destination** → Sélectionner **"Any Mac"**
3. Menu **Product** → **Archive** (ou ⌘+⌥+⇧+R)
4. Attendre la fin de la compilation (1-2 minutes)

**Résultat** : La fenêtre "Organizer" s'ouvre automatiquement

### Étape 2 : Exporter l'application (1 min)

Dans la fenêtre **Organizer** (Archives) :

1. Sélectionner l'archive qui vient d'être créée (la plus récente)
2. Cliquer sur **"Distribute App"** (bouton bleu à droite)
3. Sélectionner **"Copy App"**
4. Cliquer **"Next"**
5. Choisir un emplacement (ex: Bureau)
6. Cliquer **"Export"**

**Résultat** : Un fichier `voltapeak.app` est créé sur votre Bureau

### Étape 3 : Créer un DMG (2 min)

**Option A - Script automatique (recommandé) :**

```bash
# Ouvrir Terminal
# Aller dans le dossier du projet
cd /chemin/vers/voltapeak

# Rendre le script exécutable (première fois seulement)
chmod +x create_dmg.sh

# Lancer le script
./create_dmg.sh ~/Desktop/voltapeak.app
```

**Option B - Commande manuelle :**

```bash
# Dans Terminal
cd ~/Desktop

# Créer le DMG
hdiutil create -volname "Voltapeak" -srcfolder voltapeak.app -ov -format UDZO Voltapeak-1.0.dmg
```

**Résultat** : Un fichier `Voltapeak-1.0.dmg` est créé

### Étape 4 : Tester (Important !)

1. **Monter le DMG** : Double-cliquer sur `Voltapeak-1.0.dmg`
2. **Copier l'app** : Glisser vers un autre dossier (ex: Bureau)
3. **Lancer** : Double-cliquer sur la copie
4. **Tester** : Ouvrir un fichier SWV

Si tout fonctionne → **Prêt à distribuer !** ✅

---

## Méthode avancée

### 🔐 Pour distribution publique (recommandé)

**Prérequis** :
- Compte Apple Developer (99 €/an)
- Certificat Developer ID installé

### Configuration Hardened Runtime

1. Projet voltapeak → Cible → **Signing & Capabilities**
2. Cliquer **"+ Capability"**
3. Ajouter **"Hardened Runtime"**
4. Dans Hardened Runtime, **ne rien cocher** (par défaut OK)

### Archiver avec signature

1. **Product** → **Archive**
2. Dans Organizer, cliquer **"Distribute App"**
3. Sélectionner **"Developer ID"**
4. Cliquer **"Next"**
5. Sélectionner **"Upload"** (pour notarisation)
6. Cliquer **"Next"**
7. Vérifier les informations
8. Cliquer **"Upload"**

**Résultat** : Apple va :
- Signer l'application
- La scanner pour malware
- La notariser (5-30 minutes)

### Vérifier la notarisation

```bash
# Attendre ~10 minutes puis vérifier
xcrun notarytool history --apple-id votre@email.com --team-id VOTRE_TEAM_ID

# Ou utiliser l'interface web :
# https://appstoreconnect.apple.com/
```

### Télécharger et agrafer

Une fois notarisé :

```bash
# Télécharger l'app notarisée depuis Organizer
# (Distribute App → Developer ID → Export)

# Agrafer le ticket
xcrun stapler staple ~/Desktop/voltapeak.app

# Créer le DMG
hdiutil create -volname "Voltapeak" -srcfolder ~/Desktop/voltapeak.app -ov -format UDZO Voltapeak-1.0.dmg

# Agrafer le DMG aussi
xcrun stapler staple Voltapeak-1.0.dmg
```

---

## Package de distribution

### 📦 Créer un package complet pour vos utilisateurs

Structure recommandée :

```
Voltapeak-1.0/
├── Voltapeak-1.0.dmg           # Application
├── README.txt                   # Instructions
├── Exemples/
│   └── exemple_swv.txt         # Fichier d'exemple
└── Documentation/
    └── Guide_utilisateur.pdf   # Guide (optionnel)
```

### Créer le README.txt

```bash
# Copier le README de distribution
cp README_DISTRIBUTION.md Voltapeak-1.0/README.txt
```

### Ajouter un fichier d'exemple (optionnel)

Créer un fichier `exemple_swv.txt` :

```
Potentiel (V)	Courant (A)
-0.500	-1.234e-06
-0.495	-1.189e-06
-0.490	-1.145e-06
-0.485	-1.102e-06
-0.480	-1.060e-06
```

### Créer l'archive finale

```bash
# ZIP pour distribution
cd ~/Desktop
zip -r Voltapeak-1.0.zip Voltapeak-1.0/

# Ou DMG pour plus professionnel
hdiutil create -volname "Voltapeak 1.0" -srcfolder Voltapeak-1.0/ -ov -format UDZO Voltapeak-1.0-Complete.dmg
```

---

## 🌐 Distribution

### Où héberger votre application ?

#### Option 1 : GitHub Releases (recommandé)

1. Créer un repository GitHub
2. Aller dans **Releases** → **Create a new release**
3. Tag version : `v1.0`
4. Titre : `Voltapeak 1.0`
5. Description : Notes de version
6. Glisser-déposer `Voltapeak-1.0.dmg`
7. Publier

**Avantages** :
- Gratuit
- Versioning automatique
- Téléchargement direct
- Historique des versions

#### Option 2 : Google Drive / Dropbox

1. Upload le DMG
2. Créer un lien de partage
3. Partager le lien

#### Option 3 : Votre propre site web

```html
<!-- Exemple de page de téléchargement -->
<!DOCTYPE html>
<html>
<head>
    <title>Télécharger Voltapeak</title>
</head>
<body>
    <h1>Voltapeak 1.0</h1>
    <p>Analyseur de voltampérogrammes SWV pour macOS</p>
    
    <a href="Voltapeak-1.0.dmg" download>
        Télécharger Voltapeak 1.0 (7 Mo)
    </a>
    
    <h2>Configuration requise</h2>
    <ul>
        <li>macOS 13.0 ou supérieur</li>
        <li>Intel ou Apple Silicon</li>
    </ul>
</body>
</html>
```

---

## 📋 Checklist finale

Avant de distribuer :

### Tests
- [ ] Testé sur votre Mac
- [ ] Testé sur un autre Mac (si possible)
- [ ] Testé sur Intel ET Apple Silicon (si possible)
- [ ] Testé le premier lancement (clic droit → Ouvrir)
- [ ] Testé avec un fichier SWV réel
- [ ] Testé l'export CSV

### Fichiers
- [ ] DMG créé
- [ ] README inclus
- [ ] Taille raisonnable (< 10 Mo)
- [ ] Nom de fichier clair (Voltapeak-1.0.dmg)

### Documentation
- [ ] Instructions d'installation rédigées
- [ ] Problèmes connus documentés
- [ ] Contact pour support fourni

---

## 🎉 Publication

### Message type pour annoncer la version

```
🎉 Voltapeak 1.0 est disponible !

Analysez vos voltampérogrammes SWV directement sur macOS.

✨ Fonctionnalités :
• Lecture de fichiers texte
• Lissage Savitzky-Golay
• Détection automatique des pics
• Correction de baseline (asPLS)
• Export CSV

📥 Télécharger : [lien]

💻 Configuration requise : macOS 13.0+

📖 Documentation complète incluse
```

---

## 🔄 Mises à jour futures

Pour publier une nouvelle version :

1. Modifier le numéro de version dans Xcode
2. Product → Archive
3. Distribuer (même processus)
4. Créer un nouveau DMG : `Voltapeak-1.1.dmg`
5. Publier sur la même plateforme

**Notes de version** :
```
Version 1.1 (Juin 2026)
• Correction : Bug lors du chargement de gros fichiers
• Amélioration : Détection de pic plus précise
• Ajout : Support du format CSV en entrée
```

---

## ✅ Résumé rapide

**Pour une distribution simple (5 minutes) :**
1. Product → Archive
2. Distribute App → Copy App
3. `hdiutil create` pour créer le DMG
4. Tester et distribuer

**Pour une distribution professionnelle (30 minutes) :**
1. Activer Hardened Runtime
2. Product → Archive
3. Distribute App → Developer ID → Upload
4. Attendre la notarisation
5. Agrafer (stapler)
6. Créer le DMG
7. Tester et distribuer

---

## 🆘 Besoin d'aide ?

- **Erreurs de signature** → Vérifier les certificats dans Xcode
- **Notarisation échoue** → Consulter les logs sur appstoreconnect.apple.com
- **App bloquée** → Vérifier App Sandbox et Hardened Runtime

---

**Bon courage pour votre distribution ! 🚀**
