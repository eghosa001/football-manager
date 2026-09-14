#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="${TMPDIR:-/tmp}/football-dynasty-monetization-plugins"
rm -rf "$TMP"
mkdir -p "$TMP" "$ROOT/addons"

BILLING_VERSION="3.3.0"
BILLING_URL="https://github.com/godot-sdk-integrations/godot-google-play-billing/releases/download/${BILLING_VERSION}/godot-google-play-billing.zip"
BILLING_SHA256="20d75623d6f337f08d8283c83098b73678d5f575e39247af5a8eb80588b18568"

ADMOB_VERSION="v7.0"
ADMOB_URL="https://github.com/godot-sdk-integrations/godot-admob/releases/download/${ADMOB_VERSION}/AdmobPlugin-Android-v7.0.zip"
ADMOB_SHA256="ce38b75aeb4bb870fda8b74e1513d807696d8485d237c263b7b7a9613493aee8"

download_and_verify() {
  local url="$1"
  local sha="$2"
  local out="$3"
  curl --fail --location --retry 3 --output "$out" "$url"
  echo "$sha  $out" | sha256sum --check --status
}

install_single_plugin() {
  local src_root="$1"
  local expected_name="$2"
  local plugin_cfg
  plugin_cfg="$(find "$src_root" -type f -name plugin.cfg -path "*/${expected_name}/plugin.cfg" -print -quit || true)"
  if [[ -z "$plugin_cfg" ]]; then
    echo "No ${expected_name}/plugin.cfg found in extracted archive." >&2
    find "$src_root" -maxdepth 5 -type f -print >&2
    exit 1
  fi
  local plugin_dir
  plugin_dir="$(dirname "$plugin_cfg")"
  rm -rf "$ROOT/addons/$expected_name"
  cp -R "$plugin_dir" "$ROOT/addons/$expected_name"
  test -s "$ROOT/addons/$expected_name/plugin.cfg"
}

install_addon_bundle() {
  local src_root="$1"
  local required_plugin="$2"
  local addons_dir
  addons_dir="$(find "$src_root" -type d -name addons -print -quit || true)"
  if [[ -n "$addons_dir" ]]; then
    cp -R "$addons_dir"/. "$ROOT/addons"/
  else
    # Some release zips unpack add-on folders directly rather than under an
    # `addons/` parent. Preserve every sibling directory because shared helper
    # classes (for example GMP logger/SPM support) are dependencies of AdMob.
    local required_cfg
    required_cfg="$(find "$src_root" -type f -name plugin.cfg -path "*/${required_plugin}/plugin.cfg" -print -quit || true)"
    if [[ -z "$required_cfg" ]]; then
      echo "Required plugin ${required_plugin} not found in bundle." >&2
      find "$src_root" -maxdepth 5 -type f -print >&2
      exit 1
    fi
    local parent
    parent="$(dirname "$(dirname "$required_cfg")")"
    for entry in "$parent"/*; do
      [[ -d "$entry" ]] || continue
      local name
      name="$(basename "$entry")"
      rm -rf "$ROOT/addons/$name"
      cp -R "$entry" "$ROOT/addons/$name"
    done
  fi

  if [[ ! -s "$ROOT/addons/$required_plugin/plugin.cfg" ]]; then
    echo "${required_plugin} plugin descriptor missing after bundle install." >&2
    find "$ROOT/addons" -maxdepth 4 -type f -print >&2
    exit 1
  fi
}

download_and_verify "$BILLING_URL" "$BILLING_SHA256" "$TMP/billing.zip"
download_and_verify "$ADMOB_URL" "$ADMOB_SHA256" "$TMP/admob.zip"

mkdir -p "$TMP/billing" "$TMP/admob"
unzip -q "$TMP/billing.zip" -d "$TMP/billing"
unzip -q "$TMP/admob.zip" -d "$TMP/admob"

# Billing's archive currently packages the plugin differently from the AdMob
# bundle, so install the known plugin directory directly.
install_single_plugin "$TMP/billing" "GodotGooglePlayBilling"

# AdMob ships shared helper add-ons used by its editor/export script. Copy the
# complete bundle so classes such as GmpLogger and SpmDependency are available.
install_addon_bundle "$TMP/admob" "AdmobPlugin"

echo "Installed pinned monetization plugins into $ROOT/addons"
echo "Billing: GodotGooglePlayBilling $BILLING_VERSION"
echo "Ads: AdmobPlugin $ADMOB_VERSION (full helper bundle)"
