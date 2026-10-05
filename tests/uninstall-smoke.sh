#!/usr/bin/env bash
# Sandboxed uninstall test: plant every file the plugin creates, run
# uninstall.sh against a fake HOME with stub omarchy/hyprctl, assert cleanup.
set -euo pipefail

cd "$(dirname "$0")/.."
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

export HOME="$WORK/home"
export XDG_RUNTIME_DIR="$WORK/run"
unset XDG_STATE_HOME
export STUB_LOG="$WORK/stub.log"
mkdir -p "$HOME/.config/hypr" "$HOME/.local/bin" \
         "$HOME/.local/state/omarchy/settings" \
         "$HOME/.local/state/omarchy/toggles/hypr" \
         "$XDG_RUNTIME_DIR" "$WORK/bin"

# Plant user config: our lines plus a foreign binding that must survive.
printf '%s\n' \
  '-- keep me' \
  'o.bind("SUPER + E", "Editor", "nvim")' \
  '' \
  '-- Lingua language switch' \
  'o.bind("CTRL + SPACE", "Switch language", "~/.local/bin/lingua-switch")' \
  'o.bind("Control_L", nil, '"'"'date +%s%3N > "${XDG_RUNTIME_DIR:-/tmp}/lingua-switch.mod"'"'"', { non_consuming = true, ignore_mods = true })' \
  >"$HOME/.config/hypr/bindings.lua"
chmod 0644 "$HOME/.config/hypr/bindings.lua"

ln -sf /bin/true "$HOME/.local/bin/lingua-switch"
touch "$HOME/.local/state/lingua-switch.json" \
      "$HOME/.local/state/lingua-switch.json.lock" \
      "$HOME/.local/state/lingua-switch.json.tmp" \
      "$XDG_RUNTIME_DIR/lingua-switch.mod" \
      "$HOME/.local/state/omarchy/settings/smyrnode-lingua.json" \
      "$HOME/.local/state/omarchy/settings/smyrnode-lingua.lock" \
      "$HOME/.local/state/omarchy/toggles/hypr/smyrnode-lingua.lua" \
      "$HOME/.local/state/omarchy/settings/.smyrnode-kb-state.ABC123" \
      "$HOME/.local/state/omarchy/toggles/hypr/.smyrnode-kb-toggle.XYZ789"

for stub in omarchy hyprctl; do
  cat >"$WORK/bin/$stub" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"\$STUB_LOG"
exit 0
EOF
  chmod +x "$WORK/bin/$stub"
done
export PATH="$WORK/bin:$PATH"

./uninstall.sh >/dev/null

fail=0
check() {
  local name=$1
  shift
  if "$@"; then
    echo "ok: $name"
  else
    echo "FAIL: $name"
    fail=1
  fi
}

gone() { [[ ! -e $1 && ! -L $1 ]]; }

check "symlink removed" gone "$HOME/.local/bin/lingua-switch"
check "settings removed" gone "$HOME/.local/state/omarchy/settings/smyrnode-lingua.json"
check "settings lock removed" gone "$HOME/.local/state/omarchy/settings/smyrnode-lingua.lock"
check "generated toggle removed" gone "$HOME/.local/state/omarchy/toggles/hypr/smyrnode-lingua.lua"
check "mru state removed" gone "$HOME/.local/state/lingua-switch.json"
check "mru lock removed" gone "$HOME/.local/state/lingua-switch.json.lock"
check "mru tmp removed" gone "$HOME/.local/state/lingua-switch.json.tmp"
check "modifier timestamp removed" gone "$XDG_RUNTIME_DIR/lingua-switch.mod"
check "helper temp litter removed" \
  bash -c '! compgen -G "$HOME/.local/state/omarchy/settings/.smyrnode-kb-*" >/dev/null && ! compgen -G "$HOME/.local/state/omarchy/toggles/hypr/.smyrnode-kb-*" >/dev/null'
check "binding and modifier lines removed" bash -c '! grep -q -E "lingua-switch|Lingua language" "$HOME/.config/hypr/bindings.lua"'
check "foreign bindings kept" grep -q "SUPER + E" "$HOME/.config/hypr/bindings.lua"
check "no trailing blank lines left" bash -c '[[ -n $(tail -n1 "$HOME/.config/hypr/bindings.lua") ]]'
check "bindings mode kept" bash -c '[[ $(stat -c %a "$HOME/.config/hypr/bindings.lua") == 644 ]]'
check "plugin disabled" grep -q "plugin disable smyrnode.lingua" "$STUB_LOG"
check "stock widget restored" grep -q "plugin enable omarchy.keyboard-layout" "$STUB_LOG"
check "hyprland reloaded" grep -q "^reload$" "$STUB_LOG"

if [[ $fail -eq 0 ]]; then
  echo "ALL TESTS PASSED"
else
  exit 1
fi
