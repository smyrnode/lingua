#!/usr/bin/env bash
# Full uninstall of the smyrnode.lingua plugin, for a development checkout.
#
# `omarchy plugin remove` (or disable) already undoes the binding, the link and
# the generated keymap through bin/lingua-cleanup, but keeps your saved
# languages so a reinstall resumes. This script also deletes those settings and
# puts the stock keyboard-layout widget back in the bar.
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Uninstalling Lingua..."

# 1. Disable the bar widget and restore the stock one
omarchy plugin disable smyrnode.lingua >/dev/null 2>&1 || true
omarchy plugin enable omarchy.keyboard-layout --section center --after omarchy.clock >/dev/null 2>&1 || true

# 2. Binding, link, generated keymap, runtime state and saved settings; reloads Hyprland
"${PLUGIN_DIR}/bin/lingua-cleanup" --now --purge

echo "==> Uninstalled successfully."
