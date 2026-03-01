#!/bin/bash

# Script pour synchroniser/sauvegarder les dotfiles
# Usage: ./sync.sh [push|pull]

set -euo pipefail

REPO_DIR="$HOME/dotfiles"
BACKUP_DIR="$HOME/dotfiles_backup"
DATE=$(date +"%Y%m%d_%H%M%S")

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Vérifier que le répertoire des dotfiles existe
if [ ! -d "$REPO_DIR" ]; then
    echo -e "${RED}Erreur: Le répertoire $REPO_DIR n'existe pas.${NC}"
    exit 1
fi

# Fonction pour créer une sauvegarde
backup() {
    echo -e "${YELLOW}Création d'une sauvegarde dans $BACKUP_DIR...${NC}"
    mkdir -p "$BACKUP_DIR"
    cp -r "$REPO_DIR" "$BACKUP_DIR/dotfiles_backup_$DATE"
    echo -e "${GREEN}Sauvegarde créée: $BACKUP_DIR/dotfiles_backup_$DATE${NC}"
}

# Fonction pour pousser les changements
push() {
    echo -e "${YELLOW}Synchronisation des dotfiles (push)...${NC}"
    
    # Liste des fichiers à synchroniser (à adapter selon tes besoins)
    FILES_TO_SYNC=(
        "$HOME/.bashrc"
        "$HOME/.gitconfig"
        "$HOME/.gitignore_global"
        "$HOME/.ssh/config"
        "$HOME/.gnupg/gpg.conf"
    )
    
    # Copier les fichiers vers le répertoire des dotfiles
    for file in "${FILES_TO_SYNC[@]}"; do
        if [ -f "$file" ]; then
            # Créer la structure de répertoires si nécessaire
            rel_path="$(realpath --relative-to=$HOME "$file")"
            dest="$REPO_DIR/$(dirname "$rel_path")"
            mkdir -p "$dest"
            
            cp -v "$file" "$dest/"
        fi
    done
    
    # Ajouter les nouveaux fichiers à git
    cd "$REPO_DIR"
    git add .
    
    # Commit
    git commit -m "Auto-sync dotfiles - $DATE"
    
    # Push
    git push origin main
    
    echo -e "${GREEN}Synchronisation terminée avec succès !${NC}"
}

# Fonction pour tirer les changements
pull() {
    echo -e "${YELLOW}Mise à jour des dotfiles (pull)...${NC}"
    
    # Sauvegarde avant de pull
    backup
    
    cd "$REPO_DIR"
    git pull origin main
    
    # Copier les fichiers depuis le répertoire des dotfiles
    cp -v "$REPO_DIR/.bashrc" "$HOME/.bashrc"
    cp -v "$REPO_DIR/.gitconfig" "$HOME/.gitconfig"
    cp -v "$REPO_DIR/.gitignore_global" "$HOME/.gitignore_global"
    
    # Créer le répertoire .ssh si nécessaire
    mkdir -p "$HOME/.ssh"
    cp -v "$REPO_DIR/.ssh/config" "$HOME/.ssh/config"
    chmod 600 "$HOME/.ssh/config"
    
    # Créer le répertoire .gnupg si nécessaire
    mkdir -p "$HOME/.gnupg"
    cp -v "$REPO_DIR/.gnupg/gpg.conf" "$HOME/.gnupg/gpg.conf"
    chmod 600 "$HOME/.gnupg/gpg.conf"
    
    echo -e "${GREEN}Mise à jour terminée avec succès !${NC}"
}

# Vérifier l'argument
if [ $# -eq 0 ]; then
    echo -e "${RED}Usage: $0 [push|pull]${NC}"
    exit 1
fi

# Exécuter la commande demandée
case "$1" in
    push)
        push
        ;;
    pull)
        pull
        ;;
    *)
        echo -e "${RED}Commande invalide. Utilisez 'push' ou 'pull'.${NC}"
        exit 1
        ;;
esac