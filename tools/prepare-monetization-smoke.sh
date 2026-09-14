#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

bash tools/install-monetization-plugins.sh

BILLING_PLUGIN="addons/GodotGooglePlayBilling/plugin.cfg"
ADMOB_PLUGIN="addons/AdmobPlugin/plugin.cfg"
for plugin in "$BILLING_PLUGIN" "$ADMOB_PLUGIN"; do
  if [[ ! -f "$plugin" ]]; then
    echo "Required Godot plugin descriptor missing after install: $plugin" >&2
    exit 1
  fi
done

# Google's documented sample AdMob application ID. This file is generated only
# for CI/debug smoke builds; it must never be treated as the production AdMob ID.
cat > addons/AdmobPlugin/android_export.cfg <<'CFG'
[General]
is_real = false

[Debug]
app_id = "ca-app-pub-3940256099942544~3347511713"

[Release]
app_id = "ca-app-pub-3940256099942544~3347511713"

[Mediation]
enabled_networks = []
CFG

# The downloaded addons are intentionally not committed. Enable their editor
# export plugins only inside this disposable CI workspace.
if ! grep -q '^\[editor_plugins\]' project.godot; then
  cat >> project.godot <<'CFG'

[editor_plugins]
enabled=PackedStringArray("res://addons/AdmobPlugin/plugin.cfg", "res://addons/GodotGooglePlayBilling/plugin.cfg")
CFG
fi

echo "Monetization smoke environment prepared with Google test ads only."
