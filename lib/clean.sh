# shellcheck shell=bash
# dot clean

ghcup_versions() {
    ghcup list -c "$1" -r 2>/dev/null | awk '{ print $1, $2 }' | sort
}

clean_ghcup_inactive() {
    local line tool version

    while read -r line <&3; do
        read -r tool version _ <<<"$line"
        [[ $tool == ghcup ]] && continue

        if ask "  $tool $version installé mais pas actif, le supprimer ?"; then
            ghcup rm "$tool" "$version" || fail "  échec de la suppression de $tool $version"
        fi
    done 3< <(comm -23 <(ghcup_versions installed) <(ghcup_versions set))

    return 0
}

node_version_files() {
    local f

    while read -r f; do
        printf '%s %s\n' "$(tr -d '[:space:]v' <"$f")" "$f"
    done < <(
        find "$HOME" -maxdepth 6 \
            \( -name node_modules -o -name '.*' ! -name .nvmrc ! -name .node-version \) -prune \
            -o \( -name .nvmrc -o -name .node-version \) -type f -print 2>/dev/null
    )
}

fnm_dir() {
    if [[ -n ${FNM_DIR:-} ]]; then
        echo "$FNM_DIR"
    elif [[ $OS == macos ]]; then
        echo "$HOME/Library/Application Support/fnm"
    else
        echo "${XDG_DATA_HOME:-$HOME/.local/share}/fnm"
    fi
}

fnm_aliased_dirs() {
    local a

    for a in "$(fnm_dir)"/aliases/*; do
        readlink -f "$a"
    done 2>/dev/null
}

fnm_installed_versions() {
    local dir

    for dir in "$(fnm_dir)"/node-versions/v*/; do
        basename "$dir"
    done | sed 's/^v//' | sort -V
}

newest_matching() {
    local req=$1
    local installed=$2

    grep -E "^${req//./\\.}(\.|$)" <<<"$installed" | tail -n 1 || true
}

node_versions_to_keep() {
    local installed req path wanted
    installed="$(fnm_installed_versions)"

    while read -r req path; do
        [[ $req =~ ^[0-9]+(\.[0-9]+)*$ ]] || continue

        wanted="$(newest_matching "$req" "$installed")"
        if [[ -n $wanted ]]; then
            echo "v$wanted $(pretty "$path")"
        fi
    done < <(node_version_files)
}

clean_fnm_versions() {
    local aliased keep
    aliased="$(fnm_aliased_dirs)"
    keep="$(node_versions_to_keep)"

    local dir version user
    for dir in "$(fnm_dir)"/node-versions/v*/; do
        [[ -d $dir ]] || continue
        version="$(basename "$dir")"

        grep -qx "${dir%/}/installation" <<<"$aliased" && continue

        user="$(grep "^$version " <<<"$keep" | head -n 1 | cut -d' ' -f2- || true)"
        if [[ -n $user ]]; then
            info "  Node $version gardée: demandée par $user"
            continue
        fi

        if ask "  Node $version (aucun alias fnm, aucun .nvmrc), la supprimer ?"; then
            fnm uninstall "$version" || fail "  échec de la suppression de Node $version"
        fi
    done

    return 0
}

ghc_versions() {
    local g

    {
        ls "$HOME/.ghcup/ghc" 2>/dev/null || true

        for g in $(compgen -c | grep -E '^ghc(-[0-9.]+)?$' | sort -u); do
            "$g" --numeric-version 2>/dev/null || true
        done
    } | sort -u
}

clean_cabal_store() {
    local versions
    versions="$(ghc_versions)"

    local stale=()
    local dir version

    for dir in "$HOME"/.cabal/store/ghc-* "$HOME"/.local/state/cabal/store/ghc-*; do
        [[ -d $dir ]] || continue

        version="${dir##*/ghc-}"
        version="${version%%-*}"

        grep -qx "$version" <<<"$versions" || stale+=("$dir")
    done

    ((${#stale[@]})) || return 0

    info "  stores cabal de GHC qui ne sont plus installés:"
    printf '    %s\n' "${stale[@]}"

    if ask "  Les supprimer ?"; then
        rm -rf "${stale[@]}"
    fi
}

empty_trash() {
    local trash="${XDG_DATA_HOME:-$HOME/.local/share}/Trash"

    [[ -n $(ls -A "$trash/files" 2>/dev/null) ]] || return 0
    ask "Vider la corbeille ($(du -sh "$trash" | cut -f1)) ?" || return 0

    if have ktrash6; then
        ktrash6 --empty
    elif have gio && gio trash --empty 2>/dev/null; then
        :
    else
        rm -rf "${trash:?}/files" "$trash/info" "$trash/expunged" "$trash/directorysizes"
    fi
}

clean_backups() {
    local old
    mapfile -t old < <(find "$HOME/dotfiles_backup" -mindepth 1 -maxdepth 1 -type d -mtime +30 2>/dev/null)

    ((${#old[@]})) || return 0

    if ask "Supprimer ${#old[@]} sauvegarde(s) de dot apply de plus de 30 jours ?"; then
        rm -rf "${old[@]}"
    fi
}

free_kb() { df -Pk "$HOME" | awk 'NR == 2 { print $4 }'; }

clean_system_macos() {
    local orphans
    orphans="$(brew autoremove --dry-run 2>/dev/null || true)"

    if [[ -n $orphans ]]; then
        printf '%s\n' "$orphans"
        if ask "Retirer ces paquets brew devenus inutiles ?"; then
            brew autoremove || true
        fi
    fi

    brew cleanup --prune=all || true
}

clean_system_linux() {
    sudo dnf autoremove || true
    sudo dnf clean all || true

    if have flatpak; then
        flatpak uninstall --unused -y || true
    fi

    if ask "Ne garder que 2 semaines de journaux système ?"; then
        sudo journalctl --vacuum-time=2weeks || true
    fi

    empty_trash
    rm -rf "$HOME/.cache/thumbnails"
}

clean_dev_caches() {
    info "Caches des outils de dev (re-téléchargés au besoin)..."

    local npm
    if npm="$(system_npm)" || npm="$(command -v npm)"; then
        "$npm" cache clean --force --loglevel=error || true
    fi

    rm -rf "$HOME/.yarn/berry/cache"

    if have pip; then
        pip cache purge || true
    fi

    if have go; then
        go clean -cache -testcache -modcache || true
    fi

    rm -rf "$HOME/.cargo/registry/cache" "$HOME/.cargo/registry/src" "$HOME/.cargo/git/checkouts"

    # symboles de débogage téléchargés par gdb: le client ne fait le ménage
    # que quand gdb tourne, le cache grossit donc entre deux sessions
    local debuginfod="${DEBUGINFOD_CACHE_PATH:-${XDG_CACHE_HOME:-$HOME/.cache}/debuginfod_client}"
    if [[ -d $debuginfod ]]; then
        find "$debuginfod" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} + || true
    fi

    if have ghcup; then
        export GHCUP_SKIP_UPDATE_CHECK=1
        ghcup gc --hls-no-ghc --cache --tmpdirs || true
        clean_ghcup_inactive
        clean_cabal_store
    fi

    if have fnm; then
        clean_fnm_versions
    fi
}

clean_containers() {
    if have docker && ask "Docker: supprimer conteneurs arrêtés, images et réseaux inutilisés ?"; then
        docker system prune -f || true
    fi

    if have podman && ask "Podman: supprimer conteneurs arrêtés et images inutilisées ?"; then
        podman system prune -f || true
    fi
}

clean_nvim() {
    info "nvim (plugins, parsers et paquets Mason plus utilisés, miniatures, logs)..."

    rm -rf "$HOME/.cache/nvim/video-thumbs"

    local log
    for log in "$HOME"/.local/state/nvim/*.log; do
        if [[ -f $log ]]; then
            : >"$log"
        fi
    done

    local list
    list="$(mktemp)"
    nvim_maint list "$list"

    if [[ -s $list ]]; then
        info "  hors de la config nvim (installés à la main ?):"
        sed 's/^/    /' "$list"

        if ask "  Les désinstaller ?"; then
            nvim_maint remove "$list"
        fi
    fi

    rm -f "$list"
}

cmd_clean() {
    local before
    before="$(free_kb)"

    info "Paquets système inutilisés..."
    if [[ $OS == macos ]]; then
        clean_system_macos
    else
        clean_system_linux
    fi

    clean_backups
    clean_dev_caches
    clean_containers
    clean_nvim

    local after
    after="$(free_kb)"
    ok "Terminé: $(((after - before) / 1024)) Mo libérés."
}
