# Configuration des permissions - Voltapeak

## Problème : "You don't have permission to view it"

Cette erreur apparaît à cause du **sandbox macOS** qui protège l'accès aux fichiers.

## Solution rapide

### Étape 1 : Configurer App Sandbox dans Xcode

1. Ouvrir votre projet dans Xcode
2. Sélectionner le **projet** "voltapeak" dans le navigateur (icône bleue)
3. Sélectionner la **cible** "voltapeak" 
4. Aller dans l'onglet **"Signing & Capabilities"**
5. Si "App Sandbox" n'est pas visible :
   - Cliquer sur **"+ Capability"**
   - Chercher et ajouter **"App Sandbox"**
6. Dans la section **"File Access"** :
   - ✅ Cocher **"User Selected File"** → **Read Only**
   - (ou **Read/Write** si vous prévoyez de modifier les fichiers)

### Étape 2 : Rebuild

1. Nettoyer le build : **Product > Clean Build Folder** (⇧⌘K)
2. Rebuilder : **Product > Build** (⌘B)
3. Relancer l'application

## Explication

### Pourquoi cette erreur ?

macOS utilise un système de **sandbox** pour protéger les données utilisateur. Par défaut, les applications n'ont accès qu'à :
- Leur propre conteneur
- Les fichiers explicitement sélectionnés par l'utilisateur via un dialogue

### Comment le code gère-t-il cela ?

Le code a été mis à jour avec :

```swift
// Demander l'accès au fichier sélectionné
guard url.startAccessingSecurityScopedResource() else {
    // Erreur si l'accès est refusé
    return
}

// Libérer l'accès à la fin
defer {
    url.stopAccessingSecurityScopedResource()
}

// Lire le fichier
let content = try String(contentsOf: url)
```

### Alternatives (si le problème persiste)

#### Option 1 : Désactiver temporairement le sandbox (développement uniquement)

⚠️ **Ne pas faire pour une distribution App Store !**

1. Dans **Signing & Capabilities**
2. Supprimer complètement "App Sandbox" (clic droit > Remove)
3. Rebuild

#### Option 2 : Copier le fichier dans le dossier Documents

Si vous ne pouvez pas modifier les permissions :

1. Copier votre fichier `.txt` dans `~/Documents/`
2. Ouvrir depuis là

#### Option 3 : Vérifier les permissions du fichier

Dans Terminal :
```bash
ls -la /chemin/vers/BT16Mb-T16TAC_01_SWV_C06.txt
```

Si nécessaire, modifier :
```bash
chmod 644 /chemin/vers/BT16Mb-T16TAC_01_SWV_C06.txt
```

## Configuration recommandée pour la distribution

Pour une application distribuée (TestFlight, App Store, ou hors App Store) :

### Capabilities à activer :
- ✅ **App Sandbox** : Activé
- ✅ **User Selected File** : Read Only
- ❌ **Downloads Folder** : Désactivé (sauf besoin spécifique)
- ❌ **Pictures Folder** : Désactivé

### Entitlements supplémentaires (si nécessaire)

Si vous distribuez hors App Store, vous pourriez avoir besoin de :

```xml
<!-- Dans voltapeak.entitlements -->
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
```

Mais normalement, Xcode gère cela automatiquement via l'interface Capabilities.

## Vérification

Pour vérifier que tout fonctionne :

1. Lancer l'application
2. Cliquer sur "Parcourir"
3. Sélectionner un fichier `.txt`
4. Le fichier devrait s'ouvrir sans erreur

Si l'erreur persiste après configuration, vérifier :
- Les logs de la console Xcode
- Que le rebuild complet a été fait
- Que le fichier n'est pas sur un volume externe (permissions différentes)

## Support

Si le problème persiste :
1. Vérifier la console Xcode pour des messages détaillés
2. Tester avec un fichier dans `~/Documents/`
3. Vérifier que le fichier n'est pas verrouillé (Get Info dans Finder)
