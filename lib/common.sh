# shellcheck shell=bash
# Fonctions de base: messages, questions, lecture du manifest, accès aux fichiers.
# Sourcé par dot, qui définit REPO_DIR, MANIFEST, BACKUP_DIR, EXCLUDES, OS et PKG_DIR.

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
DIM=$'\033[2m'
NC=$'\033[0m'

info() { printf '%s\n' "${YELLOW}$*${NC}"; }
ok() { printf '%s\n' "${GREEN}$*${NC}"; }
warn() { printf '%s\n' "${RED}$*${NC}" >&2; }

FAILURES=()

fail() {
    warn "$*"
    FAILURES+=("${1#"${1%%[! ]*}"}")
}

die() {
    warn "Erreur: $*"
    exit 1
}

have() { command -v "$1" &>/dev/null; }

ask() {
    local reply
    read -r -p "$1 (y/N) " reply

    [[ $reply =~ ^[YyOo]$ ]]
}

trim() {
    local s="$1"

    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

firefox_roots() {
    if [[ $OS == macos ]]; then
        echo "$HOME/Library/Application Support/Firefox"
    else
        echo "$HOME/.mozilla/firefox"
        echo "$HOME/.config/mozilla/firefox"
        echo "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox"
    fi
}

installed_profile() {
    awk -F= '
        /^\[/                                  { section = $0 }
        section ~ /^\[Install/ && $1 == "Default" { print $2; exit }
    ' "$1"
}

default_profile() {
    awk -F= '
        /^\[/ {
            section = $0
            path = ""
            is_default = 0
        }

        section ~ /^\[Profile/ {
            if ($1 == "Path") path = $2
            if ($1 == "Default" && $2 == 1) is_default = 1

            if (path != "" && is_default) {
                print path
                exit
            }
        }
    ' "$1"
}

firefox_profile() {
    local root ini path

    while IFS= read -r root; do
        ini="$root/profiles.ini"
        [[ -f $ini ]] || continue

        path="$(installed_profile "$ini")"
        if [[ -z $path ]]; then
            path="$(default_profile "$ini")"
        fi
        [[ -n $path ]] || continue

        if [[ $path != /* ]]; then
            path="$root/$path"
        fi

        if [[ -d $path ]]; then
            echo "$path"
            return
        fi
    done < <(firefox_roots)

    return 1
}

repo_path() {
    local src="$1"

    case $src in
    "~/"*) echo "$REPO_DIR/home/${src#\~/}" ;;
    /*) echo "$REPO_DIR/system$src" ;;
    *) echo "$src" ;;
    esac
}

# Lit le manifest et sort une ligne « chemin_machine<TAB>chemin_repo »
entries() {
    local line tag dest src
    local ff=""
    local ff_done=0

    while IFS= read -r line || [[ -n $line ]]; do
        tag=""
        if [[ $line == *"#"* ]]; then
            tag="$(trim "${line#*#}")"
        fi

        if [[ ($tag == linux || $tag == macos) && $tag != "$OS" ]]; then
            continue
        fi

        line="$(trim "${line%%#*}")"
        [[ -n $line ]] || continue

        dest="$line"
        src="$line"
        if [[ $line == *" < "* ]]; then
            dest="$(trim "${line%% < *}")"
            src="$(trim "${line#* < }")"
        fi
        src="$(repo_path "$src")"

        case $dest in
        "~/"*)
            printf '%s\t%s\n' "$HOME/${dest#\~/}" "$src"
            ;;
        /*)
            printf '%s\t%s\n' "$dest" "$src"
            ;;
        firefox:*)
            if ((! ff_done)); then
                ff_done=1
                ff="$(firefox_profile)" ||
                    warn "Profil Firefox introuvable, entrées firefox: ignorées (lance Firefox une fois, ferme-le, puis « dot apply »)"
            fi

            if [[ -n $ff ]]; then
                printf '%s\t%s\n' "$ff/${dest#firefox:}" "$REPO_DIR/firefox/${dest#firefox:}"
            fi
            ;;
        *)
            warn "Entrée ignorée (doit commencer par ~/, / ou firefox:): $dest"
            ;;
        esac
    done <"$MANIFEST"
}

pretty() { sed "s|^$HOME|~|" <<<"$1"; }

is_home() { [[ $1 == "$HOME"/* ]]; }

read_file() {
    cat "$1" 2>/dev/null && return
    is_home "$1" && return 1

    sudo cat "$1" 2>/dev/null
}

sys_exists() {
    [[ -e $1 ]] && return
    is_home "$1" && return 1

    sudo test -e "$1" 2>/dev/null
}

RSYNC_EXCLUDES=()
DIFF_EXCLUDES=()

for e in "${EXCLUDES[@]}"; do
    RSYNC_EXCLUDES+=("--exclude=$e")
    DIFF_EXCLUDES+=(-x "$e")
done
unset e
