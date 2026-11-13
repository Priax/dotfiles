# Même environnement que ~/.config/env.sh (bash, sh, zsh), à garder en phase
set -gx GOPATH ~/go
set -gx BUN_INSTALL ~/.bun
set -gx EDITOR nvim
set -gx NPM_CONFIG_PREFIX ~/.local

# ici plutôt que dans fish_variables, qui n'est pas suivi
set -g fish_greeting 'Stay silly !! <3'

# macOS: Homebrew (absent sur Linux)
if test -x /opt/homebrew/bin/brew
    /opt/homebrew/bin/brew shellenv fish | source
end

fish_add_path -g ~/.local/bin ~/bin $BUN_INSTALL/bin ~/.ghcup/bin ~/.deno/bin ~/.cargo/bin
fish_add_path -g -a $GOPATH/bin ~/.cabal/bin

if status is-interactive
    # fnm: change de version de Node selon le .nvmrc du dossier (--use-on-cd)
    if type -q fnm
        fnm env --use-on-cd --shell fish | source
    end

    alias neofetch=fastfetch
    alias yt='mpv --no-video --cache=yes --demuxer-readahead-secs=20'

    # macOS (launchd) et les bureaux Linux fournissent déjà un agent. Sinon (tty, ssh): un seul
    # agent partagé par tous les shells, sur un socket fixe, au lieu d'un nouveau par shell.
    # Les clés y sont ajoutées à leur première utilisation (AddKeysToAgent, ~/.config/ssh/common.conf).
    if not set -q SSH_AUTH_SOCK
        set -gx SSH_AUTH_SOCK ~/.ssh/agent.sock
        ssh-add -l >/dev/null 2>&1
        # 2: aucun agent derrière le socket
        if test $status -eq 2
            rm -f $SSH_AUTH_SOCK
            ssh-agent -a $SSH_AUTH_SOCK >/dev/null
        end
    end
end
