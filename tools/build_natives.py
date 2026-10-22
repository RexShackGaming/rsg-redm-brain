"""Build natives/db/ from VORPCORE/RDR3natives (same source redm.info uses).
Usage: python3 tools/build_natives.py <path-to-RDR3natives-clone> <brain>/natives/db"""
import json, os, sys
src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
idx = []
for fn in ("rdr3natives.json", "natives_cfx.json"):
    data = json.load(open(os.path.join(src, fn), encoding="utf-8"))
    for ns, natives in sorted(data.items()):
        lines = [f"# {ns} natives ({len(natives)})", f"Source: VORPCORE/RDR3natives `{fn}`. Grep by NAME or hash.", ""]
        for h, n in sorted(natives.items(), key=lambda x: x[1].get("name") or x[0]):
            name = n.get("name") or h
            params = ", ".join(f"{p.get('type','')} {p.get('name','')}".strip() for p in n.get("params", []))
            lines.append(f"## {name}")
            lines.append(f"`{h}` | `{n.get('return_type','void')} {name}({params})`" + (f" | build {n['build']}" if n.get("build") else ""))
            c = (n.get("comment") or "").strip()
            if c: lines.append(c)
            for ex in n.get("examples", []) or []:
                code = ex.get("code") if isinstance(ex, dict) else ex
                if code: lines.append(f"```{(ex.get('lang','lua') if isinstance(ex,dict) else 'lua')}\n{code}\n```")
            lines.append("")
            idx.append(f"{name}\t{h}\t{ns}")
        open(os.path.join(out, f"{ns}.md"), "w", encoding="utf-8").write("\n".join(lines))
idx.sort()
open(os.path.join(out, "INDEX.tsv"), "w", encoding="utf-8").write("name\thash\tnamespace\n" + "\n".join(idx) + "\n")
print(len(idx), "natives")
