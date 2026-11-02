#!/bin/bash
# Builds the two ready-to-use installers and their ZIP files into dist/
#   dist/Eglantine Installer & Updater.zip            (PGO build)
#   dist/Eglantine Installer & Updater (non-PGO).zip  (normal build)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/src/installer.template.sh"
COVER="$ROOT/assets/cover.jpg"
DIST="$ROOT/dist"

rm -rf "$DIST"
mkdir -p "$DIST"

build() {  # build <variant> <label> <name>
    local variant="$1" label="$2" name="$3" stage="$DIST/stage-$1"
    mkdir -p "$stage/roms/ports/images"
    python3 - "$SRC" "$stage/roms/ports/$name.sh" "$variant" "$label" "$COVER" <<'PY'
import base64, sys, textwrap
src, out, variant, label, cover = sys.argv[1:6]
poster = "\n".join(textwrap.wrap(base64.b64encode(open(cover, "rb").read()).decode(), 76))
t = open(src).read()
t = (t.replace("@@VARIANT@@", variant)
      .replace("@@VARIANT_LABEL@@", label)
      .replace("@@POSTER@@", poster))
open(out, "w", newline="\n").write(t)
PY
    chmod +x "$stage/roms/ports/$name.sh"
    bash -n "$stage/roms/ports/$name.sh"
    cp "$COVER" "$stage/roms/ports/images/$name.jpg"
    cp "$ROOT/README.md" "$stage/README.txt"
    cp "$ROOT/LIESMICH.md" "$stage/LIESMICH.txt"
    (cd "$stage" && zip -qr "$DIST/$name.zip" README.txt LIESMICH.txt roms)
    rm -rf "$stage"
    echo "built: dist/$name.zip"
}

build pgo    "PGO"     "Eglantine Installer & Updater"
build normal "non-PGO" "Eglantine Installer & Updater (non-PGO)"
