#!/bin/bash
# vc installer — run this in any project root:
#   curl -fsSL https://raw.githubusercontent.com/realpkuasule/vc/main/install.sh | bash

set -e

REPO="https://raw.githubusercontent.com/realpkuasule/vc/main"
GREEN='\033[0;32m'
NC='\033[0m'

mkdir -p scripts
curl -fsSL "$REPO/vc.sh" -o scripts/vc.sh
chmod +x scripts/vc.sh

cat > vc << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/scripts/vc.sh" "$@"
EOF
chmod +x vc

echo -e "${GREEN}✓ vc installed.${NC}"

# Auto-run init so the user can start immediately
bash vc init
