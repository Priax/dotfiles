# shellcheck shell=bash
# Synchro machine ⇄ repo: save, push, apply, pull, status, diff

save_one() {
    local sys=$1 repo=$2
    if [[ $sys == */ ]]; then
        if [[ ! -d $sys ]]; then
            warn "  absent: $(pretty "$sys")"
            return
        fi
        mkdir -p "$repo"
        rsync -a --delete --delete-excluded "${RSYNC_EXCLUDES[@]}" "$sys" "$repo"
    else
        mkdir -p "$(dirname "$repo")"
        local tmp
        tmp="$(mktemp)"
        if read_file "$sys" >"$tmp"; then
            mv "$tmp" "$repo"
            # mêmes droits que l'original (stat -c sur Linux, -f sur macOS)
            [[ -r $sys && -O $sys ]] && chmod "$(stat -L -c %a "$sys" 2>/dev/null || stat -L -f %Lp "$sys")" "$repo"
        else
            rm -f "$tmp"
            warn "  illisible ou absent: $(pretty "$sys")"
            return
        fi
    fi
    printf '  %s\n' "$(pretty "$sys")"
}

cmd_save() {
    info "Copie machine → repo..."
    local sys repo
    while IFS=$'\t' read -r sys repo; do
        save_one "$sys" "$repo"
    done < <(entries)
    export_packages
}

# Le repo est public, et un secret poussé y reste même après un commit qui le retire.
check_secrets() {
    # motifs coupés en deux ('') pour que ce fichier ne se détecte pas lui-même
    local pattern='BEGIN [A-Z ]*PRIVATE KEY|aws_secret_''access_key|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{20,}|github_''pat_|xox[abp]-'
    pattern+='|sk-ant-[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9]{32,}|npm_[A-Za-z0-9]{30,}|glpat-[A-Za-z0-9_-]{15,}|AIza[0-9A-Za-z_-]{30,}'
    local hits
    hits="$(git -C "$REPO_DIR" diff --cached -U0 | grep -E '^\+' | grep -E "$pattern" || true)"
    if [[ -n $hits ]]; then
        git -C "$REPO_DIR" reset -q
        warn "Ce qui ressemble à un secret a été détecté, commit annulé:"
        printf '%s\n' "$hits" | cut -c1-80 >&2
        exit 1
    fi
    # gitleaks connaît bien plus de formats que les motifs ci-dessus
    if ! have gitleaks; then
        warn "gitleaks absent, secrets cherchés avec les seuls motifs de dot (dnf ou brew install gitleaks)"
    elif ! gitleaks git --staged --pre-commit --redact --no-banner --log-level warn "$REPO_DIR"; then
        git -C "$REPO_DIR" reset -q
        die "gitleaks a signalé un secret, commit annulé"
    fi
}

# Passe les scripts du repo à shellcheck (-x suit les « . lib/….sh » de dot). Lancé après
# cmd_save, pour vérifier ce qui va vraiment être poussé. Un avertissement ne bloque pas le
# push, il faut juste le confirmer.
check_scripts() {
    if ! have shellcheck; then
        warn "shellcheck absent, scripts non vérifiés (dnf install ShellCheck, ou brew install shellcheck)"
        return 0
    fi
    (cd "$REPO_DIR" && shellcheck -x dot bootstrap.sh home/.local/bin/fl) && return 0
    ask "shellcheck signale des problèmes (ci-dessus). Pousser quand même ?" ||
        die "push annulé: corrige, puis « dot push »"
}

cmd_push() {
    cmd_save
    check_scripts
    cd "$REPO_DIR"
    git add -A
    if ! git diff --cached --quiet; then
        check_secrets
        git --no-pager diff --cached --stat
        git commit -q -m "sync: $(hostname -s) $(date '+%Y-%m-%d %H:%M')" \
            -m "$(git diff --cached --stat | tail -n 1)"
    elif [[ -z $(git rev-list '@{u}..HEAD') ]]; then
        ok "Rien à commiter, les dotfiles sont à jour."
        return
    else
        info "Rien de nouveau, mais des commits pas encore poussés: envoi..."
    fi

    # L'autre machine a pu pousser entre-temps, sans ça le push serait refusé
    local before after
    before="$(git rev-parse '@{u}')"
    git pull -q --rebase ||
        die "conflit avec l'autre machine: corrige les fichiers (git status), puis « git rebase --continue », « dot apply » et « git push »"
    after="$(git rev-parse '@{u}')"
    # Si on a récupéré quelque chose, on l'installe ici avant de pousser. Sinon le prochain push
    # depuis cette machine annulerait ces changements.
    if [[ $after != "$before" ]]; then
        info "Changements de l'autre machine récupérés, installation ici..."
        cmd_apply
    fi
    git push -q origin HEAD
    ok "Dotfiles commités et poussés."
}

differs() {
    local sys=$1 repo=$2
    if [[ $repo == */ ]]; then
        ! diff -rq "${DIFF_EXCLUDES[@]}" "$repo" "$sys" &>/dev/null
    else
        ! cmp -s "$repo" <(read_file "$sys")
    fi
}

backup_one() {
    local sys=$1 dest
    if is_home "$sys"; then
        dest="$BACKUP_DIR/home/${sys#"$HOME"/}"
    else
        dest="$BACKUP_DIR/system$sys"
    fi
    dest="${dest%/}"
    mkdir -p "$(dirname "$dest")"
    if [[ $sys == */ ]]; then
        cp -a "$sys" "$dest"
    else
        read_file "$sys" >"$dest"
    fi
}

apply_one() {
    local sys=$1 repo=$2
    if [[ ! -e ${repo%/} ]]; then
        warn "  pas dans le repo: $(pretty "$sys")"
        return
    fi
    # Jamais de dossier système créé par dot: un /var/lib/pgsql/data créé ici ferait échouer
    # « postgresql-setup --initdb ».
    local parent
    parent="$(dirname "${sys%/}")"
    if ! is_home "$sys" && [[ ! -d $parent ]] && ! sudo test -d "$parent"; then
        warn "  ignoré, $parent n'existe pas (service pas encore installé ?)"
        return
    fi
    if ! sys_exists "${sys%/}"; then
        :
    elif ! differs "$sys" "$repo"; then
        return
    else
        backup_one "$sys"
    fi

    if [[ $sys == */ ]]; then
        mkdir -p "$sys"
        # --delete comme dans save_one, sinon un fichier supprimé sur l'autre machine resterait
        # ici et reviendrait dans le repo au prochain push
        rsync -a --delete "${RSYNC_EXCLUDES[@]}" "$repo" "$sys"
    elif is_home "$sys"; then
        mkdir -p "$(dirname "$sys")"
        cp "$repo" "$sys"
    else
        # cp garde le propriétaire et les droits du fichier existant
        sudo cp "$repo" "$sys"
    fi
    printf '  %s\n' "$(pretty "$sys")"
}

# ~/.ssh/config n'est pas suivi (noms d'hôtes). On y ajoute seulement, en tête, l'inclusion
# des réglages communs.
SSH_CONFIG="$HOME/.ssh/config"
SSH_INCLUDE='Include ~/.config/ssh/common.conf'

has_ssh_include() { grep -qxF "$SSH_INCLUDE" "$SSH_CONFIG" 2>/dev/null; }

ensure_ssh_include() {
    [[ -f $HOME/.config/ssh/common.conf ]] || return 0
    has_ssh_include && return
    mkdir -p "$HOME/.ssh"
    if [[ -f $SSH_CONFIG ]]; then
        backup_one "$SSH_CONFIG"
        { printf '%s\n\n' "$SSH_INCLUDE"; cat "$SSH_CONFIG"; } >"$SSH_CONFIG.tmp"
        mv "$SSH_CONFIG.tmp" "$SSH_CONFIG"
    else
        printf '%s\n' "$SSH_INCLUDE" >"$SSH_CONFIG"
    fi
    printf '  %s\n' "$(pretty "$SSH_CONFIG") (Include de ~/.config/ssh/common.conf)"
}

cmd_apply() {
    info "Copie repo → machine (sauvegarde dans $(pretty "$BACKUP_DIR"))..."
    local sys repo
    while IFS=$'\t' read -r sys repo; do
        apply_one "$sys" "$repo"
    done < <(entries)
    ensure_ssh_include
    if [[ -d $HOME/.ssh ]]; then
        chmod 700 "$HOME/.ssh"
        [[ -f $HOME/.ssh/config ]] && chmod 600 "$HOME/.ssh/config"
    fi
    if [[ $OS == linux ]]; then
        ok "Terminé. Pense à redémarrer docker/postgresql si leur config a changé."
    else
        ok "Terminé."
    fi
}

cmd_pull() {
    # Repo modifié mais pas commité (dot save, ou push interrompu): git refuserait la fusion
    # avec un message peu clair
    local dirty
    dirty="$(git -C "$REPO_DIR" status --porcelain)"
    if [[ -n $dirty ]]; then
        warn "Le repo contient des changements de cette machine qui n'ont pas été poussés:"
        printf '%s\n' "$dirty" >&2
        warn "Soit « dot push » pour les envoyer (fusionnés avec ceux de l'autre machine),"
        warn "soit, pour les abandonner: git -C $(pretty "$REPO_DIR") checkout -- <fichier>"
        exit 1
    fi
    # Fichiers modifiés sur la machine depuis le dernier save: apply les écraserait
    local changed=() sys repo
    while IFS=$'\t' read -r sys repo; do
        if [[ -e ${repo%/} ]] && sys_exists "${sys%/}" && differs "$sys" "$repo"; then
            changed+=("$(pretty "$sys")")
        fi
    done < <(entries)
    if ((${#changed[@]})); then
        warn "Ces fichiers ont changé sur cette machine et seraient écrasés:"
        printf '  %s\n' "${changed[@]}" >&2
        warn "Soit « dot push » pour les envoyer (fusionnés avec ceux de l'autre machine),"
        warn "soit « dot apply » pour les abandonner (copie dans ~/dotfiles_backup), puis « dot pull »."
        exit 1
    fi
    git -C "$REPO_DIR" pull --ff-only
    # Le pull a pu modifier dot ou lib/, déjà chargés dans ce processus: la suite tourne
    # dans un nouveau dot
    exec "$REPO_DIR/dot" after-pull
}

cmd_after_pull() {
    cmd_apply
    install_nerd_font
    # la config nvim tirée peut changer lazy-lock.json ou demander d'autres parsers / paquets Mason
    info "nvim (plugins, parsers et paquets Mason manquants)..."
    nvim_maint install
}

cmd_status() {
    local sys repo state
    while IFS=$'\t' read -r sys repo; do
        if ! is_home "$sys" && [[ ! -r ${sys%/} ]] && ! sudo -n true 2>/dev/null; then
            state="${DIM}? (sudo requis, lance « sudo -v » avant)"
        elif [[ ! -e ${repo%/} ]] && ! sys_exists "${sys%/}"; then
            state="${RED}absent partout"
        elif [[ ! -e ${repo%/} ]]; then
            state="${YELLOW}pas encore sauvegardé"
        elif ! sys_exists "${sys%/}"; then
            state="${YELLOW}absent de la machine"
        elif differs "$sys" "$repo"; then
            state="${YELLOW}modifié"
        else
            state="${GREEN}ok"
        fi
        printf '  %-45s %s%s\n' "$(pretty "$sys")" "$state" "$NC"
    done < <(entries)
    if has_ssh_include; then
        state="${GREEN}ok"
    else
        state="${YELLOW}Include manquant (dot apply)"
    fi
    printf '  %-45s %s%s\n' "$(pretty "$SSH_CONFIG")" "$state" "$NC"
}

cmd_diff() {
    local filter=${1:-} sys repo tmp
    while IFS=$'\t' read -r sys repo; do
        [[ -n $filter && $sys != *"$filter"* ]] && continue
        [[ -e ${repo%/} ]] || continue
        if [[ $sys == */ || -r $sys ]]; then
            git --no-pager diff --no-index --color=auto -- "${repo%/}" "${sys%/}" || true
        else
            tmp="$(mktemp)"
            read_file "$sys" >"$tmp" || true
            git --no-pager diff --no-index --color=auto -- "$repo" "$tmp" || true
            rm -f "$tmp"
        fi
    done < <(entries)
}
