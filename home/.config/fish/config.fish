# Environment (mirrors ~/.bashrc)
set -gx GOPATH ~/go
set -gx BUN_INSTALL ~/.bun
set -gx EDITOR nvim

# Défini ici plutôt que dans fish_variables (état local, non versionné)
set -g fish_greeting 'Stay silly !! <3'

# macOS: Homebrew (absent sur Linux)
if test -x /opt/homebrew/bin/brew
    /opt/homebrew/bin/brew shellenv fish | source
end

fish_add_path -g ~/.local/bin ~/bin $BUN_INSTALL/bin ~/.ghcup/bin ~/.deno/bin ~/.cargo/bin
fish_add_path -g -a $GOPATH/bin ~/.cabal/bin

if status is-interactive
    # Node version manager: falls back to system node when no version is selected
    if type -q fnm
        fnm env --use-on-cd --shell fish | source
    end

    alias neofetch=fastfetch

    # macOS (launchd) et les bureaux Linux fournissent déjà un agent. Sinon (tty, ssh): un seul
    # agent partagé par tous les shells, sur un socket fixe, au lieu d'un nouveau par shell.
    if not set -q SSH_AUTH_SOCK
        set -gx SSH_AUTH_SOCK ~/.ssh/agent.sock
        ssh-add -l >/dev/null 2>&1
        # 2: aucun agent derrière le socket
        if test $status -eq 2
            rm -f $SSH_AUTH_SOCK
            ssh-agent -a $SSH_AUTH_SOCK >/dev/null
            test -f ~/.ssh/tsinghua_gitlab; and ssh-add ~/.ssh/tsinghua_gitlab 2>/dev/null
        end
    end
end
