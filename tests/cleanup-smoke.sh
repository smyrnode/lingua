#!/usr/bin/env bash
# Disable/remove lifecycle of bin/lingua-cleanup in a sandbox: it must leave a
# plugin that is still installed and enabled alone (shell restart, hot-reload)
# and undo everything once it is disabled or its folder is gone.
set -euo pipefail

cd "$(dirname "$0")/.."
CLEANUP="$PWD/bin/lingua-cleanup"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

export HOME="$WORK/home"
export XDG_RUNTIME_DIR="$WORK/run"
unset XDG_STATE_HOME
export STUB_LOG="$WORK/hyprctl.log"
export LINGUA_WAIT=0
export LINGUA_PLUGIN_DIR="$HOME/.config/omarchy/plugins/smyrnode.lingua"
export LINGUA_SHELL_JSON="$HOME/.config/omarchy/shell.json"
STATE="$HOME/.local/state/omarchy"

fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "ok: $1"; }

mkdir -p "$WORK/bin" "$XDG_RUNTIME_DIR" "$HOME/.config/hypr" "$HOME/.config/omarchy" "$HOME/.local/bin"
cat >"$WORK/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$STUB_LOG"
if [[ ${1:-} == -j && ${2:-} == devices ]]; then
  printf '%s\n' '{"keyboards":[{"name":"kbd-a"},{"name":"kbd-b"}]}'
fi
exit 0
EOF
chmod +x "$WORK/bin/hyprctl"
export PATH="$WORK/bin:$PATH"

plant() {
  mkdir -p "$STATE/settings" "$STATE/toggles/hypr" "$LINGUA_PLUGIN_DIR"
  echo '{}' >"$LINGUA_PLUGIN_DIR/manifest.json"
  printf '%s\n' '-- keep me' '' '-- Lingua language switch' \
    'o.bind("CTRL + SPACE", "Switch language", "~/.local/bin/lingua-switch")' >"$HOME/.config/hypr/bindings.lua"
  ln -sf /bin/true "$HOME/.local/bin/lingua-switch"
  echo '{"layouts":[]}' >"$STATE/settings/smyrnode-lingua.json"
  : >"$STATE/toggles/hypr/smyrnode-lingua.lua"
  : >"$HOME/.local/state/lingua-switch.json"
  : >"$XDG_RUNTIME_DIR/lingua-switch.mod"
  : >"$STUB_LOG"
}
enabled_json='{"bar":{"layout":{"center":[{"id":"omarchy.clock"},{"id":"smyrnode.lingua"}]}}}'
disabled_json='{"bar":{"layout":{"center":[{"id":"omarchy.clock"}]}},"disabledPlugins":["smyrnode.lingua"]}'

# 1. installed and enabled: a restart or hot-reload, nothing may change
plant
echo "$enabled_json" >"$LINGUA_SHELL_JSON"
"$CLEANUP"
grep -q lingua-switch "$HOME/.config/hypr/bindings.lua" || fail "binding must stay while the plugin is enabled"
[[ -f $STATE/toggles/hypr/smyrnode-lingua.lua && -L $HOME/.local/bin/lingua-switch ]] || fail "toggle and link must stay while the plugin is enabled"
[[ ! -s $STUB_LOG ]] || fail "Hyprland must not be touched while the plugin is enabled"
pass "enabled plugin is left alone"

# 2. disabled but the folder is still there
plant
echo "$disabled_json" >"$LINGUA_SHELL_JSON"
"$CLEANUP"
if grep -q lingua-switch "$HOME/.config/hypr/bindings.lua"; then fail "binding should go when disabled"; fi
grep -q 'keep me' "$HOME/.config/hypr/bindings.lua" || fail "foreign lines must survive"
[[ ! -e $STATE/toggles/hypr/smyrnode-lingua.lua && ! -e $HOME/.local/bin/lingua-switch ]] || fail "toggle and link should go when disabled"
[[ ! -e $HOME/.local/state/lingua-switch.json && ! -e $XDG_RUNTIME_DIR/lingua-switch.mod ]] || fail "runtime state should go when disabled"
[[ -f $STATE/settings/smyrnode-lingua.json ]] || fail "saved languages must be kept so a reinstall resumes"
grep -q 'switchxkblayout kbd-a 0' "$STUB_LOG" && grep -q 'switchxkblayout kbd-b 0' "$STUB_LOG" || fail "keyboards should be parked on the first layout"
grep -q '^reload$' "$STUB_LOG" || fail "Hyprland should reload"
pass "disabled plugin is cleaned up, settings kept"

# 3. folder removed (omarchy plugin remove)
plant
echo "$enabled_json" >"$LINGUA_SHELL_JSON"
rm -rf "$LINGUA_PLUGIN_DIR"
"$CLEANUP"
if grep -q lingua-switch "$HOME/.config/hypr/bindings.lua"; then fail "binding should go when the folder is gone"; fi
pass "removed plugin is cleaned up"

# 4. --purge also drops the saved languages
plant
echo "$disabled_json" >"$LINGUA_SHELL_JSON"
"$CLEANUP" --purge
[[ ! -e $STATE/settings/smyrnode-lingua.json ]] || fail "--purge should delete the saved languages"
pass "purge deletes settings"

# 5. a missing shell.json means the plugin cannot be enabled: clean up
plant
rm -f "$LINGUA_SHELL_JSON"
"$CLEANUP"
if grep -q lingua-switch "$HOME/.config/hypr/bindings.lua"; then fail "binding should go without a shell.json"; fi
pass "no shell.json counts as disabled"

echo "ALL TESTS PASSED"
