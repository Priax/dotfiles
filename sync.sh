#!/bin/bash

# Script pour synchroniser/sauvegarder les dotfiles
# Usage: ./sync.sh [push|pull]

set -euo pipefail

REPO_DIR="$HOME/dotfiles"
BACKUP_DIR="$HOME/dotfiles_backup"
DATE=$(date +"%Y%m%d_%H%M%S")

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ ! -d "$REPO_DIR" ]; then
    echo -e "${RED}Erreur: Le répertoire $REPO_DIR n'existe pas.${NC}"
    exit 1
fi

backup() {
    echo -e "${YELLOW}Création d'une sauvegarde dans $BACKUP_DIR...${NC}"
    mkdir -p "$BACKUP_DIR"
    cp -r "$REPO_DIR" "$BACKUP_DIR/dotfiles_backup_$DATE"
    echo -e "${GREEN}Sauvegarde créée: $BACKUP_DIR/dotfiles_backup_$DATE${NC}"
}

push() {
    echo -e "${YELLOW}Synchronisation des dotfiles (push)...${NC}"
    
    FILES_TO_SYNC=(
        "$HOME/.bashrc"
        "$HOME/.bash_profile"
        "$HOME/.gitconfig"
        "$HOME/.gitignore"
        "$HOME/.ssh/config"
    )
    
    for file in "${FILES_TO_SYNC[@]}"; do
        if [ -f "$file" ]; then
            rel_path="$(realpath --relative-to=$HOME "$file")"
            dest="$REPO_DIR/$(dirname "$rel_path")"
            mkdir -p "$dest"
            
            cp -v "$file" "$dest/"
        fi
    done
    
    cd "$REPO_DIR"
    git add .
    
    git commit -m "Auto-sync dotfiles - $DATE"
    
    git push origin main
    
    echo -e "${GREEN}Synchronisation terminée avec succès !${NC}"
}

pull() {
    echo -e "${YELLOW}Mise à jour des dotfiles (pull)...${NC}"
    
    backup
    
    cd "$REPO_DIR"
    git pull origin main
    
    cp -v "$REPO_DIR/.bashrc" "$HOME/.bashrc"
    cp -v "$REPO_DIR/.bash_profile" "$HOME/.bash_profile"
    cp -v "$REPO_DIR/.gitconfig" "$HOME/.gitconfig"
    cp -v "$REPO_DIR/.gitignore" "$HOME/.gitignore"
    
    mkdir -p "$HOME/.ssh"
    cp -v "$REPO_DIR/.ssh/config" "$HOME/.ssh/config"
    chmod 600 "$HOME/.ssh/config"
    
    echo -e "${GREEN}Mise à jour terminée avec succès !${NC}"
}

if [ $# -eq 0 ]; then
    echo -e "${RED}Usage: $0 [push|pull]${NC}"
    exit 1
fi

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
