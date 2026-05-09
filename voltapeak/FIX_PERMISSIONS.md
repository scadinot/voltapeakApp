# 🔒 CORRECTION DE L'ERREUR : "You don't have permission to view it"

## ⚡️ Solution en 5 étapes (2 minutes)

### Étape 1️⃣ : Ouvrir le projet dans Xcode
- Fichier déjà ouvert ✅

### Étape 2️⃣ : Sélectionner le projet
Dans le navigateur de fichiers (à gauche), cliquer sur **voltapeak** (icône bleue tout en haut)

### Étape 3️⃣ : Aller dans "Signing & Capabilities"
1. Sélectionner la **cible** "voltapeak" (sous TARGETS)
2. Cliquer sur l'onglet **"Signing & Capabilities"** (en haut)

### Étape 4️⃣ : Ajouter App Sandbox
1. Cliquer sur **"+ Capability"** (en haut à gauche)
2. Chercher **"App Sandbox"**
3. Double-cliquer dessus pour l'ajouter

### Étape 5️⃣ : Activer "User Selected File"
Dans la section **"App Sandbox"** qui vient d'apparaître :
1. Trouver **"File Access"**
2. Sous **"User Selected File"**, cocher **"Read Only"**

### Étape 6️⃣ : Reconstruire l'application
1. Menu **Product** → **Clean Build Folder** (ou ⇧⌘K)
2. Menu **Product** → **Build** (ou ⌘B)
3. Menu **Product** → **Run** (ou ⌘R)

---

## ✅ C'est réglé !

Maintenant vous pouvez :
1. Cliquer sur **"Parcourir"**
2. Sélectionner votre fichier `BT16Mb-T16TAC_01_SWV_C06.txt`
3. L'analyse démarre automatiquement !

---

## 🤔 Pourquoi cette erreur ?

macOS protège les fichiers de l'utilisateur via le **sandbox**. Sans configuration appropriée, l'application ne peut pas lire de fichiers, même ceux que vous sélectionnez explicitement.

La configuration "User Selected File (Read Only)" donne à l'application la permission de lire **uniquement** les fichiers que **vous** sélectionnez via le dialogue "Parcourir".

---

## 📖 Plus d'informations

- **Guide complet** : PERMISSIONS.md
- **Démarrage rapide** : QUICKSTART.md

---

## 🆘 Si le problème persiste

### Vérifier que la configuration est bien sauvegardée :
1. Dans Xcode, regarder dans le fichier `voltapeak.entitlements`
2. Vous devriez voir :
```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
```

### Alternative temporaire (développement seulement) :
1. Dans "Signing & Capabilities"
2. Clic droit sur "App Sandbox" → **Remove**
3. Rebuild

⚠️ **Attention** : Cette méthode ne fonctionne que pour le développement local. Ne convient pas pour une distribution.

---

## 📱 Contact

Si vous avez d'autres questions, consultez la documentation complète dans le projet.
