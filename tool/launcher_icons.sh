#!/usr/bin/env bash
# Builds the three launcher icons from the original 1024px artwork.
#
# flutter_launcher_icons writes the adaptive foreground and the background
# colour to fixed resource names (ic_launcher_foreground, ic_launcher_background)
# no matter which icon name a config asks for. Running it once per set therefore
# leaves every adaptive icon pointing at whichever set ran last — the bug that
# made the app install wearing the blue icon while the app itself showed yellow.
#
# So: run the plugin, then file its output under the set's own name. No image is
# touched here; the artwork is exactly the file in assets/app_icons/, resized by
# the plugin to each density.
#
# Runs on CI before the APK build. Locally: bash tool/launcher_icons.sh
set -euo pipefail
cd "$(dirname "$0")/.."

RES=android/app/src/main/res
MANIFEST="$(dirname "$RES")/AndroidManifest.xml"
DENSITIES="mdpi hdpi xhdpi xxhdpi xxxhdpi"

# flutter_launcher_icons rewrites *every* line that carries android:icon, not
# only the one on <application>. The three activity-alias entries carry it too,
# so each run retargeted all of them at its own icon — and the default set runs
# last, which left every alias pointing at ic_launcher. The aliases still
# switched, they just all looked identical, so the home screen never changed no
# matter which icon was picked. The manifest is restored on the way out, on
# failure as well as success.
cp "$MANIFEST" "$MANIFEST.iconbak"
trap 'mv -f "$MANIFEST.iconbak" "$MANIFEST"' EXIT

generate() {
  local config="$1" name="$2" colour="$3"
  dart run flutter_launcher_icons -f "$config"

  # The default set keeps the names the plugin writes, because that is the one
  # the manifest calls ic_launcher and the last run leaves in place.
  if [ "$name" = "ic_launcher" ]; then
    return
  fi

  for density in $DENSITIES; do
    mv "$RES/drawable-$density/ic_launcher_foreground.png" \
      "$RES/drawable-$density/${name}_foreground.png"
  done

  sed -i "s|@drawable/ic_launcher_foreground|@drawable/${name}_foreground|" \
    "$RES/mipmap-anydpi-v26/$name.xml"
  sed -i "s|@color/ic_launcher_background|@color/${name}_background|" \
    "$RES/mipmap-anydpi-v26/$name.xml"

  if ! grep -q "name=\"${name}_background\"" "$RES/values/colors.xml"; then
    sed -i "s|</resources>|    <color name=\"${name}_background\">${colour}</color>\n</resources>|" \
      "$RES/values/colors.xml"
  fi
}

# Default last: its run leaves ic_launcher_foreground and ic_launcher_background
# holding the default artwork and field, which is what a fresh install shows.
generate tool/icons/crown.yaml launcher_icon_crown "#14662A"
generate tool/icons/blue.yaml launcher_icon_blue "#0F2C51"
generate tool/icons/default.yaml ic_launcher "#1A4632"

echo "launcher icons written to $RES"
