"""Generate per-resource API reference markdown from cloned RSG repos (redm-brain/tools).
Usage: python extract.py <repos_dir> <out_dir>
"""
import os, re, sys, subprocess
from collections import defaultdict

SRC, OUT = sys.argv[1], sys.argv[2]
SKIP_DIRS = {'.git', 'node_modules', 'dist', 'build', 'stream'}
THIRD_PARTY = {'ox_lib', 'ox_target', 'PolyZone', 'interact-sound', 'progressbar', 'rNotify', 'menu_base', 'redm-ymaps'}

pat = {
    'export': re.compile(r'\bexports?\s*\(\s*[\'"]([\w:.-]+)[\'"]\s*,\s*(?:function\s*\(([^)]*)\))?'),
    'netevent': re.compile(r'RegisterNetEvent\s*\(\s*[\'"]([^\'"]+)[\'"]'),
    'handler': re.compile(r'AddEventHandler\s*\(\s*[\'"]([^\'"]+)[\'"]'),
    'rsgcb': re.compile(r'CreateCallback\s*\(\s*[\'"]([^\'"]+)[\'"]'),
    'libcb': re.compile(r'lib\.callback\.register\s*\(\s*[\'"]([^\'"]+)[\'"]'),
    'item': re.compile(r'CreateUseableItem\s*\(\s*[\'"]([^\'"]+)[\'"]'),
    'cmd': re.compile(r'(?:RSGCore\.)?Commands\.Add\s*\(\s*[\'"]([^\'"]+)[\'"]\s*,\s*([^,]+?)\s*,.*?,\s*(?:true|false)\s*,\s*function.*?end\s*,\s*[\'"]?(\w+)?', re.S),
    'cmdsimple': re.compile(r'(?:RSGCore\.)?Commands\.Add\s*\(\s*[\'"]([^\'"]+)[\'"]'),
    'regcmd': re.compile(r'RegisterCommand\s*\(\s*[\'"]([^\'"]+)[\'"]'),
    'table': re.compile(r'CREATE TABLE(?: IF NOT EXISTS)?\s+`?(\w+)`?', re.I),
    'trig_s': re.compile(r'TriggerServerEvent\s*\(\s*[\'"]([^\'"]+)[\'"]'),
}

def side(path):
    p = path.replace('\\', '/').lower()
    if '/client' in p or p.startswith('client') or 'cl_' in os.path.basename(p): return 'client'
    if '/server' in p or p.startswith('server') or 'sv_' in os.path.basename(p): return 'server'
    if '/shared' in p or 'config' in p or p.startswith('shared'): return 'shared'
    return '?'

def walk(root):
    for d, dirs, files in os.walk(root):
        dirs[:] = [x for x in dirs if x not in SKIP_DIRS]
        for f in files:
            yield os.path.join(d, f)

def read(p):
    try:
        with open(p, encoding='utf-8', errors='ignore') as fh: return fh.read()
    except Exception: return ''

def manifest(root):
    t = read(os.path.join(root, 'fxmanifest.lua'))
    deps = []
    m = re.search(r'dependenc(?:y|ies)\s*\{([^}]*)\}', t, re.S)
    if m: deps = re.findall(r'[\'"]([^\'"]+)[\'"]', m.group(1))
    else: deps = re.findall(r'dependency\s+[\'"]([^\'"]+)[\'"]', t)
    ver = re.search(r'\bversion\s+[\'"]([^\'"]+)', t)
    desc = re.search(r'\bdescription\s+[\'"]([^\'"]+)', t)
    return deps, ver.group(1) if ver else '', desc.group(1) if desc else '', ('ui_page' in t)

def readme_intro(root):
    for n in ('README.md', 'readme.md', 'README.MD'):
        t = read(os.path.join(root, n))
        if t:
            lines = [l.strip() for l in t.splitlines() if l.strip() and not l.strip().startswith(('#', '!', '<', '[', '|', '```', '---'))]
            return ' '.join(lines[:3])[:400]
    return ''

index = []
os.makedirs(OUT, exist_ok=True)
for name in sorted(os.listdir(SRC)):
    root = os.path.join(SRC, name)
    if not os.path.isdir(root) or name in THIRD_PARTY or not os.path.exists(os.path.join(root, 'fxmanifest.lua')):
        continue
    data = defaultdict(lambda: defaultdict(set))
    all_lua = '\n'.join(read(f) for f in walk(root) if f.endswith('.lua'))
    def fn_params(t, ident):
        e = re.escape(ident)
        for src in (t, all_lua):
            d = re.search(r'function\s+' + e + r'\s*\(([^)]*)\)|' + e + r'\s*=\s*function\s*\(([^)]*)\)', src)
            if d: return d.group(1) if d.group(1) is not None else d.group(2)
        return None
    for f in walk(root):
        rel = os.path.relpath(f, root)
        if f.endswith('.lua'):
            t = read(f); s = side(rel)
            for m in pat['export'].finditer(t):
                params = m.group(2)
                if params is None:
                    ref = re.match(r'\s*([\w.:]+)\s*\)', t[m.end():])
                    if ref: params = fn_params(t, ref.group(1))
                data['export'][s].add(m.group(1) + (f"({params.strip()})" if params is not None else ''))
            for m in re.finditer(r'for\s+(\w+)\s*,\s*(\w+)\s+in\s+pairs\s*\(\s*([\w.]+)\s*\)\s*do\s+exports\s*\(\s*\1\s*,\s*\2\s*\)', t):
                tbl = re.escape(m.group(3))
                for d in re.finditer(r'(?:function\s+' + tbl + r'[.:](\w+)\s*\(([^)]*)\)|' + tbl + r'\.(\w+)\s*=\s*function\s*\(([^)]*)\))', all_lua):
                    nm = d.group(1) or d.group(3); pr = d.group(2) if d.group(1) else d.group(4)
                    data['export'][s].add(f'{nm}({pr.strip()})')
            for k in ('netevent', 'rsgcb', 'libcb', 'item', 'regcmd'):
                for m in pat[k].finditer(t): data[k][s].add(m.group(1))
            for m in pat['handler'].finditer(t):
                ev = m.group(1)
                if not ev.startswith(('onResource', 'playerDropped', 'onClientResource')): data['handler'][s].add(ev)
            for m in pat['cmdsimple'].finditer(t): data['cmd'][s].add(m.group(1))
            for m in pat['trig_s'].finditer(t):
                ev = m.group(1)
                if not ev.startswith(name): data['ext_server'][s].add(ev)
        elif f.lower().endswith('.sql'):
            for m in pat['table'].finditer(read(f)): data['table']['sql'].add(m.group(1))
    deps, ver, desc, ui = manifest(root)
    intro = readme_intro(root)
    def flat(k): return sorted(set().union(*data[k].values())) if data[k] else []
    out = [f'# {name}', '']
    if ver or desc: out.append(f'Version {ver or "?"}. {desc}'.strip())
    if intro: out += ['', intro]
    out += ['', f'Source: https://github.com/Rexshack-RedM/{name}', '']
    if deps: out += ['**Dependencies:** ' + ', '.join(f'`{d}`' for d in deps), '']
    if ui: out += ['Has NUI (`ui_page`).', '']
    def sect(title, k, fmt):
        if not data[k]: return
        out.extend([f'## {title}', ''])
        for s in ('server', 'client', 'shared', '?'):
            if data[k].get(s):
                out.append(f'**{s}:** ' + ', '.join(fmt(x) for x in sorted(data[k][s])))
                out.append('')
    q = lambda x: f'`{x}`'
    sect(f"Exports (call as exports['{name}']:Name)", 'export', q)
    sect('Net events registered', 'netevent', q)
    sect('Event handlers', 'handler', q)
    sect('Callbacks (RSGCore.Functions.CreateCallback)', 'rsgcb', q)
    sect('Callbacks (lib.callback)', 'libcb', q)
    sect('Usable items', 'item', q)
    sect('Commands (RSGCore.Commands.Add)', 'cmd', lambda x: f'`/{x}`')
    sect('Commands (RegisterCommand)', 'regcmd', lambda x: f'`/{x}`')
    sect('Server events it triggers in other resources', 'ext_server', q)
    funcs = []
    for f in sorted(walk(root)):
        if not f.endswith('.lua') or '/locales/' in f.replace('\\', '/'): continue
        defs = [re.sub(r'^\s*function\s+', '', m.group(0)).replace('self.Functions.', 'Player.Functions.')
                for m in re.finditer(r'(?m)^[ \t]*function\s+[A-Za-z_]\w*[.:][\w.:]+\s*\([^)]*\)', read(f))]
        if defs: funcs.append((os.path.relpath(f, root).replace('\\', '/'), defs))
    if funcs:
        out += ['## Public (table) functions', '']
        for rel, defs in funcs:
            out.append(f'**{rel}:** ' + ', '.join(f'`{d}`' for d in defs[:80]) + (' …' if len(defs) > 80 else ''))
            out.append('')
    if data['table']: out += ['## Database tables', '', ', '.join(q(x) for x in flat('table')), '']
    with open(os.path.join(OUT, f'{name}.md'), 'w', encoding='utf-8') as fh: fh.write('\n'.join(out).rstrip() + '\n')
    index.append((name, (desc if desc and desc.strip().lower() != name.lower() else intro)[:110].replace('|', '/').replace('**', ''), len(flat('export')), len(flat('netevent'))))

with open(os.path.join(OUT, 'README.md'), 'w', encoding='utf-8') as fh:
    fh.write('# RSG resources: generated API index\n\n'
             'Auto-generated from the Rexshack-RedM repos by `tools/extract.py`. **Do not hand-edit**; re-run `tools/refresh.sh` to update.\n'
             'Each file lists exports, net events, callbacks, usable items, commands, dependencies and DB tables, pulled from the source code.\n'
             'When an export\'s parameters are not listed, open the source repo and read the function before using it.\n\n'
             '| Resource | Description | Exports | Net events |\n|---|---|---|---|\n')
    for n, d, e, ev in index: fh.write(f'| [{n}]({n}.md) | {d} | {e} | {ev} |\n')
print(len(index), 'resources')
