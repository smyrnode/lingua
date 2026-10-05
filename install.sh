#!/usr/bin/env bash
# Installer for smyrnode.lingua plugin
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
BINDINGS_FILE="${HOME}/.config/hypr/bindings.lua"

echo "==> Installing Lingua for Omarchy..."

# 1. Install toggle binary (symlink so updates in plugin apply immediately)
mkdir -p "$BIN_DIR"
ln -sf "${PLUGIN_DIR}/bin/lingua-switch" "${BIN_DIR}/lingua-switch"
chmod +x "${PLUGIN_DIR}/bin/lingua-switch"
echo "  [x] Linked lingua-switch to ${BIN_DIR}/lingua-switch"

# Carry over an install made under the old plugin name (state, binding, link).
"${PLUGIN_DIR}/bin/lingua-layout" migrate

# 2. Configure the Hyprland keybinding in bindings.lua. `bind` keeps an
# existing hotkey and adds the modifier-press bindings older installs lack.
if [[ -f "$BINDINGS_FILE" ]]; then
  if grep -q "lingua-switch.mod" "$BINDINGS_FILE"; then
    echo "  [x] Language binding already present in ${BINDINGS_FILE}"
  else
    "${PLUGIN_DIR}/bin/lingua-layout" bind
    echo "  [x] Added language binding to ${BINDINGS_FILE}"
  fi
fi

# 3. Enable bar widget in Omarchy shell (place next to clock)
echo "  [x] Enabling bar widget next to clock..."
if omarchy plugin list | grep -q "omarchy.keyboard-layout.*enabled"; then
  omarchy plugin disable omarchy.keyboard-layout >/dev/null 2>&1 || true
fi
omarchy plugin enable smyrnode.lingua --section center --after omarchy.clock >/dev/null 2>&1 || true

# 4. Reload Hyprland & Omarchy shell
echo "  [x] Reloading Hyprland configuration..."
hyprctl reload >/dev/null 2>&1 || true

echo "==> Installation complete! Press Ctrl+Space to toggle languages."
