#!/usr/bin/env bash
# Réglages macOS (Réglages Système, Finder, Dock…), lancé par « dot install » et « dot defaults ».
# Relançable sans risque: chaque commande pose une valeur, rien n'est basculé.
# Lire un réglage pour l'ajouter ici: defaults read <domaine> <clé>, defaults read-type pour son type.

set -euo pipefail

# Clavier: délai avant répétition court, répétition plutôt que le menu des accents en maintenant une touche
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Texte: pas de correction orthographique automatique ni de « . » sur double espace
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# Apparence sombre (prise en compte à la prochaine session)
defaults write NSGlobalDomain AppleInterfaceStyle -string Dark

# Trackpad: toucher pour cliquer (trackpad intégré, Magic Trackpad, et réglage propre à cette machine)
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Finder: barre du chemin et d'état, vue en colonnes, dossiers en premier, nouvelle fenêtre sur le Bureau
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder FXPreferredViewStyle -string clmv
defaults write com.apple.finder _FXSortFoldersFirst -bool true
defaults write com.apple.finder NewWindowTarget -string PfDe
defaults write com.apple.finder NewWindowTargetPath -string "file://$HOME/Desktop/"

# Dock: petites icônes, affiché seulement au survol du bas de l'écran
defaults write com.apple.dock tilesize -float 30
defaults write com.apple.dock autohide -bool true

# Finder et Dock relisent leurs réglages au redémarrage
killall Finder Dock 2>/dev/null || true
