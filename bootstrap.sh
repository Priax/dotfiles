#!/bin/bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_DIR="$HOME/dotfiles"
BACKUP_DIR="$HOME/dotfiles_backup"
DATE=$(date +"%Y%m%d_%H%M%S")

error_exit() {
    echo -e "${RED}Erreur: $1${NC}" >&2
    exit 1
}

    echo -e "${YELLOW}Création d'une sauvegarde des fichiers existants...${NC}"
    mkdir -p "$BACKUP_DIR"
    
    if [ -f "$HOME/.bashrc" ]; then
        cp "$HOME/.bashrc" "$BACKUP_DIR/.bashrc_backup_$DATE"
    fi
    
    if [ -f "$HOME/.gitconfig" ]; then
        cp "$HOME/.gitconfig" "$BACKUP_DIR/.gitconfig_backup_$DATE"
    fi
    
    if [ -f "$HOME/.gitignore" ]; then
        cp "$HOME/.gitignore" "$BACKUP_DIR/.gitignore_backup_$DATE"
    fi
    
    if [ -f "$HOME/.ssh/config" ]; then
        cp "$HOME/.ssh/config" "$BACKUP_DIR/ssh_config_backup_$DATE"
    fi
    
    if [ -f "$HOME/.gnupg/gpg.conf" ]; then
        cp "$HOME/.gnupg/gpg.conf" "$BACKUP_DIR/gpg.conf_backup_$DATE"
    fi
    
    echo -e "${GREEN}Sauvegarde terminée dans $BACKUP_DIR${NC}"
}

install_dependencies() {
    echo -e "${YELLOW}Installation des dépendances...${NC}"
    
    if ! command -v git &> /dev/null; then
        echo -e "${BLUE}Installation de git...${NC}"
        sudo apt-get update && sudo apt-get install -y git
    fi
    
    if ! command -v nvim &> /dev/null; then
        echo -e "${BLUE}Installation de neovim...${NC}"
        sudo apt-get install -y neovim
    fi
    
    if ! command -v gnupg &> /dev/null; then
        echo -e "${BLUE}Installation de gnupg...${NC}"
        sudo apt-get install -y gnupg
    fi
    
    echo -e "${GREEN}Dependencies installed${NC}"
}

clone_repo() {
    if [ ! -d "$REPO_DIR" ]; then
        echo -e "${YELLOW}Clonage du répertoire des dotfiles...${NC}"
        git clone https://github.com/priax/dotfiles.git "$REPO_DIR"
    fi
}

deploy_dotfiles() {
    echo -e "${YELLOW}Déploiement des dotfiles...${NC}"
    
    mkdir -p "$HOME/.ssh"
    
    cp -v "$REPO_DIR/.bashrc" "$HOME/.bashrc"
    cp -v "$REPO_DIR/.gitconfig" "$HOME/.gitconfig"
    cp -v "$REPO_DIR/.gitignore" "$HOME/.gitignore"
    cp -v "$REPO_DIR/.ssh/config" "$HOME/.ssh/config"
    
    chmod 600 "$HOME/.ssh/config"
    
    git config --global core.excludesfile "$HOME/.gitignore"
    
    echo -e "${GREEN}Dotfiles déployés avec succès !${NC}"
}

setup_neovim() {
    echo -e "${YELLOW}Configuration de Neovim...${NC}"
    
    mkdir -p "$HOME/.config/nvim"
    
    if [ -d "$REPO_DIR/nvim" ]; then
        cp -r "$REPO_DIR/nvim/"* "$HOME/.config/nvim/"
        echo -e "${GREEN}Configuration Neovim déployée${NC}"
    else
        echo -e "${YELLOW}No Neovim config found in dotfiles${NC}"
    fi
}

# Fonction pour afficher un résumé
summary() {
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                  Installation terminée !                  ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Les fichiers suivants ont été installés :"
    echo "  - ~/.bashrc"
    echo "  - ~/.gitconfig"
    echo "  - ~/.gitignore"
    echo "  - ~/.ssh/config"
    echo "  - ~/.config/nvim/"
    echo ""
    echo "Une sauvegarde des fichiers existants a été créée dans :"
    echo "  $BACKUP_DIR"
    echo ""
    echo "Pour synchroniser vos dotfiles à l'avenir, utilisez :"
    echo "  cd $REPO_DIR && ./sync.sh push"
    echo "${NC}"
}

if [ "$(id -u)" -eq 0 ]; then
    error_exit "Ce script ne doit pas être exécuté en tant que root"
fi

# Menu principal
echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              Bootstrap script pour les dotfiles             ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo "${NC}"

read -p "Voulez-vous continuer ? (y/N) " -n 1 -r
 echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

echo -e "${YELLOW}Démarrage de l'installation...${NC}"
backup
install_dependencies
clone_repo
deploy_dotfiles
setup_neovim
summary

echo -e "${GREEN}Installation terminée avec succès !${NC}"
