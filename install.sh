#!/usr/bin/env bash
#
# Install script for Omarchy To-Do List Plugin (ciphersar.todo)
# Usage:
#   ./install.sh                # Install and enable plugin
#   ./install.sh --no-keybind   # Install without modifying Hyprland bindings
#   ./install.sh --uninstall    # Remove plugin and CLI helper
#

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ID="ciphersar.todo"
PLUGINS_DEST="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$PLUGIN_ID"
BIN_DEST="${HOME}/.local/bin"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy"
BINDINGS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/bindings.lua"

ADD_KEYBINDING=true
UNINSTALL=false

while (( $# > 0 )); do
  case "$1" in
    --no-keybind|--no-keybinding)
      ADD_KEYBINDING=false
      shift
      ;;
    --uninstall)
      UNINSTALL=true
      shift
      ;;
    -h|--help)
      cat <<EOF
Usage: ./install.sh [OPTIONS]

Options:
  --no-keybind    Install the plugin and CLI without editing ~/.config/hypr/bindings.lua
  --uninstall     Uninstall the plugin, CLI helper, and disable from shell.json
  -h, --help      Show this help message
EOF
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}" >&2
      exit 1
      ;;
  esac
done

# ------------------------------------------------------------- UNINSTALL
if [[ "$UNINSTALL" == true ]]; then
  echo -e "${BOLD}${BLUE}==> Uninstalling Omarchy To-Do Plugin...${NC}"

  if command -v omarchy >/dev/null 2>&1; then
    echo "Disabling plugin..."
    omarchy plugin disable "$PLUGIN_ID" 2>/dev/null || true
  fi

  if [[ -d "$PLUGINS_DEST" ]]; then
    rm -rf "$PLUGINS_DEST"
    echo "Removed $PLUGINS_DEST"
  fi

  if [[ -f "$BIN_DEST/omarchy-todo" ]]; then
    rm -f "$BIN_DEST/omarchy-todo"
    echo "Removed $BIN_DEST/omarchy-todo"
  fi

  if command -v omarchy-shell >/dev/null 2>&1; then
    omarchy-shell -q shell rescanPlugins 2>/dev/null || true
  fi

  echo -e "${GREEN}✓ Plugin uninstalled successfully.${NC}"
  echo -e "Note: If you have keybindings in $BINDINGS_FILE, you can manually remove them."
  exit 0
fi

# --------------------------------------------------------------- INSTALL
echo -e "${BOLD}${BLUE}==> Installing Omarchy To-Do Plugin ($PLUGIN_ID)...${NC}"

# 1. Validate files exist in source
for f in manifest.json TodoModel.js TodoOverlay.qml bin/omarchy-todo; do
  if [[ ! -f "$SCRIPT_DIR/$f" ]]; then
    echo -e "${RED}Error: Required file '$f' not found in $SCRIPT_DIR${NC}" >&2
    exit 1
  fi
done

# 2. Check Omarchy plugin validator if present
if command -v omarchy-plugin-validate >/dev/null 2>&1; then
  echo "Validating plugin manifest..."
  if ! omarchy-plugin-validate "$SCRIPT_DIR"; then
    echo -e "${RED}Error: Plugin validation failed.${NC}" >&2
    exit 1
  fi
fi

# 3. Create destination and copy plugin files
echo "Installing plugin files to $PLUGINS_DEST..."
mkdir -p "$PLUGINS_DEST"
cp -f "$SCRIPT_DIR/manifest.json" "$PLUGINS_DEST/"
cp -f "$SCRIPT_DIR/TodoModel.js" "$PLUGINS_DEST/"
cp -f "$SCRIPT_DIR/TodoOverlay.qml" "$PLUGINS_DEST/"

# 4. Install CLI script
echo "Installing CLI helper to $BIN_DEST/omarchy-todo..."
mkdir -p "$BIN_DEST"
cp -f "$SCRIPT_DIR/bin/omarchy-todo" "$BIN_DEST/omarchy-todo"
chmod +x "$BIN_DEST/omarchy-todo"

# 5. Ensure data storage file exists
mkdir -p "$STATE_DIR"
if [[ ! -f "$STATE_DIR/todo-items.json" ]]; then
  echo "[]" > "$STATE_DIR/todo-items.json"
fi

# 6. Rescan plugins and enable in omarchy-shell
if command -v omarchy-shell >/dev/null 2>&1; then
  echo "Registering plugin with omarchy-shell..."
  omarchy-shell -q shell rescanPlugins 2>/dev/null || true

  if command -v omarchy >/dev/null 2>&1; then
    echo "Enabling plugin in Omarchy..."
    omarchy plugin enable "$PLUGIN_ID" >/dev/null 2>&1 || true
  fi
fi

# 7. Add Hyprland keybinding if requested
if [[ "$ADD_KEYBINDING" == true && -f "$BINDINGS_FILE" ]]; then
  if ! grep -q "omarchy-todo" "$BINDINGS_FILE"; then
    echo "Adding SUPER + ALT + T keybinding to $BINDINGS_FILE..."
    cp "$BINDINGS_FILE" "${BINDINGS_FILE}.bak.$(date +%s)"
    cat << 'EOF' >> "$BINDINGS_FILE"

-- Quake-style To-Do list
o.bind("SUPER + ALT + T", "To-Do list", "omarchy-todo")
EOF
    if command -v hyprctl >/dev/null 2>&1; then
      hyprctl reload >/dev/null 2>&1 || true
    fi
  else
    echo "Keybinding for omarchy-todo already present in $BINDINGS_FILE."
  fi
fi

# 8. Check PATH warning
if [[ ":$PATH:" != *":$BIN_DEST:"* ]]; then
  echo -e "${YELLOW}Warning: $BIN_DEST is not in your PATH.${NC}"
  echo "Add 'export PATH=\"\$HOME/.local/bin:\$PATH\"' to your ~/.bashrc or ~/.zshrc."
fi

echo ""
echo -e "${BOLD}${GREEN}✓ Installation complete!${NC}"
echo ""
echo -e "${BOLD}Usage:${NC}"
echo -e "  Press ${YELLOW}SUPER + ALT + T${NC} to drop down the To-Do console."
echo -e "  Or run: ${BLUE}omarchy-todo${NC} from the terminal."
echo -e "  View history directly with: ${BLUE}omarchy-todo history${NC}"
echo -e "  Add tasks via CLI: ${BLUE}omarchy-todo add \"My next task\"${NC}"
