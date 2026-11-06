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
# native flags & enums (Halen84)
git clone --depth 1 -q https://github.com/Halen84/RDR3-Native-Flags-And-Enums.git "$TMP/enums" && python3 "$BRAIN/tools/build_enums.py" "$TMP/enums" "$BRAIN/data/rdr3-native-enums" || echo "skip enums"
# VORP Core reference (vorp/): repos from the VORP txAdmin recipe
git clone --depth 1 -q https://github.com/VORPCORE/VORP_txAdmin.git "$TMP/vrecipe" && {
  grep -ohE 'VORPCORE/vorp_[A-Za-z0-9_.-]+' -r "$TMP/vrecipe" | sed 's#.*/##; s/\.git$//; s/^vorp_core-lua$/vorp_core/; s/^vorp_character-lua$/vorp_character/; s/^vorp_fishing-lua$/vorp_fishing/; s/^vorp_metabolism-lua$/vorp_metabolism/; s/^vorp_stores-lua$/vorp_stores/' | sort -u > "$TMP/vlist.txt"
  mkdir -p "$TMP/vrepos"
  xargs -P 8 -I{} sh -c 'git clone --depth 1 -q https://github.com/VORPCORE/{}.git "'"$TMP"'/vrepos/{}" 2>/dev/null || echo "skip {}"' < "$TMP/vlist.txt"
  git clone --depth 1 -q https://github.com/VORPCORE/documentation.git "$TMP/vdocs" && mkdir -p "$BRAIN/vorp/docs" && cp "$TMP/vdocs"/api-reference/*.mdx "$TMP/vdocs"/bestpractices.mdx "$TMP/vdocs"/development.mdx "$TMP/vdocs"/faq.mdx "$BRAIN/vorp/docs/"
  rm -rf "$BRAIN/vorp/source"; mkdir -p "$BRAIN/vorp/source"
  ( cd "$TMP/vrepos" && find . \( -name '*.lua' -o -name '*.sql' -o -name '*.md' -o -name '*.js' -o -name '*.html' -o -name '*.css' -o -name '*.json' \) \
      -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/images/*' -not -path '*/img/*' -not -name '*.min.*' -size -400k -print0 \
    | while IFS= read -r -d '' f; do mkdir -p "$BRAIN/vorp/source/$(dirname "$f")"; cp "$f" "$BRAIN/vorp/source/$f"; done )
  BRAIN_ORG=VORPCORE BRAIN_TITLE="VORP resources" python3 "$BRAIN/tools/extract.py" "$TMP/vrepos" "$BRAIN/vorp/resources"
  date -u +"%Y-%m-%d %H:%M UTC" > "$BRAIN/vorp/source/LAST_REFRESH.txt"
} || echo "skip vorp"

# Feather Framework reference (feather/): all non-archived FeatherFramework repos
GITHUB_API_AUTH=()
if [ -n "${GITHUB_TOKEN:-}" ]; then GITHUB_API_AUTH=(-H "Authorization: Bearer $GITHUB_TOKEN"); fi
git clone --depth 1 -q https://github.com/FeatherFramework/feather-website.git "$TMP/fweb" && { mkdir -p "$BRAIN/feather/docs"; cp -r "$TMP/fweb/docs/"* "$BRAIN/feather/docs/"; } || echo "skip feather docs"
# The GitHub API can return an empty body or an error JSON when rate-limited.
# Parse defensively; an empty flist means "skip feather" instead of a traceback.
curl -fsSL --retry 2 --retry-delay 2 --connect-timeout 15 --max-time 30 \
  -H "Accept: application/vnd.github+json" \
  -H "User-Agent: rsg-redm-brain" \
  "${GITHUB_API_AUTH[@]}" \
  "https://api.github.com/orgs/FeatherFramework/repos?per_page=100" \
  | python3 -c '
import json, sys
try:
    repos = json.load(sys.stdin)
except Exception:
    raise SystemExit(1)
if not isinstance(repos, list):
    raise SystemExit(1)
for repo in repos:
    if isinstance(repo, dict) and not repo.get("archived") and repo.get("name") not in (".github", "feather-website", "feather-loadscreen"):
        print(repo["name"])
' > "$TMP/flist.txt" || : > "$TMP/flist.txt"
[ -s "$TMP/flist.txt" ] && {
  mkdir -p "$TMP/frepos"
  xargs -P 8 -I{} sh -c 'git clone --depth 1 -q https://github.com/FeatherFramework/{}.git "'"$TMP"'/frepos/{}" 2>/dev/null || echo "skip {}"' < "$TMP/flist.txt"
  rm -rf "$BRAIN/feather/source"; mkdir -p "$BRAIN/feather/source"
  ( cd "$TMP/frepos" && find . \( -name '*.lua' -o -name '*.sql' -o -name '*.md' -o -name '*.js' -o -name '*.html' -o -name '*.css' -o -name '*.json' \) \
      -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/images/*' -not -path '*/img/*' -not -name '*.min.*' -size -400k -print0 \
    | while IFS= read -r -d '' f; do mkdir -p "$BRAIN/feather/source/$(dirname "$f")"; cp "$f" "$BRAIN/feather/source/$f"; done )
  BRAIN_ORG=FeatherFramework BRAIN_TITLE="Feather resources" python3 "$BRAIN/tools/extract.py" "$TMP/frepos" "$BRAIN/feather/resources"
  date -u +"%Y-%m-%d %H:%M UTC" > "$BRAIN/feather/source/LAST_REFRESH.txt"
} || echo "skip feather"
date -u +"%Y-%m-%d %H:%M UTC" > "$BRAIN/source/LAST_REFRESH.txt"
# Keep the support playbook (DOCS.md) in sync with the refreshed mirror.
python3 "$BRAIN/tools/build_support_docs.py" || echo "skip support docs"
rm -rf "$TMP" 2>/dev/null || true
echo "Done. $(ls "$BRAIN/source" | wc -l) resources in source/"
