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

install_plugin_from_tree() {
  local src_root="$1"
  local expected_name="$2"
  local plugin_cfg
  plugin_cfg="$(find "$src_root" -type f -name plugin.cfg -print | head -n 1 || true)"
  if [[ -z "$plugin_cfg" ]]; then
    echo "No plugin.cfg found in extracted $expected_name archive." >&2
    echo "Archive contents:" >&2
    find "$src_root" -maxdepth 4 -type f -print >&2
    exit 1
  fi

  local plugin_dir
  plugin_dir="$(dirname "$plugin_cfg")"
  local found_name
  found_name="$(basename "$plugin_dir")"
  if [[ "$found_name" != "$expected_name" ]]; then
    echo "Expected plugin directory '$expected_name' but archive contains '$found_name'." >&2
    exit 1
  fi

  rm -rf "$ROOT/addons/$expected_name"
  cp -R "$plugin_dir" "$ROOT/addons/$expected_name"
  test -s "$ROOT/addons/$expected_name/plugin.cfg"
}

download_and_verify "$BILLING_URL" "$BILLING_SHA256" "$TMP/billing.zip"
download_and_verify "$ADMOB_URL" "$ADMOB_SHA256" "$TMP/admob.zip"

mkdir -p "$TMP/billing" "$TMP/admob"
unzip -q "$TMP/billing.zip" -d "$TMP/billing"
unzip -q "$TMP/admob.zip" -d "$TMP/admob"

install_plugin_from_tree "$TMP/billing" "GodotGooglePlayBilling"
install_plugin_from_tree "$TMP/admob" "AdmobPlugin"

echo "Installed pinned monetization plugins into $ROOT/addons"
echo "Billing: GodotGooglePlayBilling $BILLING_VERSION"
echo "Ads: AdmobPlugin $ADMOB_VERSION"
