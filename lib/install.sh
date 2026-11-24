# shellcheck shell=bash
# Nouvelle machine: outils, kitty, police, dépendances de nvim, tablette, réglages macOS

rustup_list() {
    local f="$PKG_DIR/rustup.txt"

    if [[ ! -s $f ]]; then
        f="$(find "$REPO_DIR/packages" -name rustup.txt | head -n 1)"
    fi

    echo "$f"
}

install_rust_toolchains() {
    local f
    f="$(rustup_list)"

    if [[ ! -s $f ]]; then
        rustup toolchain install stable --component rust-analyzer && rustup default stable
        return
    fi

    local name def comps targets
    local args

    while read -r name def comps targets; do
        args=()
        if [[ $comps != - ]]; then
            args+=(--component "$comps")
        fi
        if [[ $targets != - ]]; then
            args+=(--target "$targets")
        fi

        rustup toolchain install "$name" "${args[@]}" || fail "  échec de la toolchain $name"

        if [[ $def == default ]]; then
            rustup default "$name"
        fi
    done <"$f"

    return 0
}

install_rust() {
    [[ -x $HOME/.cargo/bin/rustup ]] && return 0
    ask "Installer Rust (rustup et les toolchains de rustup.txt) ?" || return 0

    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |
        sh -s -- -y --no-modify-path --default-toolchain none || fail "  échec de rustup"

    PATH="$HOME/.cargo/bin:$PATH"

    if have rustup; then
        install_rust_toolchains
    fi
}

install_haskell() {
    if [[ ! -x $HOME/.ghcup/bin/ghcup ]] && ask "Installer Haskell (ghcup: GHC, cabal, stack, HLS) ?"; then
        if [[ $OS == linux ]]; then
            sudo dnf install -y gcc gcc-c++ gmp gmp-devel make ncurses ncurses-compat-libs xz perl
        fi

        curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org |
            BOOTSTRAP_HASKELL_NONINTERACTIVE=1 BOOTSTRAP_HASKELL_INSTALL_HLS=1 sh ||
            fail "  échec de ghcup"
    fi

    [[ -x $HOME/.ghcup/bin/ghcup ]] || return 0
    PATH="$HOME/.ghcup/bin:$HOME/.cabal/bin:$PATH"

    if ! have cabal-fmt && ask "Compiler cabal-fmt (plusieurs minutes) ?"; then
        { cabal update && cabal install cabal-fmt --allow-newer=base; } || fail "  échec de cabal-fmt"
    fi
}

install_node() {
    have fnm && return 0
    ask "Installer fnm et la dernière LTS de Node ?" || return 0

    if [[ $OS == macos ]]; then
        brew install fnm
    else
        curl -fsSL https://fnm.vercel.app/install |
            bash -s -- --install-dir "$HOME/.local/bin" --skip-shell || fail "  échec de fnm"
        PATH="$HOME/.local/bin:$PATH"
    fi

    if have fnm; then
        { fnm install --lts && fnm default lts-latest; } || fail "  échec de l'installation de Node"
    fi
}

install_deno() {
    [[ -x $HOME/.deno/bin/deno ]] && return 0
    ask "Installer Deno ?" || return 0

    curl -fsSL https://deno.land/install.sh | sh -s -- -y --no-modify-path || fail "  échec de deno"
}

install_tools() {
    info "Outils hors gestionnaire de paquets..."

    install_rust
    install_haskell
    install_node
    install_deno
}

install_kitty() {
    local app="$HOME/.local/kitty.app"
    local apps="$HOME/.local/share/applications"

    [[ -x $app/bin/kitty ]] && return

    info "Installation de kitty..."
    if ! curl -fsSL https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n; then
        fail "  échec de l'installeur kitty"
        return
    fi

    mkdir -p "$HOME/.local/bin" "$apps"
    ln -sf "$app/bin/kitty" "$app/bin/kitten" "$HOME/.local/bin/"
    cp "$app/share/applications/kitty.desktop" "$app/share/applications/kitty-open.desktop" "$apps/"

    local icon="$app/share/icons/hicolor/256x256/apps/kitty.png"
    sed -i "s|Icon=kitty|Icon=$icon|g; s|Exec=kitty|Exec=$app/bin/kitty|g" \
        "$apps/kitty.desktop" "$apps/kitty-open.desktop"
}

setup_dnf_repos() {
    local list=$1
    local fedora
    fedora="$(rpm -E %fedora)"

    local rpmfusion="https://mirrors.rpmfusion.org"
    local docker_repo="https://download.docker.com/linux/fedora/docker-ce.repo"
    local gh_repo="https://cli.github.com/packages/rpm/gh-cli.repo"
    local pgadmin_repo="https://ftp.postgresql.org/pub/pgadmin/pgadmin4/yum/pgadmin4-fedora-repo-2-1.noarch.rpm"

    if grep -q '^rpmfusion-free' "$list"; then
        sudo dnf install -y "$rpmfusion/free/fedora/rpmfusion-free-release-$fedora.noarch.rpm" ||
            fail "  échec de RPM Fusion free"
    fi

    if grep -q '^rpmfusion-nonfree' "$list"; then
        sudo dnf install -y "$rpmfusion/nonfree/fedora/rpmfusion-nonfree-release-$fedora.noarch.rpm" ||
            fail "  échec de RPM Fusion nonfree"
    fi

    if grep -q '^docker-ce' "$list" && [[ ! -f /etc/yum.repos.d/docker-ce.repo ]]; then
        sudo dnf config-manager addrepo --from-repofile="$docker_repo" ||
            fail "  échec du dépôt docker-ce"
    fi

    if grep -q '^gh-cli' "$list" && [[ ! -f /etc/yum.repos.d/gh-cli.repo ]]; then
        sudo dnf config-manager addrepo --from-repofile="$gh_repo" ||
            fail "  échec du dépôt gh-cli"
    fi

    if grep -q '^pgAdmin4' "$list"; then
        sudo dnf install -y "$pgadmin_repo" || fail "  échec du dépôt pgAdmin4"
    fi

    return 0
}

github_latest() {
    curl -fsSI --max-time 15 "https://github.com/$1/releases/latest" 2>/dev/null |
        awk -F/ 'tolower($1) ~ /^location:/ { print $NF }' |
        tr -d '\r' || true
}

download_verified() {
    local dir=$1
    local url=$2
    local archive=$3
    local sums=$4

    curl -fsSL -o "$dir/$archive" "$url/$archive" &&
        curl -fsSL -o "$dir/$sums" "$url/$sums" &&
        (cd "$dir" && grep " ${archive//./\\.}\$" "$sums" | sha256sum -c --quiet -)
}

install_nerd_font() {
    [[ $OS == linux ]] || return 0

    local dest="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
    local latest current
    latest="$(github_latest ryanoasis/nerd-fonts)"
    current="$(cat "$dest/.version" 2>/dev/null || true)"

    if [[ -z $latest ]]; then
        [[ -n $current ]] && return 0
        fail "  dernière version de JetBrainsMono Nerd Font introuvable (hors ligne ?)"
        return 0
    fi
    [[ $current == "$latest" ]] && return 0

    info "JetBrainsMono Nerd Font: ${current:-absente} → $latest..."

    local url="https://github.com/ryanoasis/nerd-fonts/releases/download/$latest"
    local tmp
    tmp="$(mktemp -d)"

    mkdir -p "$tmp/font"

    if download_verified "$tmp" "$url" JetBrainsMono.tar.xz SHA-256.txt &&
        tar -xJf "$tmp/JetBrainsMono.tar.xz" -C "$tmp/font" --wildcards '*.ttf'; then
        echo "$latest" >"$tmp/font/.version"

        rm -rf "$dest"
        mkdir -p "$(dirname "$dest")"
        mv "$tmp/font" "$dest"
        fc-cache -f "$dest" >/dev/null

        ok "  installée: relance kitty pour qu'il l'utilise (il ne recharge pas les polices à chaud)"
    else
        fail "  téléchargement impossible, police à installer à la main"
    fi

    rm -rf "$tmp"
}

lazygit_arch() {
    case "$(uname -m)" in
    x86_64) echo x86_64 ;;
    aarch64) echo arm64 ;;
    *) return 1 ;;
    esac
}

install_lazygit() {
    [[ $OS == linux ]] || return 0

    local bin="$HOME/.local/bin/lazygit"
    local latest current
    latest="$(github_latest jesseduffield/lazygit)"
    current="$("$bin" --version 2>/dev/null | sed -n 's/.*, version=\([^,]*\),.*/\1/p' || true)"

    if [[ -z $latest ]]; then
        [[ -x $bin ]] && return 0
        fail "  dernière version de lazygit introuvable (hors ligne ?)"
        return 0
    fi
    [[ v$current == "$latest" ]] && return 0

    local arch
    if ! arch="$(lazygit_arch)"; then
        fail "  lazygit: pas de binaire prévu pour $(uname -m)"
        return 0
    fi

    info "lazygit: ${current:-absent} → ${latest#v}..."

    local file="lazygit_${latest#v}_linux_$arch.tar.gz"
    local url="https://github.com/jesseduffield/lazygit/releases/download/$latest"
    local tmp
    tmp="$(mktemp -d)"

    if download_verified "$tmp" "$url" "$file" checksums.txt &&
        tar -xzf "$tmp/$file" -C "$tmp" lazygit; then
        mkdir -p "$(dirname "$bin")"
        install -m 755 "$tmp/lazygit" "$bin"
    else
        fail "  échec de l'installation de lazygit"
    fi

    rm -rf "$tmp"
}

install_base() {
    info "Installation des dépendances de base..."

    if [[ $OS == macos ]]; then
        have brew || die "Homebrew introuvable (bootstrap.sh l'installe)"

        brew install git rsync bash fish neovim gitleaks shellcheck
        brew install --cask kitty font-jetbrains-mono-nerd-font
    else
        sudo dnf install -y git rsync fish neovim gitleaks ShellCheck
        install_kitty
        install_nerd_font
    fi

    install_nvim_deps
}

# Dépendances de la config nvim.
# À garder en phase avec lua/configs/health.lua (:checkhealth configs).
#   go, npm, python3       paquets Mason
#   tree-sitter, gcc       parsers de nvim-treesitter
#   rg, fd                 picker et explorateur de Snacks
#   lazygit                <leader>gg
#   magick, ffmpeg         image.nvim, aperçu des vidéos
install_nvim_deps() {
    info "Dépendances de la config nvim..."

    if [[ $OS == macos ]]; then
        brew install go node ripgrep fd lazygit tree-sitter-cli imagemagick ffmpeg
        return
    fi

    local deps=(
        golang /usr/bin/npm /usr/bin/python3 /usr/bin/tree-sitter gcc make unzip
        /usr/bin/rg /usr/bin/fd /usr/bin/magick /usr/bin/ffmpeg /usr/bin/ffprobe /usr/bin/wl-copy
    )
    sudo dnf install -y "${deps[@]}"

    install_lazygit
}

# Télécommande XP-Pen ACK05 (tablette Deco Pro XLW). Le correctif HID-BPF de Fedora
# (udev-hid-bpf) ne se charge plus sur le noyau 7.3. Celui de ~/src/hid-bpf-ack05 est compilé
# pour le noyau en cours, puis installé dans /etc/udev-hid-bpf avec sa règle udev.
# À relancer quand, après un nouveau noyau, la télécommande renvoie ses raccourcis d'usine.
XPPEN_DIR="$HOME/src/hid-bpf-ack05"

build_xppen_fix() {
    make -C "$XPPEN_DIR" clean &&
        make -C "$XPPEN_DIR" &&
        sudo make -C "$XPPEN_DIR" install
}

cmd_tablette() {
    [[ $OS == linux ]] || die "dot tablette: Linux seulement"
    [[ -f $XPPEN_DIR/Makefile ]] || die "$(pretty "$XPPEN_DIR") absent: « dot apply » d'abord"

    info "Correctif de la télécommande XP-Pen (noyau $(uname -r))..."

    if ! sudo dnf install -y clang llvm bpftool make udev-hid-bpf; then
        fail "  dépendances du correctif XP-Pen"
        return
    fi

    if ! build_xppen_fix; then
        fail "  correctif XP-Pen: échec de la compilation ou de l'installation"
        return
    fi

    sudo udevadm control --reload
    ok "  installé: débrancher et rebrancher la télécommande (ou son dongle)"
}

cmd_defaults() {
    [[ $OS == macos ]] || die "dot defaults: macOS seulement"

    info "Réglages macOS (packages/macos/defaults.sh)..."
    bash "$PKG_DIR/defaults.sh"
    ok "Réglages appliqués (l'apparence et le clavier peuvent demander de rouvrir la session)."
}

login_shell() {
    if [[ $OS == macos ]]; then
        dscl . -read "/Users/$USER" UserShell | awk '{ print $2 }'
    else
        getent passwd "$USER" | cut -d: -f7
    fi
}

switch_to_fish() {
    [[ $(login_shell) == */fish ]] && return 0
    ask "Passer à fish comme shell par défaut ?" || return 0

    local fish
    fish="$(command -v fish)"

    if ! grep -qx "$fish" /etc/shells; then
        echo "$fish" | sudo tee -a /etc/shells >/dev/null
    fi

    chsh -s "$fish"
}

install_dot_command() {
    mkdir -p "$HOME/.local/bin"
    ln -sf "$REPO_DIR/dot" "$HOME/.local/bin/dot"
    ok "Commande « dot » disponible dans ~/.local/bin"
}

final_hints() {
    if ! compgen -G "$HOME/.ssh/id_*" >/dev/null; then
        info "Pas de clé SSH: copie ~/.ssh depuis l'ancienne machine, sinon « dot push » ne pourra pas pousser."
    fi

    if [[ $OS == macos && ! -f $HOME/.gitconfig.local ]]; then
        info "Pas de ~/.gitconfig.local: à recréer pour git-lfs (non suivi par dotfiles)."
    fi
}

cmd_install() {
    [[ $(id -u) -eq 0 ]] && die "ne pas lancer en root"

    install_base
    cmd_apply

    install_tools
    install_packages
    setup_groups

    info "nvim (plugins, parsers, paquets Mason)..."
    nvim_maint install

    if [[ $OS == macos ]]; then
        cmd_defaults
    fi

    if [[ $OS == linux && -f $XPPEN_DIR/Makefile ]] && ask "Installer le correctif de la télécommande XP-Pen ?"; then
        cmd_tablette
    fi

    install_dot_command
    switch_to_fish

    ok "Installation terminée."
    final_hints
}
