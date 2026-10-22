#!/usr/bin/env bash
# Refresh source/ (code-only mirror of Rexshack-RedM repos) and regenerate framework/resources/.
# Run from anywhere: bash tools/refresh.sh   (needs git + python3)
set -e
BRAIN="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
git clone --depth 1 -q https://github.com/Rexshack-RedM/txAdminRecipe.git "$TMP/recipe"
grep -ohE 'Rexshack-RedM/[A-Za-z0-9_.-]+' -r "$TMP/recipe" | sed 's#.*/##; s/\.git$//' | sort -u \
  | grep -vE '^(txAdminRecipe|ox_lib|ox_target|PolyZone|interact-sound|progressbar|rNotify|menu_base|redm-ymaps)$' > "$TMP/list.txt"
# add extra repos (one per line) in tools/extra-repos.txt
[ -f "$BRAIN/tools/extra-repos.txt" ] && grep -v '^#' "$BRAIN/tools/extra-repos.txt" >> "$TMP/list.txt" || true
mkdir -p "$TMP/repos"
xargs -P 8 -I{} sh -c 'git clone --depth 1 -q https://github.com/Rexshack-RedM/{}.git "'"$TMP"'/repos/{}" 2>/dev/null || echo "skip {}"' < "$TMP/list.txt"
# code-only copy into source/
mkdir -p "$BRAIN/source"
( cd "$TMP/repos" && find . \( -name '*.lua' -o -name '*.sql' -o -name '*.md' -o -name '*.js' -o -name '*.html' -o -name '*.css' -o -name '*.json' \) \
    -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/images/*' -not -name '*.min.*' -size -400k -print0 \
  | while IFS= read -r -d '' f; do mkdir -p "$BRAIN/source/$(dirname "$f")"; cp "$f" "$BRAIN/source/$f"; done )
python3 "$BRAIN/tools/extract.py" "$TMP/repos" "$BRAIN/framework/resources"
# natives database (same source redm.info uses)
git clone --depth 1 -q https://github.com/VORPCORE/RDR3natives.git "$TMP/natives" && python3 "$BRAIN/tools/build_natives.py" "$TMP/natives" "$BRAIN/natives/db" || echo "skip natives"
date -u +"%Y-%m-%d %H:%M UTC" > "$BRAIN/source/LAST_REFRESH.txt"
rm -rf "$TMP" 2>/dev/null || true
echo "Done. $(ls "$BRAIN/source" | wc -l) resources in source/"
