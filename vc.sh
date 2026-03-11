#!/bin/bash

# vc - Universal Version Control Helper
# A git wrapper for painless save/rollback workflow
# Install: curl -fsSL <url>/vc.sh | bash
# Usage: ./vc <command> [args]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# If placed in scripts/, project root is one level up; otherwise use cwd
if [ "$(basename "$SCRIPT_DIR")" = "scripts" ]; then
    PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
else
    PROJECT_DIR="$SCRIPT_DIR"
fi

cd "$PROJECT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ── helpers ─────────────────────────────────────────────────────────────────

require_git() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${RED}Error: not a git repository.${NC}"
        echo "Run './vc init' to initialise one."
        exit 1
    fi
}

require_tag() {
    local tag="$1" label="${2:-tag}"
    if [ -z "$tag" ]; then
        echo -e "${RED}Error: please specify a $label.${NC}"
        exit 1
    fi
    if ! git rev-parse "$tag" > /dev/null 2>&1; then
        echo -e "${RED}Error: '$tag' not found.${NC}"
        exit 1
    fi
}

# ── commands ─────────────────────────────────────────────────────────────────

cmd_init() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${YELLOW}Already a git repository.${NC}"
    else
        git init
        echo -e "${GREEN}��� git repository initialised.${NC}"
    fi

    # Create a sensible .gitignore if none exists
    if [ ! -f .gitignore ]; then
        cat > .gitignore << 'GITIGNORE'
# Build / compiled output
/target/
/dist/
/build/
__pycache__/
*.pyc
*.pdb
*.rs.bk
node_modules/

# IDE
.vscode/
.idea/
*.swp
*~

# OS
.DS_Store
Thumbs.db

# Secrets
.env
*.key
*.pem

# Local overrides
*.local
GITIGNORE
        echo -e "${GREEN}✓ .gitignore created.${NC}"
    fi

    # Initial commit if nothing committed yet
    if ! git rev-parse --verify HEAD > /dev/null 2>&1; then
        git add -A
        git commit -m "chore: initial commit" 2>/dev/null || true
        echo -e "${GREEN}✓ initial commit created.${NC}"
    fi

    echo -e "\n${BLUE}Ready. Try: ./vc save \"first version\"${NC}"
}

cmd_save() {
    require_git
    local message="$*"
    if [ -z "$message" ]; then
        echo -e "${RED}Error: please provide a message.${NC}"
        echo "Usage: ./vc save <message>"
        exit 1
    fi

    if git diff --quiet && git diff --cached --quiet && \
       [ -z "$(git ls-files --others --exclude-standard)" ]; then
        echo -e "${YELLOW}Nothing to save (working tree clean).${NC}"
        exit 0
    fi

    echo -e "${BLUE}Saving...${NC}"
    git status --short

    git add -A
    git commit -m "$message"

    local version="v$(date +%Y%m%d-%H%M%S)"
    git tag -a "$version" -m "$message"

    echo -e "\n${GREEN}✓ Saved as ${version}${NC}"
    echo -e "  Rollback: ./vc rollback $version"
}

cmd_list() {
    require_git

    if ! git tag -l | grep -q .; then
        echo -e "${YELLOW}No saved versions yet. Use: ./vc save \"message\"${NC}"
        return
    fi

    echo -e "${BLUE}Saved versions:${NC}\n"
    git tag -l --sort=-version:refname | while read -r tag; do
        local date msg
        date=$(git log -1 --format="%ai" "$tag" | cut -d' ' -f1,2)
        msg=$(git tag -l --format='%(contents:subject)' "$tag")
        echo -e "  ${GREEN}${tag}${NC}  ${date}"
        echo -e "    ${msg}"
        echo
    done
}

cmd_show() {
    require_git
    require_tag "$1" "version tag"
    git show "$1" --stat
}

cmd_rollback() {
    require_git
    require_tag "$1" "version tag"
    local tag="$1"

    echo -e "${YELLOW}⚠  This will discard all uncommitted changes.${NC}"
    echo -e "   Target: ${GREEN}${tag}${NC}"
    printf "Confirm? (yes/no): "
    read -r confirm
    [ "$confirm" = "yes" ] || { echo -e "${BLUE}Cancelled.${NC}"; exit 0; }

    local backup="backup-$(date +%Y%m%d-%H%M%S)"
    git branch "$backup" 2>/dev/null && \
        echo -e "  ${BLUE}Current state saved to branch: ${backup}${NC}"

    git reset --hard "$tag"

    echo -e "\n${GREEN}✓ Rolled back to ${tag}${NC}"
    echo -e "  To undo: git checkout ${backup}"
}

cmd_diff() {
    require_git
    require_tag "$1" "first tag"
    require_tag "$2" "second tag"
    echo -e "${BLUE}Changes from $1 → $2:${NC}\n"
    git diff "$1".."$2" --stat
    echo
    git log "$1".."$2" --oneline
}

cmd_status() {
    require_git
    local branch commit tag

    branch=$(git branch --show-current)
    commit=$(git log -1 --oneline 2>/dev/null || echo "no commits yet")
    tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "none")

    echo -e "${BLUE}Status${NC}"
    echo -e "  Branch : ${branch}"
    echo -e "  Commit : ${commit}"
    echo -e "  Latest tag : ${tag}"
    echo

    if git diff --quiet && git diff --cached --quiet && \
       [ -z "$(git ls-files --others --exclude-standard)" ]; then
        echo -e "  ${GREEN}✓ Working tree clean${NC}"
    else
        echo -e "  ${YELLOW}Uncommitted changes:${NC}"
        git status --short | sed 's/^/    /'
    fi
}

cmd_backup() {
    require_git
    local backup_dir="$PROJECT_DIR/backup"
    mkdir -p "$backup_dir"

    local backup_file="$backup_dir/$(date +%Y%m%d-%H%M%S).tar.gz"

    # Use git archive so we only pack tracked files — works for any project type
    git archive HEAD --format=tar.gz -o "$backup_file"

    local size
    size=$(ls -lh "$backup_file" | awk '{print $5}')
    echo -e "${GREEN}✓ Backup created: ${backup_file} (${size})${NC}"
}

cmd_log() {
    require_git
    git log --oneline --graph --all | head -40
}

show_help() {
    cat << EOF

  vc — simple version control helper (wraps git)

  Usage: ./vc <command> [args]

  Commands:
    init                  Initialise git repo + .gitignore
    save <message>        Commit everything and tag the snapshot
    list                  List all saved snapshots
    show <tag>            Show details of a snapshot
    rollback <tag>        Reset to a snapshot (with auto backup branch)
    diff <tag1> <tag2>    Compare two snapshots
    log                   Show recent commit graph
    status                Working tree status
    backup                Export current HEAD to backup/<timestamp>.tar.gz
    help                  Show this message

  Examples:
    ./vc init
    ./vc save "add streaming support"
    ./vc list
    ./vc rollback v20260311-062045
    ./vc diff v20260310-150000 v20260311-062045

EOF
}

# ── install helper (for new projects) ────────────────────────────────────────

cmd_install() {
    local target="${1:-.}"
    local target_script
    target_script="$(cd "$target" && pwd)/scripts/version-control.sh"
    local self
    self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

    mkdir -p "$target/scripts"

    if [ "$self" != "$target_script" ]; then
        cp "$self" "$target_script"
        chmod +x "$target_script"
    fi

    # Create the thin vc wrapper in the project root
    cat > "$target/vc" << 'WRAPPER'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/scripts/version-control.sh" "$@"
WRAPPER
    chmod +x "$target/vc"

    echo -e "${GREEN}✓ Installed to ${target}/${NC}"
    echo -e "  Run: cd ${target} && ./vc init"
}

# ── main ─────────────────────────────────────────────────────────────────────

main() {
    local cmd="${1:-help}"
    shift 2>/dev/null || true

    case "$cmd" in
        init)     cmd_init "$@" ;;
        save)     cmd_save "$@" ;;
        list)     cmd_list ;;
        show)     cmd_show "$@" ;;
        rollback) cmd_rollback "$@" ;;
        diff)     cmd_diff "$@" ;;
        log)      cmd_log ;;
        status)   cmd_status ;;
        backup)   cmd_backup ;;
        install)  cmd_install "$@" ;;
        help|--help|-h) show_help ;;
        *)
            echo -e "${RED}Unknown command: $cmd${NC}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
