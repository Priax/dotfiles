# shellcheck shell=bash
# dot upgrade

# kitty installé par son installeur: on ne le relance que s'il y a une nouvelle version
upgrade_kitty() {
    local app="$HOME/.local/kitty.app" current latest
    [[ -x $app/bin/kitty ]] || return 0
    current="v$("$app/bin/kitty" --version | awk '{print $2}')"
    latest="$(github_latest kovidgoyal/kitty)"
    if [[ -n $latest && $current != "$latest" ]]; then
        info "kitty: $current → $latest..."
        curl -fsSL https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n ||
            fail "  échec de la mise à jour de kitty"
    fi
}

# Met à jour seulement les paquets npm globaux en retard (tout réinstaller prenait ~25 s).
# Deux exceptions:
# - les préversions notées nom@version par pkg_npm, qui passeraient à la dernière stable;
# - npm lui-même, qui suit Node (dnf upgrade, brew upgrade).
upgrade_npm() {
    local npm pkgs
    npm="$(system_npm)" || return 0
    info "Paquets npm globaux..."
    # npm outdated sort avec le code 1 quand il trouve des paquets en retard
    mapfile -t pkgs < <({ "$npm" outdated -g --json 2>/dev/null || true; } | python3 -I -c '
import json, sys
pinned = set(sys.argv[1:]) | {"npm"}
for name, info in sorted(json.loads(sys.stdin.read() or "{}").items()):
    if name not in pinned and info.get("current") != info.get("latest"):
        print(f"{name}@latest")
' $(pkg_npm | { grep '.@' || true; } | sed 's/@[^@]*$//'))
    if ((${#pkgs[@]} == 0)); then
        info "  à jour"
        return 0
    fi
    "$npm" install -g "${pkgs[@]}" || fail "  échec de la mise à jour npm"
}

cmd_upgrade() {
    info "Paquets système..."
    if [[ $OS == macos ]]; then
        { brew update && brew upgrade; } || fail "  échec de brew upgrade"
    else
        sudo dnf upgrade --refresh || fail "  dnf: mise à jour interrompue"
        if have flatpak; then flatpak update -y || fail "  échec de flatpak update"; fi
        upgrade_kitty
        install_lazygit
    fi
    install_nerd_font

    if have rustup; then
        info "Rust (toolchains, puis outils cargo)..."
        rustup update || fail "  échec de rustup update"
        if have cargo; then install_cargo_tools <(pkg_cargo); fi
    fi
    if have ghcup; then
        info "Haskell (versions recommandées)..."
        ghcup upgrade || fail "  échec de ghcup upgrade"
        # Sinon chaque commande ghcup qui suit annonce « New … version available ». On reste
        # volontairement sur les versions recommandées.
        export GHCUP_SKIP_UPDATE_CHECK=1
        local tool
        for tool in ghc hls cabal stack; do
            # déjà installée: on l'active seulement (install afficherait un avertissement)
            if ghcup list -t "$tool" -c installed -r 2>/dev/null | grep -qw recommended; then
                ghcup set "$tool" recommended || fail "  échec de $tool"
            else
                ghcup install "$tool" recommended --set || fail "  échec de $tool"
            fi
        done
    fi
    if have fnm; then
        info "Node (dernière LTS via fnm)..."
        # Pas de « fnm default » ici, pour garder la version par défaut choisie. Si c'est
        # lts-latest (le cas après dot install), fnm install --lts déplace déjà cet alias.
        local lts
        lts="$(fnm ls-remote --lts --latest 2>/dev/null | awk '{print $1}' || true)"
        if [[ -n $lts ]] && fnm list | grep -qw "$lts"; then
            info "  $lts, dernière LTS, déjà installée"
        else
            fnm install --lts || fail "  échec de fnm"
        fi
    fi
    upgrade_npm
    if have deno; then deno upgrade || fail "  échec de deno upgrade"; fi

    info "nvim (plugins, parsers, paquets Mason)..."
    nvim_maint upgrade
    # Le correctif XP-Pen est compilé pour un noyau précis
    if [[ $OS == linux && -f /etc/udev-hid-bpf/0010-XPPen__ACK05.bpf.o ]] &&
        [[ $(rpm -q --last kernel-core 2>/dev/null | head -1) != *"$(uname -r)"* ]]; then
        info "Nouveau noyau: après le redémarrage, « dot tablette » si la télécommande XP-Pen ne marche plus."
    fi
    ok "Terminé. lazy-lock.json a pu changer: « dot push » pour l'enregistrer."
}
