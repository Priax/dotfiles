# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# Environnement (PATH, EDITOR…), commun avec ~/.profile
if [ -f ~/.config/env.sh ]; then
    . ~/.config/env.sh
fi

# La suite ne sert qu'en interactif. bash lit aussi ce fichier pour une commande lancée par ssh
# (scp, rsync, « ssh hôte cmd »), et l'agent SSH y démarrerait.
case $- in
    *i*) ;;
    *) return ;;
esac

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc

# fnm: change de version de Node selon le .nvmrc du dossier (--use-on-cd)
if command -v fnm >/dev/null; then
    eval "$(fnm env --use-on-cd --shell bash)"
fi

alias neofetch=fastfetch
alias yt='mpv --no-video --cache=yes --demuxer-readahead-secs=20'

# macOS (launchd) et les bureaux Linux fournissent déjà un agent. Sinon (tty, ssh): un seul
# agent partagé par tous les shells, sur un socket fixe, au lieu d'un nouveau par shell.
# Les clés y sont ajoutées à leur première utilisation (AddKeysToAgent, ~/.config/ssh/common.conf).
if [ -z "$SSH_AUTH_SOCK" ]; then
    export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
    ssh-add -l >/dev/null 2>&1
    # 2: aucun agent derrière le socket
    if [ $? -eq 2 ]; then
        rm -f "$SSH_AUTH_SOCK"
        ssh-agent -a "$SSH_AUTH_SOCK" >/dev/null
    fi
fi
