# Distribution

Ce guide explique comment produire une version distribuable de
`voltapeakApp` (`.app`, `.zip`, `.dmg`). Trois options selon le
contexte : **CI automatisée**, **signature locale ad-hoc**, ou
**notarisation Apple**. Le canevas est identique entre les trois apps
de la famille `voltapeak*` ; voir
[`voltapeak_batchApp/DISTRIBUTION.md`](https://github.com/scadinot/voltapeak_batchApp/blob/main/DISTRIBUTION.md) et
[`voltapeak_loopsApp/DISTRIBUTION.md`](https://github.com/scadinot/voltapeak_loopsApp/blob/main/DISTRIBUTION.md).

## Prérequis communs

Dans Xcode, onglet **Signing & Capabilities** :

```
✅ Automatically manage signing
Team               : votre équipe Apple
Bundle Identifier  : com.<votreNom>.voltapeak  (unique)

App Sandbox        : activé
  ✅ User Selected File (Read Only)
```

Pour les versions distribuables, vérifier également `Info.plist` :

```xml
<key>CFBundleShortVersionString</key>  <string>1.0</string>
<key>CFBundleVersion</key>             <string>1</string>
<key>CFBundleDisplayName</key>         <string>Voltapeak</string>
<key>NSHumanReadableCopyright</key>    <string>© 2026 Stéphane Cadinot</string>
```

---

## Option 0 — CI GitHub Actions

**Non configurée pour `voltapeakApp`.** Cette app est mono-fichier
SwiftUI, distribuée à la main pour le moment. Pour un exemple de
workflow GitHub Actions (`build-artifact.yml` + `release.yml`), voir
[`voltapeak_loopsApp/.github/workflows/`](https://github.com/scadinot/voltapeak_loopsApp/tree/main/.github/workflows).
Le squelette est facilement adaptable :

- macOS runner `macos-26` (ou `macos-latest`).
- `xcodebuild archive ... CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual`.
- `ditto -c -k --keepParent` pour empaqueter en zip.
- Upload artifact + création release sur tag `v*`.

---

## Option 1 — Distribution locale ad-hoc (sans notarisation)

Pour usage personnel, prototype, ou diffusion au sein d'une équipe
restreinte.

### Étapes

1. **Archive** : `Product → Destination → Any Mac` puis `Product →
   Archive`
2. **Export** dans Organizer : `Distribute App → Copy App → Next →
   choisir un dossier`

Résultat : un fichier `voltapeak.app`.

### Créer un ZIP

```bash
ditto -c -k --keepParent voltapeak.app voltapeak.zip
```

### Créer un DMG

**Option simple, en ligne de commande :**

```bash
hdiutil create -volname "Voltapeak" \
               -srcfolder voltapeak.app \
               -ov -format UDZO \
               Voltapeak-1.0.dmg
```

**Option scriptée** (le projet inclut
`voltapeak.xcodeproj/create_dmg.sh`) :

```bash
./voltapeak.xcodeproj/create_dmg.sh ./voltapeak.app
```

### Limitation : warning au premier lancement

Sans notarisation, macOS affiche au premier lancement :

> *« voltapeak ne peut pas être ouvert car il provient d'un développeur
> non identifié »*

L'utilisateur doit alors **clic droit → Ouvrir** puis confirmer dans la
boîte de dialogue. Les lancements suivants sont normaux.

---

## Option 2 — Distribution publique (avec notarisation Apple)

Pour diffusion large (site web, GitHub Releases, etc.) sans warning au
lancement.

### Prérequis additionnels

- Compte **Apple Developer Program** actif (99 €/an)
- Certificat **Developer ID Application** installé dans le Keychain
- Hardened Runtime activé dans Signing & Capabilities :
  ```
  ✅ Hardened Runtime
  ```

### Étapes

1. **Archive** : `Product → Archive` (comme option 1).
2. **Distribute App** dans Organizer :
   - Choisir **« Developer ID »** (pas « Copy App »).
   - **Upload** pour notarisation (option par défaut).
   - Apple va signer + scanner + notariser (quelques minutes à quelques
     heures).
3. **Vérifier** :
   ```bash
   xcrun notarytool history --apple-id <votre@email.com>
   ```
4. **Agrafer le ticket** :
   ```bash
   xcrun stapler staple voltapeak.app
   ```
5. **Créer et agrafer le DMG** :
   ```bash
   hdiutil create -volname "Voltapeak" -srcfolder voltapeak.app \
                  -ov -format UDZO Voltapeak-1.0.dmg
   xcrun stapler staple Voltapeak-1.0.dmg
   ```

Résultat : `Voltapeak-1.0.dmg` notarisé, lancé sans warning sur
n'importe quel Mac.

---

## Vérifications post-build

```bash
# Signature
codesign -dv --verbose=4 voltapeak.app

# Entitlements et hardened runtime
codesign -d --entitlements - voltapeak.app

# Validation Gatekeeper (si notarisé)
spctl -a -vv -t install voltapeak.app
```

---

## Résolution de problèmes

| Symptôme | Cause | Solution |
|---|---|---|
| « voltapeak.app est endommagé » | Attributs de quarantaine après téléchargement | `xattr -cr voltapeak.app` |
| Warning « développeur non identifié » | App non notarisée | Clic droit → Ouvrir, ou notariser (option 2) |
| `notarytool` échoue | Compte Developer non actif / mot de passe d'app | Régénérer mot de passe d'app sur appleid.apple.com |
| L'app crashe sur d'autres Macs | Architecture ou macOS minimum incompatible | Vérifier Build Settings : Architectures = Standard, Deployment Target ≤ macOS de la cible |

---

## Tailles indicatives

| Fichier | Taille |
|---|---|
| `voltapeak.app` (bundle) | ≈ 5-10 Mo |
| `voltapeak.dmg` (UDZO) | ≈ 3-7 Mo |
| `voltapeak.zip` | ≈ 3-7 Mo |

---

## Méthodes de diffusion

| Canal | Pour |
|---|---|
| Email | < 25 Mo, audience restreinte |
| iCloud Drive / Dropbox | Diffusion interne via lien |
| GitHub Releases | Open source, publication officielle |
| Site web personnel | Distribution publique |

---

## Références Apple

- [Distributing your app outside the App Store](https://developer.apple.com/documentation/xcode/distributing-your-app-outside-the-app-store)
- [Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Hardened Runtime](https://developer.apple.com/documentation/security/hardened_runtime)
