#!/usr/bin/env python3
"""Build the public RSG Framework docs site from the RedM brain.

Copies the brain's markdown into docs-site/docs/ (generated, not committed),
wraps code files (patterns, template) in markdown pages, rewrites links that
point at files not published on the site to GitHub, then mkdocs builds it.

Usage:  python3 tools/build_docs.py          # generate docs-site/docs
        mkdocs serve  /  mkdocs build        # preview / build (from repo root)
"""
import os, re, shutil, datetime, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "docs-site" / "docs"
REPO = "https://github.com/RexShackGaming/rsg-redm-brain/blob/main/"

# (source path in brain, destination in site). Folders copy *.md only (not recursive unless listed).
COPY = [
    ("README.md", "brain-guide.md"),
    ("CLAUDE.md", "ai/claude-entry.md"),
    ("server/environment.md", "getting-started/server-environment.md"),
    ("conventions", "conventions"),
    ("framework", "framework"),
    ("framework/resources", "resources"),
    ("natives", "natives"),
    ("ui/design-standard.md", "ui/design-standard.md"),
    ("audit", "audit"),
    ("data", "data"),
    ("vorp/README.md", "vorp/index.md"),
]
CODE_EXT = {".lua": "lua", ".js": "js", ".html": "html", ".css": "css", ".sql": "sql", ".json": "json"}

def copy_md(src, dst):
    s = ROOT / src
    d = OUT / dst
    if s.is_file():
        d.parent.mkdir(parents=True, exist_ok=True); shutil.copy2(s, d); return
    d.mkdir(parents=True, exist_ok=True)
    for f in sorted(s.glob("*.md")):
        name = "index.md" if f.name.lower() == "readme.md" else f.name
        shutil.copy2(f, d / name)

def code_pages(src_dir, dst_dir, title):
    """One markdown page listing every code file in src_dir (recursive)."""
    s = ROOT / src_dir
    parts = [f"# {title}\n"]
    readme = s / "README.md"
    if readme.exists():
        parts.append(readme.read_text(encoding="utf-8") + "\n")
    for f in sorted(s.rglob("*")):
        if f.is_file() and f.suffix in CODE_EXT:
            rel = f.relative_to(s).as_posix()
            body = f.read_text(encoding="utf-8", errors="replace")
            parts.append(f"## `{rel}`\n\n```{CODE_EXT[f.suffix]}\n{body.rstrip()}\n```\n")
    d = OUT / dst_dir / "index.md"
    d.parent.mkdir(parents=True, exist_ok=True)
    d.write_text("\n".join(parts), encoding="utf-8")

# map brain path -> site path, for link rewriting
def build_map():
    m = {}
    for src, dst in COPY:
        s = ROOT / src
        if s.is_file():
            m[src] = dst
        else:
            for f in s.glob("*.md"):
                name = "index.md" if f.name.lower() == "readme.md" else f.name
                m[f"{src}/{f.name}"] = f"{dst}/{name}"
    m["patterns/README.md"] = "patterns/index.md"
    m["templates/rsg-template/README.md"] = "template/index.md"
    return m

LINK = re.compile(r"(\]\()([^)\s#]+)(#[^)\s]*)?(\))")

def rewrite_links(site_file, brain_file, pmap):
    text = site_file.read_text(encoding="utf-8")
    brain_dir = posix_dir(brain_file)
    site_dir = posix_dir(site_file.relative_to(OUT).as_posix())
    def fix(m):
        target = m.group(2)
        if re.match(r"^[a-z]+:", target) or target.startswith("/"):
            return m.group(0)
        brain_target = os.path.normpath(os.path.join(brain_dir, target)).replace("\\", "/")
        key = brain_target.rstrip("/")
        if key in pmap:
            new = os.path.relpath(pmap[key], site_dir or ".").replace("\\", "/")
        elif (key + "/README.md") in pmap:
            new = os.path.relpath(pmap[key + "/README.md"], site_dir or ".").replace("\\", "/")
        else:  # not on the site: link to GitHub
            kind = "tree" if (ROOT / key).is_dir() else "blob"
            new = REPO.replace("/blob/", f"/{kind}/") + key
        return m.group(1) + new + (m.group(3) or "") + m.group(4)
    site_file.write_text(LINK.sub(fix, text), encoding="utf-8")

def posix_dir(p):
    d = os.path.dirname(p)
    return d

def page_title(f):
    for line in f.read_text(encoding="utf-8").splitlines():
        if line.startswith("# "):
            return line[2:].strip().replace('"', "'")
    return f.stem

def write_config():
    """mkdocs.yml = docs-site/mkdocs.base.yml + docs-site/nav.yml with folder entries expanded."""
    out = ["INHERIT: docs-site/mkdocs.base.yml", "docs_dir: docs-site/docs", "site_dir: docs-site/site", "nav:"]
    for line in (ROOT / "docs-site/nav.yml").read_text(encoding="utf-8").splitlines():
        m = re.match(r"^(\s*)- ([^:]+): (\S+)/$", line)
        if not m:
            if not line.lstrip().startswith("#"):
                out.append(line)
            continue
        ind, label, folder = m.groups()
        out.append(f"{ind}- {label}:")
        d = OUT / folder
        files = sorted(d.glob("*.md"), key=lambda f: (f.name != "index.md", f.name))
        for f in files:
            t = "Overview" if f.name == "index.md" else (f.stem if folder == "resources" else page_title(f))
            out.append(f'{ind}    - "{t}": {folder}/{f.name}')
    (ROOT / "mkdocs.yml").write_text("# GENERATED by tools/build_docs.py - edit docs-site/mkdocs.base.yml or docs-site/nav.yml\n" + "\n".join(out) + "\n", encoding="utf-8")

def main():
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)
    for src, dst in COPY:
        if (ROOT / src).exists():
            copy_md(src, dst)
    code_pages("patterns", "patterns", "Patterns (tested snippets)")
    code_pages("templates/rsg-template", "template", "Starter template: rsg-template")
    tcss = (ROOT / "ui/theme.css").read_text(encoding="utf-8")
    (OUT / "ui/theme-css.md").write_text(f"# theme.css\n\nDrop-in NUI theme.\n\n```css\n{tcss}\n```\n", encoding="utf-8")

    # rewrite links in every copied page
    pmap = build_map()
    inv = {v: k for k, v in pmap.items()}
    for f in OUT.rglob("*.md"):
        rel = f.relative_to(OUT).as_posix()
        rewrite_links(f, inv.get(rel, rel), pmap)

    # home page
    n = len(list((ROOT / "framework/resources").glob("rsg-*.md")))
    stamp = datetime.datetime.utcnow().strftime("%d %B %Y, %H:%M UTC")
    home = (ROOT / "docs-site/home.md").read_text(encoding="utf-8")
    (OUT / "index.md").write_text(home.replace("{{RESOURCE_COUNT}}", str(n)).replace("{{UPDATED}}", stamp), encoding="utf-8")
    shutil.copytree(ROOT / "docs-site/assets", OUT / "assets", dirs_exist_ok=True)
    write_config()
    print(f"docs generated in {OUT} ({n} resources, {stamp})")

if __name__ == "__main__":
    main()
