# Guide de démarrage rapide - Voltapeak

## ⚡️ Démarrage en 3 étapes

### 1️⃣ Configurer les permissions (OBLIGATOIRE)

**Sans cette étape, vous aurez l'erreur "You don't have permission to view it"**

Dans Xcode :
1. Sélectionner le projet **voltapeak** (icône bleue en haut du navigateur)
2. Sélectionner la cible **voltapeak**
3. Onglet **"Signing & Capabilities"**
4. Cliquer **"+ Capability"** → Ajouter **"App Sandbox"**
5. Dans **"File Access"** → Cocher **"User Selected File"** → **Read Only**
6. **Product → Clean Build Folder** (⇧⌘K)
7. **Product → Build** (⌘B)

### 2️⃣ Lancer l'application

```bash
# Dans Xcode
⌘R pour compiler et lancer
```

### 3️⃣ Analyser votre premier fichier

1. Cliquer sur **"Parcourir"**
2. Sélectionner votre fichier `.txt` (ex: `BT16Mb-T16TAC_01_SWV_C06.txt`)
3. L'analyse démarre automatiquement !

---

## 📁 Format de fichier attendu

Votre fichier `.txt` doit ressembler à :

```
Potentiel (V)    Courant (A)
-0.500000        -1.234567e-06
-0.495000        -1.189234e-06
-0.490000        -1.145678e-06
...
```

**Caractéristiques :**
- ✅ Première ligne = en-tête (ignorée)
- ✅ Deux colonnes : Potentiel, Courant
- ✅ Encodage : ISO Latin-1
- ✅ Au moins 5 lignes de données

---

## 🎛 Configuration des séparateurs

Avant d'ouvrir un fichier, vérifiez :

### Séparateur de colonnes
Choisir selon votre fichier :
- **Tabulation** (par défaut) : colonnes séparées par une tabulation
- **Virgule** : format CSV classique
- **Point-virgule** : format CSV français
- **Espace** : colonnes séparées par un espace

### Séparateur décimal
- **Point** (par défaut) : `1.234`
- **Virgule** (français) : `1,234`

---

## 📊 Lecture des résultats

Une fois l'analyse terminée, vous verrez :

### Graphique avec 5 courbes :
1. **Gris transparent** : Signal brut (données originales)
2. **Bleu** : Signal lissé (Savitzky-Golay)
3. **Orange tiretée** : Baseline estimée (asPLS)
4. **Vert** : Signal corrigé (lissé - baseline)
5. **Point rose** : Pic détecté

### Informations affichées :
- **Titre** : Nom du fichier
- **Position du pic** : en Volts (V)
- **Amplitude du pic** : en milliampères (mA)

---

## 💾 Exporter les résultats

1. Cliquer sur **"Exporter CSV"**
2. Choisir l'emplacement
3. Le fichier CSV contiendra :
   - Potentiel (V)
   - Courant brut (A)
   - Signal lissé (A)
   - Baseline (A)
   - Signal corrigé (A)

---

## ❌ Résolution des problèmes courants

### Erreur : "You don't have permission to view it"

**Cause** : App Sandbox non configuré

**Solution** :
1. Xcode → Signing & Capabilities
2. App Sandbox → User Selected File (Read Only)
3. Clean + Rebuild

📖 Voir [PERMISSIONS.md](PERMISSIONS.md) pour les détails

---

### Erreur : "Format de fichier invalide"

**Cause** : Séparateurs mal configurés

**Solution** :
1. Ouvrir le fichier dans un éditeur de texte
2. Vérifier le séparateur entre les colonnes
3. Ajuster dans l'interface Voltapeak

**Exemples** :
```
# Tabulation (invisible, représentée par →)
-0.500→-1.234e-06

# Virgule
-0.500,-1.234e-06

# Point-virgule
-0.500;-1.234e-06

# Espace
-0.500 -1.234e-06
```

---

### Erreur : "Données insuffisantes"

**Cause** : Moins de 5 points de données

**Solution** :
- Vérifier que le fichier contient bien des données
- S'assurer qu'il y a au moins 6 lignes (1 en-tête + 5 données)
- Vérifier que les courants ne sont pas tous à zéro

---

### Erreur : "Erreur d'encodage"

**Cause** : Le fichier n'est pas en ISO Latin-1

**Solution** :
1. Ouvrir le fichier dans un éditeur de texte
2. Sauvegarder en choisissant l'encodage **"ISO Latin 1"** ou **"Windows-1252"**

---

## 🔬 Comprendre les algorithmes

### Lissage Savitzky-Golay
- **Rôle** : Réduit le bruit sans déformer les pics
- **Paramètres** : Fenêtre 11 points, polynôme ordre 2

### Détection de pic
- **Protection** : Ignore 10% de chaque bord
- **Filtre** : Rejette les pentes > 500 (fronts parasites)

### Baseline asPLS
- **Zone d'exclusion** : 3% autour du pic
- **Poids** : 0.001 dans la zone du pic, 1.0 ailleurs

### Signal corrigé
- **Calcul** : Signal lissé - Baseline
- **Avantage** : Élimine l'effet de fond

---

## 🎯 Workflow typique

```
1. Configurer séparateurs
   ↓
2. Ouvrir fichier .txt
   ↓
3. Vérifier le graphique
   ↓
4. Noter la position du pic
   ↓
5. Exporter CSV si besoin
```

---

## 📞 Besoin d'aide ?

- **Problème de permissions** → Lire [PERMISSIONS.md](PERMISSIONS.md)
- **Documentation complète** → Lire [README.md](README.md)
- **Code source** → Consulter les fichiers Swift annotés

---

## 🚀 Raccourcis clavier

- **⌘O** : Ouvrir un fichier
- **⌘E** : Exporter en CSV
- **⌘Q** : Quitter

---

## ✅ Checklist avant la première utilisation

- [ ] App Sandbox configuré dans Xcode
- [ ] User Selected File (Read Only) coché
- [ ] Clean Build Folder effectué
- [ ] Application recompilée
- [ ] Fichier .txt prêt (format valide)
- [ ] Séparateurs vérifiés dans le fichier

**Si tout est ✅, vous êtes prêt à analyser !**
