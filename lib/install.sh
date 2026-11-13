# shellcheck shell=bash
# Nouvelle machine: outils, kitty, police, dépendances de nvim, tablette, réglages macOS

# Toolchains de rustup.txt. Les noms n'ont pas le triplet de l'hôte, donc la liste de l'autre
# OS fait l'affaire s'il n'y en a pas pour celui-ci.
install_rust_toolchains() {
    local f="$PKG_DIR/rustup.txt" name def comps targets args
    [[ -s $f ]] || f="$(find "$REPO_DIR/packages" -name rustup.txt | head -n 1)"
    if [[ ! -s $f ]]; then
        rustup toolchain install stable --component rust-analyzer && rustup default stable
        return
    fi
    while read -r name def comps targets; do
        args=()
        [[ $comps != - ]] && args+=(--component "$comps")
        [[ $targets != - ]] && args+=(--target "$targets")
        rustup toolchain install "$name" "${args[@]}" || fail "  échec de la toolchain $name"
        [[ $def == default ]] && rustup default "$name"
    done <"$f"
    return 0
}

# Outils installés par leur script officiel, dans ~. Aucun gestionnaire de paquets ne les
# connaît, ils n'apparaissent donc pas dans packages/.
install_tools() {
    info "Outils hors gestionnaire de paquets..."
    if [[ ! -x $HOME/.cargo/bin/rustup ]] && ask "Installer Rust (rustup et les toolchains de rustup.txt) ?"; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |
            sh -s -- -y --no-modify-path --default-toolchain none || fail "  échec de rustup"
        # cargo.txt en aura besoin plus loin dans ce même script
        PATH="$HOME/.cargo/bin:$PATH"
        have rustup && install_rust_toolchains
    fi

    if [[ ! -x $HOME/.ghcup/bin/ghcup ]] && ask "Installer Haskell (ghcup: GHC, cabal, stack, HLS) ?"; then
        # dépendances demandées par ghcup sur Fedora (sur Mac, les outils Xcode suffisent)
        [[ $OS == linux ]] &&
            sudo dnf install -y gcc gcc-c++ gmp gmp-devel make ncurses ncurses-compat-libs xz perl
        curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org |
            BOOTSTRAP_HASKELL_NONINTERACTIVE=1 BOOTSTRAP_HASKELL_INSTALL_HLS=1 sh || fail "  échec de ghcup"
    fi
    if [[ -x $HOME/.ghcup/bin/ghcup ]]; then
        PATH="$HOME/.ghcup/bin:$HOME/.cabal/bin:$PATH"
        # cabal-fmt formate les .cabal dans nvim. Sa version 0.1.12 limite base à 4.19 (GHC 9.8),
        # mais compile très bien avec le GHC recommandé, d'où --allow-newer=base.
        if ! have cabal-fmt && ask "Compiler cabal-fmt (plusieurs minutes) ?"; then
            { cabal update && cabal install cabal-fmt --allow-newer=base; } || fail "  échec de cabal-fmt"
        fi
    fi

    if ! have fnm && ask "Installer fnm et la dernière LTS de Node ?"; then
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
    fi
    if [[ ! -x $HOME/.deno/bin/deno ]] && ask "Installer Deno ?"; then
        curl -fsSL https://deno.land/install.sh | sh -s -- -y --no-modify-path || fail "  échec de deno"
    fi
}

# kitty par son installeur officiel (dans ~/.local/kitty.app), plus à jour que le paquet Fedora.
# Sur Mac, le cask Homebrew installe la même application.
install_kitty() {
    local app="$HOME/.local/kitty.app" apps="$HOME/.local/share/applications"
    [[ -x $app/bin/kitty ]] && return
    info "Installation de kitty (installeur officiel)..."
    curl -fsSL https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n || {
        fail "  échec de l'installeur kitty"
        return
    }
    # intégration au bureau, comme dans la doc de kitty
    mkdir -p "$HOME/.local/bin" "$apps"
    ln -sf "$app/bin/kitty" "$app/bin/kitten" "$HOME/.local/bin/"
    cp "$app/share/applications/kitty.desktop" "$app/share/applications/kitty-open.desktop" "$apps/"
    sed -i "s|Icon=kitty|Icon=$app/share/icons/hicolor/256x256/apps/kitty.png|g; s|Exec=kitty|Exec=$app/bin/kitty|g" \
        "$apps/kitty.desktop" "$apps/kitty-open.desktop"
}

# Dépôts tiers listés dans dnf-repos.txt, chacun installé comme le dit sa doc
setup_dnf_repos() {
    local list=$1 fedora
    fedora="$(rpm -E %fedora)"
    if grep -q '^rpmfusion-free' "$list"; then
        sudo dnf install -y "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$fedora.noarch.rpm" ||
            fail "  échec de RPM Fusion free"
    fi
    if grep -q '^rpmfusion-nonfree' "$list"; then
        sudo dnf install -y "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$fedora.noarch.rpm" ||
            fail "  échec de RPM Fusion nonfree"
    fi
    if grep -q '^docker-ce' "$list" && [[ ! -f /etc/yum.repos.d/docker-ce.repo ]]; then
        sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo ||
            fail "  échec du dépôt docker-ce"
    fi
    if grep -q '^pgAdmin4' "$list"; then
        sudo dnf install -y https://ftp.postgresql.org/pub/pgadmin/pgadmin4/yum/pgadmin4-fedora-repo-2-1.noarch.rpm ||
            fail "  échec du dépôt pgAdmin4"
    fi
    return 0
}

# Tag de la dernière release d'un repo GitHub, lu dans la redirection de /releases/latest
# (l'API GitHub, elle, limite le nombre de requêtes). Vide si GitHub ne répond pas en 15 s.
github_latest() {
    curl -fsSI --max-time 15 "https://github.com/$1/releases/latest" 2>/dev/null |
        awk -F/ 'tolower($1) ~ /^location:/ {print $NF}' | tr -d '\r' || true
}

# JetBrainsMono Nerd Font (police de kitty.conf), absente des dépôts Fedora: installée ou mise
# à jour depuis la dernière release, vérifiée avec son SHA-256.txt. Sur Mac c'est un cask.
install_nerd_font() {
    [[ $OS == linux ]] || return 0
    local dest="$HOME/.local/share/fonts/JetBrainsMonoNerdFont" latest current tmp
    latest="$(github_latest ryanoasis/nerd-fonts)"
    current="$(cat "$dest/.version" 2>/dev/null || true)"
    if [[ -z $latest ]]; then
        [[ -n $current ]] && return 0
        fail "  dernière version de JetBrainsMono Nerd Font introuvable (hors ligne ?)"
        return 0
    fi
    [[ $current == "$latest" ]] && return 0
    info "JetBrainsMono Nerd Font: ${current:-absente} → $latest..."
    tmp="$(mktemp -d)"
    # décompressée à côté, l'ancienne version n'est remplacée qu'une fois la nouvelle prête
    mkdir -p "$tmp/font"
    local url="https://github.com/ryanoasis/nerd-fonts/releases/download/$latest"
    if curl -fsSL -o "$tmp/JetBrainsMono.tar.xz" "$url/JetBrainsMono.tar.xz" &&
        curl -fsSL -o "$tmp/SHA-256.txt" "$url/SHA-256.txt" &&
        (cd "$tmp" && grep ' JetBrainsMono\.tar\.xz$' SHA-256.txt | sha256sum -c --quiet -) &&
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

# lazygit n'est pas dans les dépôts Fedora: on prend le binaire de la dernière release, vérifié
# avec son checksums.txt. dot upgrade relance cette fonction, qui ne fait rien si c'est à jour.
# Sur Mac, brew s'en occupe.
install_lazygit() {
    [[ $OS == linux ]] || return 0
    local bin="$HOME/.local/bin/lazygit" latest current arch file url tmp
    latest="$(github_latest jesseduffield/lazygit)"
    current="$("$bin" --version 2>/dev/null | sed -n 's/.*, version=\([^,]*\),.*/\1/p' || true)"
    if [[ -z $latest ]]; then
        [[ -x $bin ]] && return 0
        fail "  dernière version de lazygit introuvable (hors ligne ?)"
        return 0
    fi
    [[ v$current == "$latest" ]] && return 0
    case "$(uname -m)" in
        x86_64) arch=x86_64 ;;
        aarch64) arch=arm64 ;;
        *)
            fail "  lazygit: pas de binaire prévu pour $(uname -m)"
            return 0
            ;;
    esac
    info "lazygit: ${current:-absent} → ${latest#v}..."
    file="lazygit_${latest#v}_linux_$arch.tar.gz"
    url="https://github.com/jesseduffield/lazygit/releases/download/$latest"
    tmp="$(mktemp -d)"
    if curl -fsSL -o "$tmp/$file" "$url/$file" &&
        curl -fsSL -o "$tmp/checksums.txt" "$url/checksums.txt" &&
        (cd "$tmp" && grep " $file\$" checksums.txt | sha256sum -c --quiet -) &&
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
        # pour zsh, Homebrew est mis dans le PATH par ~/.zprofile → ~/.profile → ~/.config/env.sh
    else
        sudo dnf install -y git rsync fish neovim gitleaks ShellCheck
        install_kitty
        install_nerd_font
    fi
    install_nvim_deps
}

# Dépendances de la config nvim, installées explicitement: dans dnf.txt elles peuvent n'être
# qu'une dépendance d'un autre paquet, donc absentes de la liste.
# À garder en phase avec lua/configs/health.lua (:checkhealth configs).
#   go, npm, python3       paquets Mason
#   tree-sitter, gcc       parsers de nvim-treesitter
#   rg, fd                 picker et explorateur de Snacks
#   lazygit                <leader>gg
#   magick, ffmpeg         image.nvim, aperçu des vidéos
install_nvim_deps() {
    info "Dépendances de la config nvim..."
    if [[ $OS == macos ]]; then
        # gcc et python3 viennent des outils Xcode, installés avec Homebrew
        brew install go node ripgrep fd lazygit tree-sitter-cli imagemagick ffmpeg
    else
        # des chemins plutôt que des noms de paquets: dnf choisit lui-même le fournisseur
        # (ffmpeg-free de Fedora, ou ffmpeg de RPM Fusion si le dépôt est configuré)
        sudo dnf install -y golang /usr/bin/npm /usr/bin/python3 /usr/bin/tree-sitter gcc make unzip \
            /usr/bin/rg /usr/bin/fd /usr/bin/magick /usr/bin/ffmpeg /usr/bin/ffprobe /usr/bin/wl-copy
        install_lazygit
    fi
}

# Télécommande XP-Pen ACK05 (tablette Deco Pro XLW). Le correctif HID-BPF de Fedora
# (udev-hid-bpf) ne se charge plus sur le noyau 7.3. Celui de ~/src/hid-bpf-ack05 est compilé
# pour le noyau en cours, puis installé dans /etc/udev-hid-bpf avec sa règle udev.
# À relancer quand, après un nouveau noyau, la télécommande renvoie ses raccourcis d'usine.
XPPEN_DIR="$HOME/src/hid-bpf-ack05"
cmd_tablette() {
    [[ $OS == linux ]] || die "dot tablette: Linux seulement"
    [[ -f $XPPEN_DIR/Makefile ]] || die "$(pretty "$XPPEN_DIR") absent: « dot apply » d'abord"
    info "Correctif de la télécommande XP-Pen (noyau $(uname -r))..."
    sudo dnf install -y clang llvm bpftool make udev-hid-bpf || {
        fail "  dépendances du correctif XP-Pen"
        return
    }
    { make -C "$XPPEN_DIR" clean && make -C "$XPPEN_DIR" && sudo make -C "$XPPEN_DIR" install; } || {
        fail "  correctif XP-Pen: échec de la compilation ou de l'installation"
        return
    }
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
        dscl . -read "/Users/$USER" UserShell | awk '{print $2}'
    else
        getent passwd "$USER" | cut -d: -f7
    fi
}

cmd_install() {
    [[ $(id -u) -eq 0 ]] && die "ne pas lancer en root"
    install_base

    cmd_apply
    # avant les paquets: cargo.txt a besoin du cargo de rustup
    install_tools
    install_packages
    setup_groups
    # après les paquets: Mason a besoin de go et npm
    info "nvim (plugins, parsers, paquets Mason)..."
    nvim_maint install
    [[ $OS == macos ]] && cmd_defaults
    if [[ $OS == linux && -f $XPPEN_DIR/Makefile ]] && ask "Installer le correctif de la télécommande XP-Pen ?"; then
        cmd_tablette
    fi

    mkdir -p "$HOME/.local/bin"
    ln -sf "$REPO_DIR/dot" "$HOME/.local/bin/dot"
    ok "Commande « dot » disponible dans ~/.local/bin"

    if [[ $(login_shell) != */fish ]] && ask "Passer à fish comme shell par défaut ?"; then
        local fish
        fish="$(command -v fish)"
        # chsh refuse un shell absent de /etc/shells (c'est le cas du fish de Homebrew)
        grep -qx "$fish" /etc/shells || echo "$fish" | sudo tee -a /etc/shells >/dev/null
        chsh -s "$fish"
    fi
    ok "Installation terminée."
    compgen -G "$HOME/.ssh/id_*" >/dev/null ||
        info "Pas de clé SSH: copie ~/.ssh depuis l'ancienne machine, sinon « dot push » ne pourra pas pousser."
    if [[ $OS == macos && ! -f $HOME/.gitconfig.local ]]; then
        info "Pas de ~/.gitconfig.local: à recréer pour git-lfs (non suivi par dotfiles)."
    fi
}
