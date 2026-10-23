#!/usr/bin/env bash
# Installation sur une nouvelle machine (Fedora ou macOS):
#   curl -fsSL https://raw.githubusercontent.com/Priax/dotfiles/main/bootstrap.sh | bash
# ou, si le repo est déjà cloné : ./bootstrap.sh

set -euo pipefail

# Sur une machine neuve, aucune clé SSH n'est encore liée à GitHub : on clone
# en HTTPS (public, sans authentification) et on garde SSH pour les push.
REPO_URL="${DOTFILES_REPO:-https://github.com/Priax/dotfiles.git}"
REPO_DIR="${DOTFILES_DIR:-$HOME/delivery/dotfiles}"

[[ $(id -u) -eq 0 ]] && {
    echo "Ne pas lancer en root." >&2
    exit 1
}

# Avec « curl | bash », stdin est le pipe: les questions doivent lire le terminal.
if [[ $(uname -s) == Darwin ]]; then
    # dot a besoin de bash 4+ et de rsync récent, que macOS ne fournit pas: Homebrew d'abord.
    find_brew() {
        local b
        for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
            if [[ -x $b ]]; then
                echo "$b"
                return
            fi
        done
    }
    brew_bin="$(find_brew)"
    if [[ -z $brew_bin ]]; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty
        brew_bin="$(find_brew)"
    fi
    eval "$("$brew_bin" shellenv)"
    brew install git bash rsync </dev/tty
else
    command -v git &>/dev/null || sudo dnf install -y git
fi

if [[ ! -d $REPO_DIR/.git ]]; then
    mkdir -p "$(dirname "$REPO_DIR")"
    git clone "$REPO_URL" "$REPO_DIR"
    git -C "$REPO_DIR" remote set-url --push origin git@github.com:Priax/dotfiles.git
fi

# bash du PATH: celui de Homebrew sur Mac (le /bin/bash 3.2 de macOS ne suffit pas)
exec bash "$REPO_DIR/dot" install </dev/tty
