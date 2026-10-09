#!/usr/bin/env bash
# Installation sur une nouvelle machine :
#   curl -fsSL https://raw.githubusercontent.com/Priax/dotfiles/main/bootstrap.sh | bash
# ou, si le repo est déjà cloné : ./bootstrap.sh

set -euo pipefail

# Clone en HTTPS (pas encore de clé SSH), push en SSH.
REPO_URL="${DOTFILES_REPO:-https://github.com/Priax/dotfiles.git}"
REPO_DIR="${DOTFILES_DIR:-$HOME/delivery/dotfiles}"

[[ $(id -u) -eq 0 ]] && {
    echo "Ne pas lancer en root." >&2
    exit 1
}

command -v git &>/dev/null || sudo dnf install -y git

if [[ ! -d $REPO_DIR/.git ]]; then
    mkdir -p "$(dirname "$REPO_DIR")"
    git clone "$REPO_URL" "$REPO_DIR"
    git -C "$REPO_DIR" remote set-url --push origin git@github.com:Priax/dotfiles.git
fi

# Avec « curl | bash », stdin est le pipe : les questions doivent lire le terminal.
exec "$REPO_DIR/dot" install </dev/tty
