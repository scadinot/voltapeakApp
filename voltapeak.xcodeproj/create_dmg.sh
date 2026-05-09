#!/bin/bash

# Script de création de DMG pour Voltapeak
# Usage: ./create_dmg.sh [chemin/vers/voltapeak.app]

set -e  # Arrêter en cas d'erreur

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}   Voltapeak - Création de DMG${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo ""

# Vérifier qu'on a bien un argument ou utiliser le défaut
if [ $# -eq 0 ]; then
    APP_PATH="./voltapeak.app"
    echo -e "${BLUE}ℹ️  Aucun chemin spécifié, utilisation de : ${APP_PATH}${NC}"
else
    APP_PATH="$1"
fi

# Vérifier que l'application existe
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}❌ Erreur : voltapeak.app introuvable à ${APP_PATH}${NC}"
    echo ""
    echo "Veuillez d'abord exporter l'application depuis Xcode :"
    echo "  1. Product → Archive"
    echo "  2. Distribute App → Copy App"
    echo "  3. Puis lancer ce script"
    exit 1
fi

# Extraire le numéro de version depuis Info.plist
VERSION=$(defaults read "$(pwd)/$APP_PATH/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "1.0")
BUILD=$(defaults read "$(pwd)/$APP_PATH/Contents/Info" CFBundleVersion 2>/dev/null || echo "1")

echo -e "${GREEN}✅ Application trouvée${NC}"
echo -e "   Version : ${VERSION} (build ${BUILD})"
echo ""

# Nom du DMG
DMG_NAME="Voltapeak-${VERSION}.dmg"
TEMP_DMG="temp_voltapeak.dmg"

# Nettoyer les anciens fichiers
if [ -f "$DMG_NAME" ]; then
    echo -e "${BLUE}🗑  Suppression de l'ancien DMG...${NC}"
    rm "$DMG_NAME"
fi

if [ -f "$TEMP_DMG" ]; then
    rm "$TEMP_DMG"
fi

# Créer le DMG
echo -e "${BLUE}📦 Création du DMG...${NC}"

hdiutil create \
    -volname "Voltapeak" \
    -srcfolder "$APP_PATH" \
    -ov \
    -format UDZO \
    "$DMG_NAME"

echo ""
echo -e "${GREEN}✅ DMG créé avec succès !${NC}"
echo -e "   Fichier : ${DMG_NAME}"

# Obtenir la taille du fichier
DMG_SIZE=$(du -h "$DMG_NAME" | cut -f1)
echo -e "   Taille : ${DMG_SIZE}"

# Vérifier si l'app est signée
echo ""
echo -e "${BLUE}🔍 Vérification de la signature...${NC}"

if codesign -dv "$APP_PATH" 2>&1 | grep -q "Signature"; then
    echo -e "${GREEN}✅ Application signée${NC}"
    
    # Si notarisée, proposer d'agrafer
    if xcrun stapler validate "$APP_PATH" 2>&1 | grep -q "validated"; then
        echo -e "${GREEN}✅ Application notarisée${NC}"
        
        echo ""
        read -p "Agrafer le ticket de notarisation au DMG ? (o/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[OoYy]$ ]]; then
            echo -e "${BLUE}📎 Agrafage du ticket...${NC}"
            xcrun stapler staple "$DMG_NAME"
            echo -e "${GREEN}✅ Ticket agrafé${NC}"
        fi
    else
        echo -e "${BLUE}ℹ️  Application non notarisée (optionnel)${NC}"
    fi
else
    echo -e "${BLUE}ℹ️  Application non signée (distribution interne uniquement)${NC}"
fi

# Résumé final
echo ""
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Distribution prête !${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo ""
echo "Fichier créé : ${DMG_NAME}"
echo ""
echo "Pour distribuer :"
echo "  • Téléverser sur un serveur web"
echo "  • Partager via email/cloud"
echo "  • Publier sur GitHub Releases"
echo ""
echo "Instructions pour vos utilisateurs :"
echo "  1. Télécharger ${DMG_NAME}"
echo "  2. Double-cliquer sur le DMG"
echo "  3. Glisser Voltapeak.app vers /Applications"
echo "  4. Lancer Voltapeak"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
