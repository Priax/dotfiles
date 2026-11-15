# shellcheck shell=bash
# Synchro machine ⇄ repo: save, push, apply, pull, status, diff

file_mode() {
    stat -L -c %a "$1" 2>/dev/null || stat -L -f %Lp "$1"
}

save_dir() {
    local sys=$1
    local repo=$2

    if [[ ! -d $sys ]]; then
        warn "  absent: $(pretty "$sys")"
        return 1
    fi

    mkdir -p "$repo"
    rsync -a --delete --delete-excluded "${RSYNC_EXCLUDES[@]}" "$sys" "$repo"
}

save_file() {
    local sys=$1
    local repo=$2
    local tmp

    mkdir -p "$(dirname "$repo")"
    tmp="$(mktemp)"

    if ! read_file "$sys" >"$tmp"; then
        rm -f "$tmp"
        warn "  illisible ou absent: $(pretty "$sys")"
        return 1
    fi

    mv "$tmp" "$repo"

    if [[ -r $sys && -O $sys ]]; then
        chmod "$(file_mode "$sys")" "$repo"
    fi
}

save_one() {
    local sys=$1
    local repo=$2

    if [[ $sys == */ ]]; then
        save_dir "$sys" "$repo" || return 0
    else
        save_file "$sys" "$repo" || return 0
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

SECRET_PATTERNS=(
    'BEGIN [A-Z ]*PRIVATE KEY'
    'aws_secret_''access_key'
    'AKIA[0-9A-Z]{16}'
    'gh[pousr]_[A-Za-z0-9]{20,}'
    'github_''pat_'
    'xox[abp]-'
    'sk-ant-[A-Za-z0-9_-]{20,}'
    'sk-[A-Za-z0-9]{32,}'
    'npm_[A-Za-z0-9]{30,}'
    'glpat-[A-Za-z0-9_-]{15,}'
    'AIza[0-9A-Za-z_-]{30,}'
)

secret_regex() {
    local IFS='|'
    echo "${SECRET_PATTERNS[*]}"
}

check_secrets() {
    local pattern hits
    pattern="$(secret_regex)"
    hits="$(git -C "$REPO_DIR" diff --cached -U0 | grep -E '^\+' | grep -E "$pattern" || true)"

    if [[ -n $hits ]]; then
        git -C "$REPO_DIR" reset -q
        warn "Ce qui ressemble à un secret a été détecté, commit annulé:"

        sed -E "s/$pattern/[secret masqué]/g" <<<"$hits" | cut -c1-100 >&2
        exit 1
    fi

    if ! have gitleaks; then
        warn "gitleaks absent, secrets cherchés avec les seuls motifs de dot (dnf ou brew install gitleaks)"
        return 0
    fi

    if ! gitleaks git --staged --pre-commit --redact --no-banner --log-level warn "$REPO_DIR"; then
        git -C "$REPO_DIR" reset -q
        die "gitleaks a signalé un secret, commit annulé"
    fi
}

check_scripts() {
    if ! have shellcheck; then
        warn "shellcheck absent, scripts non vérifiés (dnf install ShellCheck, ou brew install shellcheck)"
        return 0
    fi

    local scripts=(dot bootstrap.sh home/.local/bin/fl home/.local/bin/krita-bureau)

    (cd "$REPO_DIR" && shellcheck -x "${scripts[@]}") && return 0

    ask "shellcheck signale des problèmes (ci-dessus). Pousser quand même ?" ||
        die "push annulé: corrige, puis « dot push »"
}

commit_changes() {
    git add -A

    if ! git diff --cached --quiet; then
        check_secrets
        git --no-pager diff --cached --stat

        local summary
        summary="$(git diff --cached --stat | tail -n 1)"
        git commit -q -m "sync: $(hostname -s) $(date '+%Y-%m-%d %H:%M')" -m "$summary"
        return 0
    fi

    if [[ -z $(git rev-list '@{u}..HEAD') ]]; then
        ok "Rien à commiter, les dotfiles sont à jour."
        return 1
    fi

    info "Rien de nouveau, mais des commits pas encore poussés: envoi..."
}

cmd_push() {
    cmd_save
    check_scripts

    cd "$REPO_DIR"
    commit_changes || return 0

    local before after
    before="$(git rev-parse '@{u}')"

    git pull -q --rebase ||
        die "conflit avec l'autre machine: corrige les fichiers (git status), puis « git rebase --continue », « dot apply » et « git push »"

    after="$(git rev-parse '@{u}')"

    if [[ $after != "$before" ]]; then
        info "Changements de l'autre machine récupérés, installation ici..."
        cmd_apply
    fi

    git push -q origin HEAD
    ok "Dotfiles commités et poussés."
}

differs() {
    local sys=$1
    local repo=$2

    if [[ $repo == */ ]]; then
        ! diff -rq "${DIFF_EXCLUDES[@]}" "$repo" "$sys" &>/dev/null
    else
        ! cmp -s "$repo" <(read_file "$sys")
    fi
}

backup_one() {
    local sys=$1
    local dest

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

parent_missing() {
    local sys=$1
    local parent
    parent="$(dirname "${sys%/}")"

    is_home "$sys" && return 1
    [[ -d $parent ]] && return 1
    sudo test -d "$parent" && return 1

    warn "  ignoré, $parent n'existe pas (service pas encore installé ?)"
}

copy_to_machine() {
    local sys=$1
    local repo=$2

    if [[ $sys == */ ]]; then
        mkdir -p "$sys"
        rsync -a --delete "${RSYNC_EXCLUDES[@]}" "$repo" "$sys"
    elif is_home "$sys"; then
        mkdir -p "$(dirname "$sys")"
        cp "$repo" "$sys"
    else
        sudo cp "$repo" "$sys"
    fi
}

apply_one() {
    local sys=$1
    local repo=$2

    if [[ ! -e ${repo%/} ]]; then
        warn "  pas dans le repo: $(pretty "$sys")"
        return
    fi

    parent_missing "$sys" && return

    if sys_exists "${sys%/}"; then
        differs "$sys" "$repo" || return
        backup_one "$sys"
    fi

    copy_to_machine "$sys" "$repo"
    printf '  %s\n' "$(pretty "$sys")"
}

SSH_CONFIG="$HOME/.ssh/config"
SSH_INCLUDE='Include ~/.config/ssh/common.conf'

has_ssh_include() { grep -qxF "$SSH_INCLUDE" "$SSH_CONFIG" 2>/dev/null; }

ensure_ssh_include() {
    [[ -f $HOME/.config/ssh/common.conf ]] || return 0
    has_ssh_include && return

    mkdir -p "$HOME/.ssh"

    if [[ -f $SSH_CONFIG ]]; then
        backup_one "$SSH_CONFIG"
        {
            printf '%s\n\n' "$SSH_INCLUDE"
            cat "$SSH_CONFIG"
        } >"$SSH_CONFIG.tmp"
        mv "$SSH_CONFIG.tmp" "$SSH_CONFIG"
    else
        printf '%s\n' "$SSH_INCLUDE" >"$SSH_CONFIG"
    fi

    printf '  %s\n' "$(pretty "$SSH_CONFIG") (Include de ~/.config/ssh/common.conf)"
}

fix_ssh_permissions() {
    [[ -d $HOME/.ssh ]] || return 0

    chmod 700 "$HOME/.ssh"
    if [[ -f $HOME/.ssh/config ]]; then
        chmod 600 "$HOME/.ssh/config"
    fi
}

cmd_apply() {
    info "Copie repo → machine (sauvegarde dans $(pretty "$BACKUP_DIR"))..."

    local sys repo
    while IFS=$'\t' read -r sys repo; do
        apply_one "$sys" "$repo"
    done < <(entries)

    ensure_ssh_include
    fix_ssh_permissions

    if [[ $OS == linux ]]; then
        ok "Terminé. Pense à redémarrer docker/postgresql si leur config a changé."
    else
        ok "Terminé."
    fi
}

refuse_if_repo_dirty() {
    local dirty
    dirty="$(git -C "$REPO_DIR" status --porcelain)"
    [[ -z $dirty ]] && return 0

    warn "Le repo contient des changements de cette machine qui n'ont pas été poussés:"
    printf '%s\n' "$dirty" >&2
    warn "Soit « dot push » pour les envoyer (fusionnés avec ceux de l'autre machine),"
    warn "soit, pour les abandonner: git -C $(pretty "$REPO_DIR") checkout -- <fichier>"
    exit 1
}

refuse_if_machine_changed() {
    local changed=()
    local sys repo

    while IFS=$'\t' read -r sys repo; do
        if [[ -e ${repo%/} ]] && sys_exists "${sys%/}" && differs "$sys" "$repo"; then
            changed+=("$(pretty "$sys")")
        fi
    done < <(entries)

    ((${#changed[@]})) || return 0

    warn "Ces fichiers ont changé sur cette machine et seraient écrasés:"
    printf '  %s\n' "${changed[@]}" >&2
    warn "Soit « dot push » pour les envoyer (fusionnés avec ceux de l'autre machine),"
    warn "soit « dot apply » pour les abandonner (copie dans ~/dotfiles_backup), puis « dot pull »."
    exit 1
}

cmd_pull() {
    refuse_if_repo_dirty
    refuse_if_machine_changed

    git -C "$REPO_DIR" pull --ff-only

    exec "$REPO_DIR/dot" after-pull
}

cmd_after_pull() {
    cmd_apply
    install_nerd_font

    info "nvim (plugins, parsers et paquets Mason manquants)..."
    nvim_maint install
}

entry_state() {
    local sys=$1
    local repo=$2

    if ! is_home "$sys" && [[ ! -r ${sys%/} ]] && ! sudo -n true 2>/dev/null; then
        echo "${DIM}? (sudo requis, lance « sudo -v » avant)"
    elif [[ ! -e ${repo%/} ]] && ! sys_exists "${sys%/}"; then
        echo "${RED}absent partout"
    elif [[ ! -e ${repo%/} ]]; then
        echo "${YELLOW}pas encore sauvegardé"
    elif ! sys_exists "${sys%/}"; then
        echo "${YELLOW}absent de la machine"
    elif differs "$sys" "$repo"; then
        echo "${YELLOW}modifié"
    else
        echo "${GREEN}ok"
    fi
}

print_state() {
    printf '  %-45s %s%s\n' "$(pretty "$1")" "$2" "$NC"
}

cmd_status() {
    local sys repo
    while IFS=$'\t' read -r sys repo; do
        print_state "$sys" "$(entry_state "$sys" "$repo")"
    done < <(entries)

    if has_ssh_include; then
        print_state "$SSH_CONFIG" "${GREEN}ok"
    else
        print_state "$SSH_CONFIG" "${YELLOW}Include manquant (dot apply)"
    fi
}

cmd_diff() {
    local filter=${1:-}
    local sys repo tmp

    while IFS=$'\t' read -r sys repo; do
        [[ -n $filter && $sys != *"$filter"* ]] && continue
        [[ -e ${repo%/} ]] || continue

        if [[ $sys == */ || -r $sys ]]; then
            git --no-pager diff --no-index --color=auto -- "${repo%/}" "${sys%/}" || true
            continue
        fi

        tmp="$(mktemp)"
        read_file "$sys" >"$tmp" || true
        git --no-pager diff --no-index --color=auto -- "$repo" "$tmp" || true
        rm -f "$tmp"
    done < <(entries)
}
