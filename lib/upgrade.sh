# shellcheck shell=bash
# dot upgrade

upgrade_kitty() {
    local app="$HOME/.local/kitty.app"
    [[ -x $app/bin/kitty ]] || return 0

    local current latest
    current="v$("$app/bin/kitty" --version | awk '{ print $2 }')"
    latest="$(github_latest kovidgoyal/kitty)"

    [[ -n $latest && $current != "$latest" ]] || return 0

    info "kitty: $current → $latest..."
    curl -fsSL https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n ||
        fail "  échec de la mise à jour de kitty"
}

npm_pinned() {
    pkg_npm | { grep '.@' || true; } | sed 's/@[^@]*$//'
}

# Met à jour seulement les paquets npm globaux en retard.
# Deux exceptions:
# - les préversions notées nom@version par pkg_npm, qui passeraient à la dernière stable;
# - npm lui-même, qui suit Node (dnf upgrade, brew upgrade).
npm_outdated() {
    local npm=$1
    local pinned
    mapfile -t pinned < <(npm_pinned)

    { "$npm" outdated -g --json 2>/dev/null || true; } | python3 -I -c '
import json, sys

pinned = set(sys.argv[1:]) | {"npm"}
outdated = json.loads(sys.stdin.read() or "{}")

for name, info in sorted(outdated.items()):
    if name not in pinned and info.get("current") != info.get("latest"):
        print(f"{name}@latest")
' "${pinned[@]}"
}

upgrade_npm() {
    local npm
    npm="$(system_npm)" || return 0

    info "Paquets npm globaux..."

    local pkgs
    mapfile -t pkgs < <(npm_outdated "$npm")

    if ((${#pkgs[@]} == 0)); then
        info "  à jour"
        return 0
    fi

    "$npm" install -g "${pkgs[@]}" || fail "  échec de la mise à jour npm"
}

upgrade_system() {
    info "Paquets système..."

    if [[ $OS == macos ]]; then
        { brew update && brew upgrade; } || fail "  échec de brew upgrade"
    else
        sudo dnf upgrade --refresh || fail "  dnf: mise à jour interrompue"

        if have flatpak; then
            flatpak update -y || fail "  échec de flatpak update"
        fi

        upgrade_kitty
        install_lazygit
    fi

    install_nerd_font
}

upgrade_rust() {
    have rustup || return 0

    info "Rust (toolchains, puis outils cargo)..."
    rustup update || fail "  échec de rustup update"

    if have cargo; then
        install_cargo_tools <(pkg_cargo)
    fi
}

upgrade_haskell() {
    have ghcup || return 0

    info "Haskell (versions recommandées)..."
    ghcup upgrade || fail "  échec de ghcup upgrade"

    export GHCUP_SKIP_UPDATE_CHECK=1

    local tool
    for tool in ghc hls cabal stack; do
        if ghcup list -t "$tool" -c installed -r 2>/dev/null | grep -qw recommended; then
            ghcup set "$tool" recommended || fail "  échec de $tool"
        else
            ghcup install "$tool" recommended --set || fail "  échec de $tool"
        fi
    done
}

upgrade_node() {
    have fnm || return 0

    info "Node (dernière LTS via fnm)..."

    local lts
    lts="$(fnm ls-remote --lts --latest 2>/dev/null | awk '{ print $1 }' || true)"

    if [[ -n $lts ]] && fnm list | grep -qw "$lts"; then
        info "  $lts, dernière LTS, déjà installée"
    else
        fnm install --lts || fail "  échec de fnm"
    fi
}

upgrade_deno() {
    have deno || return 0

    deno upgrade || fail "  échec de deno upgrade"
}

# GOTOOLCHAIN=auto ajoute chaque version demandée sans jamais retirer l'ancienne
clean_go_toolchains() {
    have go || return 0

    local base dirs
    base="$(go env GOMODCACHE)/golang.org"
    mapfile -t dirs < <(find "$base" -maxdepth 1 -name "toolchain@*" 2>/dev/null | sort -V)
    ((${#dirs[@]} > 1)) || return 0

    local d v
    for d in "${dirs[@]:0:${#dirs[@]}-1}"; do
        v="${d##*/toolchain@}"
        info "  Go: suppression de l'ancienne toolchain ${v#v0.0.1-}"
        # le cache des modules est en lecture seule
        chmod -R u+w "$d"
        rm -rf "$d" "$(go env GOMODCACHE)/cache/download/golang.org/toolchain/@v/$v".*
    done
}

new_kernel_installed() {
    [[ $OS == linux ]] || return 1
    [[ -f /etc/udev-hid-bpf/0010-XPPen__ACK05.bpf.o ]] || return 1

    local newest
    newest="$(rpm -q --last kernel-core 2>/dev/null | head -1)"

    [[ $newest != *"$(uname -r)"* ]]
}

cmd_upgrade() {
    upgrade_system
    upgrade_rust
    upgrade_haskell
    upgrade_node
    upgrade_npm
    upgrade_deno

    info "nvim (plugins, parsers, paquets Mason)..."
    nvim_maint upgrade
    clean_go_toolchains

    if new_kernel_installed; then
        info "Nouveau noyau: après le redémarrage, « dot tablette » si la télécommande XP-Pen ne marche plus."
    fi

    ok "Terminé. lazy-lock.json a pu changer: « dot push » pour l'enregistrer."
}
