# Environment (mirrors ~/.bashrc)
set -gx GOPATH ~/go
set -gx BUN_INSTALL ~/.bun
set -gx FLYCTL_INSTALL ~/.fly
set -gx EDITOR nvim

# Défini ici plutôt que dans fish_variables (état local, non versionné)
set -g fish_greeting 'Stay silly !! <3'

fish_add_path -g ~/.local/bin ~/bin $BUN_INSTALL/bin $FLYCTL_INSTALL/bin ~/.ghcup/bin ~/.deno/bin ~/.cargo/bin
fish_add_path -g -a /usr/local/go/bin $GOPATH/bin ~/.cabal/bin

if status is-interactive
    # Node version manager — falls back to system node when no version is selected
    if type -q fnm
        fnm env --use-on-cd --shell fish | source
    end

    alias neofetch=fastfetch

    if not set -q SSH_AUTH_SOCK
        eval (ssh-agent -c) >/dev/null
        ssh-add ~/.ssh/tsinghua_gitlab 2>/dev/null
    end
end
