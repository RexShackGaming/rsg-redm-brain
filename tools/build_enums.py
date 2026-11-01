#!/usr/bin/env python3
"""Build data/rdr3-native-enums/ from a clone of Halen84/RDR3-Native-Flags-And-Enums.
Usage: python3 tools/build_enums.py <repo_clone> <out_dir>
One <EnumName>.md per enum (copied as-is) plus INDEX.tsv: enum, value_count, natives (name|hash;...)."""
import os, re, sys, shutil
src, out = sys.argv[1], sys.argv[2]
if os.path.isdir(out):
    shutil.rmtree(out)
os.makedirs(out)
rows = []
for d in sorted(os.listdir(src), key=str.lower):
    p = os.path.join(src, d, "README.md")
    if d.startswith(".") or not os.path.isfile(p):
        continue
    text = open(p, encoding="utf-8", errors="replace").read()
    name = re.sub(r"[^A-Za-z0-9_.-]+", "_", d).strip("_")
    with open(os.path.join(out, name + ".md"), "w", encoding="utf-8") as f:
        f.write(f"# {d}\n\nSource: https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/{d.replace(' ', '%20')}\n\n{text}")
    natives = []
    for m in re.finditer(r"^\|\s*([A-Z_]+::[^|]+?)\s*\|\s*(0x[0-9A-Fa-f]+)\s*\|", text, re.M):
        natives.append(m.group(1).replace("\\_", "_") + "|" + m.group(2))
    count = len(re.findall(r"^\s*[A-Za-z_0-9]+\s*=\s*[^,\n]+,?\s*$", text, re.M))
    rows.append((name, str(count), ";".join(natives)))
with open(os.path.join(out, "INDEX.tsv"), "w", encoding="utf-8") as f:
    f.write("enum\tvalues\tnatives\n")
    for r in rows:
        f.write("\t".join(r) + "\n")
print(f"{len(rows)} enums -> {out}")
