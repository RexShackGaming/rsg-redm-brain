#!/usr/bin/env python3
"""
RSG RedM Brain installer
========================

Hooks the brain into the AI tools you use. Standard library only (Python 3.8+),
works on Windows, macOS and Linux.

    python install.py                   interactive menu
    python install.py --check           health check of the brain + what is installed
    python install.py --all             Claude Code skill + upload bundle
    python install.py --claude-code     user-level Claude Code skill (works in every project)
    python install.py --bundle          build upload files for ChatGPT / Claude.ai (./dist)
    python install.py --project D:\\GitHub\\my-script --claude-project --cursor --codex
    python install.py --uninstall --all [--project DIR]
    python install.py --pull            git pull the brain first (add --refresh to run tools/refresh)

Add --dry-run to any command to see what would change without writing anything.
Everything written into shared files (CLAUDE.md, AGENTS.md ...) sits between
<!-- rsg-redm-brain:start --> and <!-- rsg-redm-brain:end --> markers, so it can be
updated or removed cleanly and never touches the rest of the file.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

BRAIN = Path(__file__).resolve().parent
START = "<!-- rsg-redm-brain:start -->"
END = "<!-- rsg-redm-brain:end -->"
DRY = False
CHUNK_BYTES = 350_000          # size of each API-reference upload part
GPT_INSTRUCTION_LIMIT = 8000   # Custom GPT instructions field limit (characters)

# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #

def say(msg=""):
    print(msg)

def ok(msg):
    print("  [ok]   " + msg)

def warn(msg):
    print("  [warn] " + msg)

def act(msg):
    print(("  [dry]  " if DRY else "  [write] ") + msg)

def brain_posix():
    return BRAIN.as_posix()

def claude_dir():
    env = os.environ.get("CLAUDE_CONFIG_DIR")
    return Path(env).expanduser() if env else Path.home() / ".claude"

def write_text(path, text):
    act(str(path))
    if DRY:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")

def read_text(path):
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return None

def block(body):
    return "{}\n{}\n{}\n".format(START, body.strip("\n"), END)

BLOCK_RE = re.compile(re.escape(START) + r".*?" + re.escape(END) + r"\n?", re.S)

def upsert_block(path, body, header=None):
    """Insert or replace the managed block in a shared file."""
    cur = read_text(path)
    new = block(body)
    if cur is None:
        text = (header or "") + new
    elif BLOCK_RE.search(cur):
        text = BLOCK_RE.sub(lambda m: new, cur, count=1)
    else:
        text = cur.rstrip("\n") + "\n\n" + new
    write_text(path, text)

def remove_block(path):
    cur = read_text(path)
    if cur is None or not BLOCK_RE.search(cur):
        return False
    text = BLOCK_RE.sub("", cur).rstrip("\n") + "\n"
    act("remove block from " + str(path))
    if DRY:
        return True
    if text.strip() == "":
        path.unlink()
    else:
        path.write_text(text, encoding="utf-8", newline="\n")
    return True

def remove_file(path):
    if path.exists():
        act("delete " + str(path))
        if not DRY:
            path.unlink()
            try:
                path.parent.rmdir()   # only succeeds if empty
            except OSError:
                pass
        return True
    return False

# --------------------------------------------------------------------------- #
# the instruction texts
# --------------------------------------------------------------------------- #

RULES = """\
You build RedM resources for a server running the RSG Framework (rsg-core 3.0.3), Lua 5.4, oxmysql and rsg-target (replaces ox_target). ox_lib is being phased out: rsg-core provides notify, callbacks and multi-job.

GOLDEN RULES
1. Never guess hashes, model names, anim dicts, scenarios, flag IDs, item names, native hashes, exports, events or callbacks. Look them up in the knowledge files. If a value is not there, say so plainly and tell the user exactly what to look up (for example "grep natives/db/INDEX.tsv for TASK_START_SCENARIO", or redm.info / redm-forge.vercel.app). Never invent a plausible value.
2. Never trust the client. All money and item changes happen on the server after validation (player in range, cooldowns, item checks, rate limits).
3. Notifications go through rsg-core (RSGCore.Functions.Notify server side, RSGCore:Client:Notify client side), never ox_lib. All player-facing text lives in locales (en, de, el, es, fr, ja, nl, pl, pt-br, ro).
4. Targeting uses rsg-target, not ox_target. Props are placed with rsg-gizmo (exports['rsg-gizmo']:Place), never a custom placement loop.
5. NUI follows the house style in ui/design-standard.md and ui/theme.css (no vignette). Push-to-talk must keep working while any NUI has focus: route every focus change through applyNuiFocus() with SetNuiFocusKeepInput(true) and a per-frame control whitelist (patterns/nui-push-to-talk.md).
6. Put coords, timers, prices and text in config or locales, never hard-coded.
7. Database tables are created automatically by the script (Config.AutoDatabase), with install.sql kept for manual installs.
8. Before calling any RSG resource's export, event or callback, check framework/resources/<resource>.md for the exact name and parameters.
9. When sources disagree the precedence is: server/environment.md > real source code > framework/ guides > everything else.
10. Start every new resource from the structure in templates/rsg-template (fxmanifest.lua, client/, server/, shared/, locales/, html/, install.sql, README.md, DOCS.md).

WORKFLOW
1. Read server/environment.md (what is installed, what is removed, item names) and conventions/coding-rules.md.
2. Find similar RSG resources in framework/resources and follow their patterns.
3. Give complete, runnable code split by file path, one fenced block per file with the path as a heading.
4. Always finish with README.md and DOCS.md for the resource, written from the actual code (conventions/documentation.md).
5. Check the result against audit/audit-checklist.md before finishing, and tell the user which knowledge file each looked-up value came from.
"""

KNOWLEDGE_CHAT = """\
KNOWLEDGE FILES (search them before answering; do not rely on memory)
- 01-core.md: the brain's entry point, server/environment.md, conventions, patterns, NUI design standard, RSGCore / inventory / banking guides, native guides, audit checklist and the resource template. Each file starts with a line "=== FILE: path ===".
- 02-api-reference-part-N.md: generated API reference for every RSG resource (exports with parameters, net events, callbacks, usable items, commands, DB tables). Check the matching resource before calling any of its APIs.
- 03-natives-index.txt: native names, hashes and namespaces. It has no signatures; if you need parameters, say which native and ask the user to paste its entry from natives/db/ in the brain.
You do NOT have the full data folders (peds, props, anims, scenarios, decompiled scripts) or the source mirror. For those values ask the user to grep their local brain and paste the lines. Never fabricate them.
"""

def chatgpt_instructions():
    return RULES + "\n" + KNOWLEDGE_CHAT

def claude_project_instructions():
    return RULES + "\n" + KNOWLEDGE_CHAT.replace("KNOWLEDGE FILES", "PROJECT KNOWLEDGE")

def pointer_body(path_text=None):
    p = path_text or brain_posix()
    return """\
## RedM / RSG Framework scripts
For any RedM or RSG Framework task (new script, fix, audit, conversion, support ticket) use the RedM brain at:
`{p}`

Read `{p}/CLAUDE.md` first (golden rules, folder map, workflow), then open only the files the task needs. Never guess hashes, item names, exports or events: look them up in the brain and say which file each value came from. Precedence: `server/environment.md` > `source/` > `framework/` > everything else.
Finish every resource with an up-to-date `README.md` and `DOCS.md`.""".format(p=p)

def skill_text():
    return """\
---
name: rsg-redm-brain
description: Use whenever writing, fixing, auditing, converting or supporting a RedM / RSG Framework (rsg-core) script, NUI, native, hash, item or resource export. Loads the RedM brain knowledge base so nothing is guessed.
---

# RSG RedM brain

The brain lives at `{p}`.

1. Read `{p}/CLAUDE.md` (golden rules, folder map, workflow). It is short.
2. Read `{p}/server/environment.md` and `{p}/conventions/coding-rules.md` for every script.
3. Open only what the task needs:
   - RSG exports/events/callbacks: `{p}/framework/resources/<resource>.md`, then the real code in `{p}/source/<resource>/`
   - natives: grep `{p}/natives/db/INDEX.tsv`, then open the matching file in `{p}/natives/db/`
   - peds, props, anims, scenarios, flags: `{p}/data/rdr3_discoveries/MAP.md`, then search the file (never read big files whole)
   - NUI: `{p}/ui/design-standard.md`, `{p}/ui/theme.css`, `{p}/patterns/nui-push-to-talk.md`
   - props placed in the world: `{p}/patterns/prop-placement.md` (rsg-gizmo)
   - support tickets: `{p}/DOCS.md`
   - new resources: copy `{p}/templates/rsg-template/`
4. Never guess a hash, model, anim, scenario, flag, item name, export or event. Say which brain file each value came from.
5. Before finishing: create or update the resource's `README.md` and `DOCS.md`, and check `{p}/audit/audit-checklist.md`.
""".format(p=brain_posix())

def cursor_rule():
    return """\
---
description: RedM / RSG Framework scripting rules and knowledge base. Use for any RedM, RSG, rsg-core, NUI or native task.
alwaysApply: false
---

""" + block(pointer_body())

# --------------------------------------------------------------------------- #
# targets that write into the user's tools
# --------------------------------------------------------------------------- #

def install_claude_code():
    say("Claude Code (user-level skill)")
    write_text(claude_dir() / "skills" / "rsg-redm-brain" / "SKILL.md", skill_text())
    ok("Claude Code will load the brain automatically on RedM/RSG tasks, in any folder.")

def uninstall_claude_code():
    if remove_file(claude_dir() / "skills" / "rsg-redm-brain" / "SKILL.md"):
        ok("removed Claude Code skill")

def settings_edit(project, add):
    path = project / ".claude" / "settings.json"
    cur = read_text(path)
    try:
        data = json.loads(cur) if cur else {}
    except ValueError:
        warn("{} is not valid JSON; leaving it alone. Add the brain with `claude --add-dir`.".format(path))
        return
    perms = data.setdefault("permissions", {})
    dirs = perms.setdefault("additionalDirectories", [])
    b = brain_posix()
    if add and b not in dirs:
        dirs.append(b)
    elif not add and b in dirs:
        dirs.remove(b)
    else:
        return
    if not add:
        if not dirs:
            perms.pop("additionalDirectories", None)
        if not perms:
            data.pop("permissions", None)
    write_text(path, json.dumps(data, indent=2) + "\n")

def install_claude_project(project):
    say("Claude Code project: " + str(project))
    upsert_block(project / "CLAUDE.md", "@{}/CLAUDE.md\n\n{}".format(brain_posix(), pointer_body()),
                 header="# Project instructions\n\n")
    settings_edit(project, True)
    ok("CLAUDE.md imports the brain; brain folder added to .claude/settings.json")

def uninstall_claude_project(project):
    remove_block(project / "CLAUDE.md")
    if (project / ".claude" / "settings.json").exists():
        settings_edit(project, False)

def install_cursor(project):
    say("Cursor: " + str(project))
    write_text(project / ".cursor" / "rules" / "rsg-redm-brain.mdc", cursor_rule())
    ok("add the brain folder to the Cursor workspace so @-mentions and search can reach it")

def uninstall_cursor(project):
    remove_file(project / ".cursor" / "rules" / "rsg-redm-brain.mdc")

def install_pointer(project, rel, label):
    say("{}: {}".format(label, project))
    upsert_block(project / rel, pointer_body())

def uninstall_pointer(project, rel):
    remove_block(project / rel)

# --------------------------------------------------------------------------- #
# bundle for chat tools with no file system access
# --------------------------------------------------------------------------- #

CORE_FILES = [
    "CLAUDE.md", "server/environment.md",
    "conventions/coding-rules.md", "conventions/security.md",
    "conventions/notify-locales.md", "conventions/documentation.md",
    "ui/design-standard.md", "ui/theme.css",
    "patterns/README.md", "patterns/nui-push-to-talk.md", "patterns/prop-placement.md",
    "patterns/nui-bridge.lua", "patterns/rsg-target.lua",
    "patterns/server-reward-event.lua", "patterns/entity-cleanup.lua",
    "framework/rsg-core.md", "framework/rsg-inventory.md", "framework/rsg-banking.md",
    "framework/other-exports.md", "framework/oxlib-migration.md",
    "natives/ped-ai-combat.md", "natives/game-events.md", "natives/prompts-blips-entities.md",
    "audit/audit-checklist.md", "audit/ai-procedure.md",
]

def file_section(rel):
    p = BRAIN / rel
    if not p.is_file():
        return None
    return "=== FILE: {} ===\n{}\n".format(rel, p.read_text(encoding="utf-8", errors="replace").rstrip())

def template_files():
    root = BRAIN / "templates" / "rsg-template"
    out = []
    if root.is_dir():
        for p in sorted(root.rglob("*")):
            if p.is_file() and p.suffix.lower() in (".lua", ".md", ".sql", ".json", ".html", ".css", ".js"):
                out.append(p.relative_to(BRAIN).as_posix())
    return out

def build_bundle(out_dir, with_natives=True):
    say("Upload bundle -> " + str(out_dir))
    if not (BRAIN / "CLAUDE.md").is_file():
        warn("CLAUDE.md not found; is this the brain folder?")
        return
    files = {}

    core = [file_section(r) for r in CORE_FILES + template_files()]
    files["01-core.md"] = ("# RSG RedM brain: core pack\n\n"
                           "Entry point, server environment, conventions, patterns, NUI standard, "
                           "framework guides, native guides, audit checklist and resource template.\n\n"
                           + "\n".join(s for s in core if s))

    res_dir = BRAIN / "framework" / "resources"
    parts, cur, size, names = [], [], 0, []
    for p in sorted(res_dir.glob("*.md")) if res_dir.is_dir() else []:
        if p.name.lower() == "readme.md":
            continue
        sec = file_section(p.relative_to(BRAIN).as_posix())
        if cur and size + len(sec) > CHUNK_BYTES:
            parts.append((cur, names)); cur, names, size = [], [], 0
        cur.append(sec); names.append(p.stem); size += len(sec)
    if cur:
        parts.append((cur, names))
    idx = BRAIN / "framework" / "resources" / "README.md"
    for i, (secs, names) in enumerate(parts, 1):
        head = "# RSG resource API reference, part {}/{}\n\nResources in this part: {}\n\n".format(
            i, len(parts), ", ".join(names))
        if i == 1 and idx.is_file():
            head += file_section("framework/resources/README.md") + "\n"
        files["02-api-reference-part-{}.md".format(i)] = head + "\n".join(secs)

    if with_natives:
        n = BRAIN / "natives" / "db" / "INDEX.tsv"
        if n.is_file():
            files["03-natives-index.txt"] = n.read_text(encoding="utf-8", errors="replace")

    gpt = chatgpt_instructions()
    if len(gpt) > GPT_INSTRUCTION_LIMIT:
        warn("ChatGPT instructions are {} chars, over the {} limit".format(len(gpt), GPT_INSTRUCTION_LIMIT))
    files["INSTRUCTIONS-chatgpt-custom-gpt.txt"] = gpt
    files["INSTRUCTIONS-claude-project.txt"] = claude_project_instructions()

    knowledge = sorted(k for k in files if not k.startswith("INSTRUCTIONS"))
    files["UPLOAD-ME-FIRST.txt"] = (
        "RSG RedM brain upload bundle (generated by install.py)\n\n"
        "KNOWLEDGE FILES (upload all of these):\n" +
        "\n".join("  - {} ({:,} KB)".format(k, len(files[k].encode("utf-8")) // 1024) for k in knowledge) +
        "\n\nINSTRUCTIONS (paste the text into the instructions box):\n"
        "  - ChatGPT Custom GPT or Project -> INSTRUCTIONS-chatgpt-custom-gpt.txt ({} chars, limit {})\n"
        "  - Claude.ai Project             -> INSTRUCTIONS-claude-project.txt\n\n"
        "Full walkthrough: INTEGRATION.md in the brain folder.\n"
        "Re-run `python install.py --bundle` after refreshing the brain and re-upload the changed files.\n"
        .format(len(gpt), GPT_INSTRUCTION_LIMIT))

    for name, text in files.items():
        write_text(out_dir / name, text)
    ok("{} knowledge files + 2 instruction files. Open UPLOAD-ME-FIRST.txt for next steps.".format(len(knowledge)))

def clean_bundle(out_dir):
    if out_dir.is_dir() and (out_dir / "UPLOAD-ME-FIRST.txt").exists():
        act("delete folder " + str(out_dir))
        if not DRY:
            shutil.rmtree(out_dir, ignore_errors=True)
        ok("removed bundle")

# --------------------------------------------------------------------------- #
# check / pull
# --------------------------------------------------------------------------- #

def count(path, pattern="*"):
    return len(list(path.glob(pattern))) if path.is_dir() else 0

def run_check(project=None):
    say("Brain: " + str(BRAIN))
    problems = 0
    for rel in ("CLAUDE.md", "server/environment.md", "conventions/coding-rules.md",
                "ui/design-standard.md", "templates/rsg-template/fxmanifest.lua",
                "natives/db/INDEX.tsv", "data/rdr3_discoveries/MAP.md"):
        if (BRAIN / rel).is_file():
            ok(rel)
        else:
            warn("missing " + rel); problems += 1
    n_res = count(BRAIN / "framework" / "resources", "*.md")
    n_src = len([p for p in (BRAIN / "source").glob("*") if p.is_dir()]) if (BRAIN / "source").is_dir() else 0
    (ok if n_res > 5 else warn)("framework/resources: {} files".format(n_res))
    (ok if n_src > 5 else warn)("source/: {} resource folders".format(n_src))
    if n_res <= 5 or n_src <= 5:
        warn("run tools/refresh.sh (or tools\\refresh.ps1 on Windows) to fill source/ and framework/resources/")
        problems += 1
    say("\nInstalled hooks")
    sk = claude_dir() / "skills" / "rsg-redm-brain" / "SKILL.md"
    (ok if sk.exists() else warn)("Claude Code user skill: " + ("installed" if sk.exists() else "not installed (--claude-code)"))
    b = BRAIN / "dist" / "UPLOAD-ME-FIRST.txt"
    (ok if b.exists() else warn)("upload bundle: " + ("built in ./dist" if b.exists() else "not built (--bundle)"))
    if project:
        for rel in ("CLAUDE.md", "AGENTS.md", ".github/copilot-instructions.md", ".windsurfrules"):
            t = read_text(project / rel)
            if t is not None:
                (ok if START in t else warn)("{}: {}".format(project / rel, "brain block present" if START in t else "file exists, no brain block"))
        mdc = project / ".cursor" / "rules" / "rsg-redm-brain.mdc"
        if mdc.exists():
            ok(str(mdc))
    return problems

def git_pull():
    say("git pull")
    if not (BRAIN / ".git").exists():
        warn("not a git checkout, skipping"); return
    if DRY:
        act("git pull --ff-only"); return
    try:
        r = subprocess.run(["git", "-C", str(BRAIN), "pull", "--ff-only"], capture_output=True, text=True, timeout=120)
        print(r.stdout.strip() or r.stderr.strip())
    except (OSError, subprocess.SubprocessError) as e:
        warn("git failed: {}".format(e))

def run_refresh():
    say("refresh source/ and framework/resources/")
    script = BRAIN / "tools" / ("refresh.ps1" if os.name == "nt" else "refresh.sh")
    if not script.exists():
        warn("{} not found".format(script)); return
    cmd = (["powershell", "-ExecutionPolicy", "Bypass", "-File", str(script)] if os.name == "nt"
           else ["bash", str(script)])
    if DRY:
        act(" ".join(cmd)); return
    subprocess.run(cmd, cwd=str(script.parent))

# --------------------------------------------------------------------------- #
# main
# --------------------------------------------------------------------------- #

PROJECT_TARGETS = ("claude_project", "cursor", "codex", "copilot", "windsurf")

def interactive(args):
    say("RSG RedM brain installer\nBrain folder: {}\n".format(BRAIN))
    menu = [
        ("claude_code", "Claude Code: user-level skill (every project)"),
        ("bundle", "Upload bundle for ChatGPT (Custom GPT / Projects) and Claude.ai Projects"),
        ("claude_project", "Claude Code: wire a specific script folder (CLAUDE.md + settings)"),
        ("cursor", "Cursor rule for a specific script folder"),
        ("codex", "Codex / generic AGENTS.md for a specific script folder"),
        ("copilot", "GitHub Copilot instructions for a specific script folder"),
        ("windsurf", "Windsurf rules for a specific script folder"),
    ]
    for i, (_, label) in enumerate(menu, 1):
        say("  {}) {}".format(i, label))
    say("  c) health check    q) quit")
    pick = input("\nChoose (e.g. 1,2): ").strip().lower()
    if pick in ("q", ""):
        return False
    if pick == "c":
        args.check = True
        return True
    for tok in re.split(r"[,\s]+", pick):
        if tok.isdigit() and 1 <= int(tok) <= len(menu):
            setattr(args, menu[int(tok) - 1][0], True)
    if any(getattr(args, t) for t in PROJECT_TARGETS) and not args.project:
        d = input("Path to your script / project folder: ").strip().strip('"')
        args.project = Path(d).expanduser() if d else None
    return True

def main():
    global DRY
    ap = argparse.ArgumentParser(description="Install the RSG RedM brain into your AI tools.",
                                 formatter_class=argparse.RawDescriptionHelpFormatter,
                                 epilog=__doc__.split("\n\n", 1)[1])
    ap.add_argument("--all", action="store_true", help="claude-code + bundle (+ every project target if --project is given)")
    ap.add_argument("--claude-code", dest="claude_code", action="store_true")
    ap.add_argument("--bundle", action="store_true")
    ap.add_argument("--no-natives", action="store_true", help="leave the natives index out of the bundle")
    ap.add_argument("--project", type=Path, help="script/project folder for the project-level targets")
    ap.add_argument("--claude-project", dest="claude_project", action="store_true")
    ap.add_argument("--cursor", action="store_true")
    ap.add_argument("--codex", action="store_true")
    ap.add_argument("--copilot", action="store_true")
    ap.add_argument("--windsurf", action="store_true")
    ap.add_argument("--uninstall", action="store_true")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--pull", action="store_true")
    ap.add_argument("--refresh", action="store_true")
    ap.add_argument("--out", type=Path, help="bundle output folder (default: ./dist in the brain)")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    DRY = args.dry_run

    chosen = [args.all, args.claude_code, args.bundle, args.check, args.pull, args.refresh] + \
             [getattr(args, t) for t in PROJECT_TARGETS]
    if not any(chosen):
        if not sys.stdin.isatty():
            ap.print_help(); return 0
        if not interactive(args):
            return 0

    if args.all:
        args.claude_code = args.bundle = True
        if args.project:
            for t in PROJECT_TARGETS:
                setattr(args, t, True)

    project = args.project.expanduser().resolve() if args.project else None
    if any(getattr(args, t) for t in PROJECT_TARGETS) and not project:
        ap.error("--project DIR is required for the project-level targets")
    if project and not project.is_dir():
        ap.error("project folder not found: {}".format(project))

    out = (args.out or BRAIN / "dist").expanduser().resolve()
    say("")
    if args.pull:
        git_pull()
    if args.refresh:
        run_refresh()

    if args.uninstall:
        if args.claude_code: uninstall_claude_code()
        if args.bundle: clean_bundle(out)
        if project:
            if args.claude_project: uninstall_claude_project(project)
            if args.cursor: uninstall_cursor(project)
            if args.codex: uninstall_pointer(project, "AGENTS.md")
            if args.copilot: uninstall_pointer(project, ".github/copilot-instructions.md")
            if args.windsurf: uninstall_pointer(project, ".windsurfrules")
        say("\nDone." + (" (dry run, nothing changed)" if DRY else ""))
        return 0

    if args.claude_code: install_claude_code()
    if args.bundle: build_bundle(out, with_natives=not args.no_natives)
    if args.claude_project: install_claude_project(project)
    if args.cursor: install_cursor(project)
    if args.codex: install_pointer(project, "AGENTS.md", "Codex / AGENTS.md")
    if args.copilot: install_pointer(project, ".github/copilot-instructions.md", "GitHub Copilot")
    if args.windsurf: install_pointer(project, ".windsurfrules", "Windsurf")
    if args.check:
        run_check(project)

    say("\nDone." + (" (dry run, nothing changed)" if DRY else ""))
    say("Next: see INTEGRATION.md for the Claude.ai Project, Claude Desktop and ChatGPT steps.")
    return 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
