# Guide de distribution de Voltapeak

## 🎯 Distribution de l'application macOS

Ce guide explique comment créer une version distribuable de Voltapeak que vous pouvez partager avec d'autres utilisateurs.

---

## 📦 Option 1 : Distribution simple (sans notarisation)

### Pour usage personnel ou au sein d'une organisation

#### Étape 1 : Configuration du projet

Dans Xcode :

1. **Sélectionner le projet** voltapeak (icône bleue)
2. **Sélectionner la cible** voltapeak
3. **Onglet "Signing & Capabilities"**

**Configuration recommandée :**
```
✅ Automatically manage signing (coché)
Team : Votre équipe Apple (ou votre compte personnel)
Bundle Identifier : com.votreNom.voltapeak (unique)

App Sandbox :
  ✅ File Access → User Selected File (Read Only)
```

#### Étape 2 : Construire l'application (Archive)

1. Menu **Product** → **Scheme** → Sélectionner **voltapeak**
2. Menu **Product** → **Destination** → **Any Mac**
3. Menu **Product** → **Archive**
4. Attendre la fin de l'archivage (quelques minutes)

La fenêtre **Organizer** s'ouvre automatiquement.

#### Étape 3 : Exporter l'application

Dans la fenêtre **Organizer** :

1. Sélectionner l'archive qui vient d'être créée
2. Cliquer sur **"Distribute App"**
3. Choisir **"Copy App"**
4. Cliquer **"Next"**
5. Choisir un dossier de destination (par exemple : Bureau)
6. Cliquer **"Export"**

✅ **Résultat** : Un fichier `voltapeak.app` est créé

#### Étape 4 : Créer un fichier DMG (optionnel mais recommandé)

**Méthode 1 - Via Terminal :**

```bash
# Aller dans le dossier où se trouve voltapeak.app
cd ~/Desktop

# Créer le DMG
hdiutil create -volname "Voltapeak" -srcfolder voltapeak.app -ov -format UDZO Voltapeak-1.0.dmg
```

**Méthode 2 - Via Utilitaire de disque :**

1. Ouvrir **Utilitaire de disque**
2. Menu **Fichier** → **Nouvelle image** → **Image depuis dossier**
3. Sélectionner `voltapeak.app`
4. Format : **Compressé**
5. Nom : `Voltapeak-1.0`
6. Enregistrer

✅ **Résultat** : Un fichier `Voltapeak-1.0.dmg` prêt à distribuer

---

## 🔐 Option 2 : Distribution professionnelle (avec notarisation)

### Pour distribution publique ou à grande échelle

**Prérequis :**
- Compte Apple Developer (99 €/an)
- Certificat de développeur Apple valide

#### Étape 1 : Configuration avancée

Dans Xcode, **Signing & Capabilities** :

```
✅ Automatically manage signing
Team : Votre équipe Apple Developer
Bundle Identifier : com.votreNom.voltapeak

Hardened Runtime :
  ✅ Activer
  
App Sandbox :
  ✅ File Access → User Selected File (Read Only)
```

#### Étape 2 : Archiver l'application

1. Menu **Product** → **Archive**
2. Attendre la fin

#### Étape 3 : Distribuer et notariser

Dans **Organizer** :

1. Sélectionner l'archive
2. **"Distribute App"**
3. Choisir **"Developer ID"**
4. **"Next"**
5. ✅ **"Upload"** (pour notarisation)
6. **"Next"** → **"Export"**

Apple va :
- Signer l'application
- Scanner pour malware
- Notariser (quelques minutes à quelques heures)

#### Étape 4 : Vérifier la notarisation

```bash
# Vérifier le statut
xcrun notarytool history --apple-id votre@email.com
```

#### Étape 5 : Agrafer le ticket (stapler)

```bash
# Agrafer le ticket de notarisation à l'app
xcrun stapler staple voltapeak.app

# Créer le DMG
hdiutil create -volname "Voltapeak" -srcfolder voltapeak.app -ov -format UDZO Voltapeak-1.0.dmg

# Agrafer aussi le DMG
xcrun stapler staple Voltapeak-1.0.dmg
```

✅ **Résultat** : Application signée et notarisée par Apple

---

## 📤 Distribution aux utilisateurs

### Option 1 : Fichier .app direct

**Avantages :**
- Simple
- Double-clic pour lancer

**Instructions pour vos utilisateurs :**
1. Télécharger `voltapeak.app`
2. Glisser vers `/Applications` (ou autre dossier)
3. Double-cliquer pour lancer

⚠️ **Premier lancement** (si non notarisé) :
```
"voltapeak" ne peut pas être ouvert car il provient d'un développeur non identifié
```

**Solution :**
1. Clic droit sur `voltapeak.app` → **Ouvrir**
2. Cliquer **"Ouvrir"** dans la fenêtre qui apparaît
3. Les lancements suivants se feront normalement

### Option 2 : Fichier .dmg (recommandé)

**Avantages :**
- Professionnel
- Compressé (fichier plus petit)
- Instructions d'installation visuelles

**Instructions pour vos utilisateurs :**
1. Télécharger `Voltapeak-1.0.dmg`
2. Double-cliquer sur le DMG
3. Glisser `Voltapeak.app` vers `/Applications`
4. Éjecter le volume DMG
5. Lancer Voltapeak depuis `/Applications`

### Option 3 : Fichier .zip

```bash
# Créer un zip
zip -r Voltapeak-1.0.zip voltapeak.app
```

---

## 🎨 Personnalisation du DMG (optionnel)

Pour un DMG professionnel avec fond personnalisé :

### Créer un DMG élaboré

```bash
# 1. Créer un DMG temporaire en lecture/écriture
hdiutil create -size 100m -fs HFS+ -volname "Voltapeak" temp.dmg

# 2. Monter le DMG
hdiutil attach temp.dmg

# 3. Copier l'application
cp -R voltapeak.app /Volumes/Voltapeak/

# 4. Créer un alias vers Applications
ln -s /Applications /Volumes/Voltapeak/Applications

# 5. Ajouter une image de fond (optionnel)
mkdir /Volumes/Voltapeak/.background
cp background.png /Volumes/Voltapeak/.background/

# 6. Démonter
hdiutil detach /Volumes/Voltapeak

# 7. Convertir en DMG final (lecture seule, compressé)
hdiutil convert temp.dmg -format UDZO -o Voltapeak-1.0.dmg

# 8. Nettoyer
rm temp.dmg
```

---

## 📋 Checklist avant distribution

### Version simple (non notarisée)
- [ ] App Sandbox configuré
- [ ] Bundle Identifier défini
- [ ] Version et Build Number mis à jour
- [ ] Archive créée
- [ ] Application exportée (Copy App)
- [ ] DMG créé (optionnel)
- [ ] Testé sur une autre machine macOS

### Version notarisée (recommandée)
- [ ] Compte Apple Developer actif
- [ ] Hardened Runtime activé
- [ ] App Sandbox configuré
- [ ] Archive créée
- [ ] Notarisation réussie
- [ ] Ticket agrafé (stapler)
- [ ] DMG créé et agrafé
- [ ] Testé sur une autre machine macOS

---

## 🌐 Méthodes de distribution

### 1. Email / Messages
- Envoyer le `.dmg` ou `.zip`
- Limite : ~25 Mo par email

### 2. Cloud (Drive, Dropbox, etc.)
- Upload le fichier
- Partager le lien

### 3. Site web / GitHub
- Héberger sur votre site
- Ou créer une Release sur GitHub

### 4. TestFlight (pour bêta-testeurs)
- Nécessite compte Developer
- Distribution gérée par Apple

---

## ⚙️ Configuration de l'Info.plist

Avant de distribuer, vérifiez/modifiez :

```xml
<!-- Dans voltapeak/Info.plist -->
<key>CFBundleShortVersionString</key>
<string>1.0</string>

<key>CFBundleVersion</key>
<string>1</string>

<key>CFBundleDisplayName</key>
<string>Voltapeak</string>

<key>CFBundleName</key>
<string>Voltapeak</string>

<key>NSHumanReadableCopyright</key>
<string>© 2026 Stéphane Cadinot</string>
```

---

## 🔍 Vérification de l'application

Avant de distribuer, testez :

```bash
# Vérifier la signature
codesign -dv --verbose=4 voltapeak.app

# Vérifier le hardened runtime
codesign -d --entitlements - voltapeak.app

# Vérifier la notarisation (si applicable)
spctl -a -vv -t install voltapeak.app
```

---

## 📊 Tailles de fichier typiques

- **voltapeak.app** : ~5-10 Mo
- **voltapeak.dmg** (compressé) : ~3-7 Mo
- **voltapeak.zip** : ~3-7 Mo

---

## 🆘 Résolution de problèmes

### "voltapeak.app" est endommagé

**Cause** : Attributs de quarantaine macOS

**Solution** :
```bash
xattr -cr voltapeak.app
```

### "Impossible d'ouvrir car provient d'un développeur non identifié"

**Solution pour vos utilisateurs :**
1. Clic droit → Ouvrir
2. Cliquer "Ouvrir" dans la fenêtre

### L'application ne fonctionne pas sur d'autres Macs

**Vérifier :**
- Architecture : Intel (x86_64) ou Apple Silicon (arm64) ?
- Version macOS minimale supportée
- Dépendances système

---

## 🎯 Recommandation finale

Pour une distribution simple et rapide :
1. **Archive** l'application (Product → Archive)
2. **Export** avec "Copy App"
3. **Créer un DMG** avec hdiutil
4. **Distribuer** le DMG

Pour une distribution professionnelle :
- Suivre le processus complet de notarisation
- Créer un site web ou page GitHub avec instructions

---

## 📝 Licence et distribution

N'oubliez pas d'inclure avec votre distribution :
- [ ] Fichier README avec instructions d'installation
- [ ] Licence (si applicable)
- [ ] Fichiers d'exemple (optionnel)
- [ ] Documentation utilisateur

---

## ✅ Exemple de structure de distribution

```
Voltapeak-1.0/
├── Voltapeak-1.0.dmg          # Application principale
├── README.md                   # Instructions d'installation
├── QUICKSTART.md               # Guide de démarrage
├── Exemples/                   # Dossier optionnel
│   └── sample_swv_data.txt    # Fichier d'exemple
└── Documentation.pdf           # Guide utilisateur (optionnel)
```

---

## 📞 Support

Pour toute question sur la distribution, consultez :
- [Documentation Apple sur la distribution](https://developer.apple.com/documentation/xcode/distributing-your-app-outside-the-app-store)
- [Guide de notarisation](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
