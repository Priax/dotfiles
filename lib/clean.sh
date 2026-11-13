# shellcheck shell=bash
# dot clean

# Versions ghcup installées mais inactives: les anciennes recommandées que dot upgrade laisse
# derrière lui (2 à 3 Go par GHC ou HLS). Une question par version.
clean_ghcup_inactive() {
    local line tool version
    # liste lue sur le descripteur 3 pour laisser l'entrée standard à ask
    while read -r line <&3; do
        read -r tool version _ <<<"$line"
        [[ $tool == ghcup ]] && continue
        if ask "  $tool $version installé mais pas actif, le supprimer ?"; then
            ghcup rm "$tool" "$version" || fail "  échec de la suppression de $tool $version"
        fi
    done 3< <(comm -23 <(ghcup list -c installed -r 2>/dev/null | awk '{print $1, $2}' | sort) \
        <(ghcup list -c set -r 2>/dev/null | awk '{print $1, $2}' | sort))
    return 0
}

# Versions de Node demandées par les .nvmrc et .node-version de ~ (hors node_modules et
# dossiers cachés). Une ligne « version chemin » par fichier, version sans le « v ».
node_version_files() {
    local f
    while read -r f; do
        printf '%s %s\n' "$(tr -d '[:space:]v' <"$f")" "$f"
    done < <(find "$HOME" -maxdepth 6 \( -name node_modules -o -name '.*' ! -name .nvmrc ! -name .node-version \) \
        -prune -o \( -name .nvmrc -o -name .node-version \) -type f -print 2>/dev/null)
}

# Propose de supprimer les versions de Node que ni un alias fnm (default, lts-latest…) ni un
# projet n'utilisent. Pour un .nvmrc « 22 » ou « 22.4 », on garde la plus récente qui correspond.
clean_fnm_versions() {
    local dir version aliased installed wanted keep="" req path
    aliased="$(for a in "$(fnm_dir)"/aliases/*; do readlink -f "$a"; done 2>/dev/null)"
    installed="$(for dir in "$(fnm_dir)"/node-versions/v*/; do basename "$dir"; done | sed 's/^v//' | sort -V)"
    while read -r req path; do
        [[ $req =~ ^[0-9]+(\.[0-9]+)*$ ]] || continue # lts/iron, node…: des alias, pas des versions
        wanted="$(grep -E "^${req//./\\.}(\.|$)" <<<"$installed" | tail -n 1 || true)"
        [[ -n $wanted ]] && keep+="v$wanted $(pretty "$path")"$'\n'
    done < <(node_version_files)
    for dir in "$(fnm_dir)"/node-versions/v*/; do
        [[ -d $dir ]] || continue # aucune version installée
        version="$(basename "$dir")"
        grep -qx "${dir%/}/installation" <<<"$aliased" && continue
        if grep -q "^$version " <<<"$keep"; then
            info "  Node $version gardée: demandée par $(grep "^$version " <<<"$keep" | head -n 1 | cut -d' ' -f2-)"
            continue
        fi
        if ask "  Node $version (aucun alias fnm, aucun .nvmrc), la supprimer ?"; then
            fnm uninstall "$version" || fail "  échec de la suppression de Node $version"
        fi
    done
    return 0
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

# Versions de GHC présentes: celles de ghcup et tout ghc / ghc-X.Y.Z du PATH (paquet dnf…)
ghc_versions() {
    local g
    {
        ls "$HOME/.ghcup/ghc" 2>/dev/null || true
        for g in $(compgen -c | grep -E '^ghc(-[0-9.]+)?$' | sort -u); do
            "$g" --numeric-version 2>/dev/null || true
        done
    } | sort -u
}

# Le store de cabal a un dossier par version de GHC, inutile une fois ce GHC désinstallé
clean_cabal_store() {
    local dir version versions stale=()
    versions="$(ghc_versions)"
    for dir in "$HOME"/.cabal/store/ghc-* "$HOME"/.local/state/cabal/store/ghc-*; do
        [[ -d $dir ]] || continue
        version="${dir##*/ghc-}"
        version="${version%%-*}"
        grep -qx "$version" <<<"$versions" || stale+=("$dir")
    done
    ((${#stale[@]})) || return 0
    info "  stores cabal de GHC qui ne sont plus installés:"
    printf '    %s\n' "${stale[@]}"
    if ask "  Les supprimer ?"; then rm -rf "${stale[@]}"; fi
}

# ktrash6 (KDE) vide aussi les corbeilles des autres disques. gio trash a besoin de gvfs (GNOME).
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
    if ask "Supprimer ${#old[@]} sauvegarde(s) de dot apply de plus de 30 jours ?"; then rm -rf "${old[@]}"; fi
}

free_kb() { df -Pk "$HOME" | awk 'NR == 2 {print $4}'; }

# Les caches se re-téléchargent, ils sont vidés sans demander. Ce qui est déduit (paquets
# « inutiles », parsers, paquets Mason, stores) est listé et confirmé avant suppression.
cmd_clean() {
    local before npm
    before="$(free_kb)"
    info "Paquets système inutilisés..."
    if [[ $OS == macos ]]; then
        local orphans
        orphans="$(brew autoremove --dry-run 2>/dev/null || true)"
        if [[ -n $orphans ]]; then
            printf '%s\n' "$orphans"
            if ask "Retirer ces paquets brew devenus inutiles ?"; then brew autoremove || true; fi
        fi
        brew cleanup --prune=all || true
    else
        # sans -y, dnf demande confirmation
        sudo dnf autoremove || true
        sudo dnf clean all || true
        if have flatpak; then flatpak uninstall --unused -y || true; fi
        if ask "Ne garder que 2 semaines de journaux système ?"; then
            sudo journalctl --vacuum-time=2weeks || true
        fi
        empty_trash
        rm -rf "$HOME/.cache/thumbnails"
    fi

    clean_backups

    info "Caches des outils de dev (re-téléchargés au besoin)..."
    # npm exige --force pour vider son cache, puis s'en plaint: on n'affiche que les erreurs
    if npm="$(system_npm)" || npm="$(command -v npm)"; then "$npm" cache clean --force --loglevel=error || true; fi
    rm -rf "$HOME/.yarn/berry/cache"
    if have pip; then pip cache purge || true; fi
    if have go; then go clean -cache -testcache -modcache || true; fi
    # crates téléchargées et leurs sources décompressées (l'index reste)
    rm -rf "$HOME/.cargo/registry/cache" "$HOME/.cargo/registry/src" "$HOME/.cargo/git/checkouts"
    if have ghcup; then
        # pas de « New … version available », dot upgrade s'en occupe
        export GHCUP_SKIP_UPDATE_CHECK=1
        # pas de --ghc-old: un projet utilise peut-être un GHC marqué ancien
        ghcup gc --hls-no-ghc --cache --tmpdirs || true
        clean_ghcup_inactive
        clean_cabal_store
    fi
    if have fnm; then clean_fnm_versions; fi
    if have docker && ask "Docker: supprimer conteneurs arrêtés, images et réseaux inutilisés ?"; then
        docker system prune -f || true
    fi
    if have podman && ask "Podman: supprimer conteneurs arrêtés et images inutilisées ?"; then
        podman system prune -f || true
    fi

    info "nvim (plugins, parsers et paquets Mason plus utilisés, miniatures, logs)..."
    rm -rf "$HOME/.cache/nvim/video-thumbs"
    local log list
    for log in "$HOME"/.local/state/nvim/*.log; do
        [[ -f $log ]] && : >"$log"
    done
    list="$(mktemp)"
    nvim_maint list "$list"
    if [[ -s $list ]]; then
        info "  hors de la config nvim (installés à la main ?):"
        sed 's/^/    /' "$list"
        if ask "  Les désinstaller ?"; then nvim_maint remove "$list"; fi
    fi
    rm -f "$list"

    local after
    after="$(free_kb)"
    ok "Terminé: $(((after - before) / 1024)) Mo libérés."
}
