# Integrating the brain with your AI tools

The brain only helps if your AI actually reads it before writing code. This guide shows how to hook it into each tool, from fully automatic to manual.

**Fast path:** run the installer.

```bash
python install.py            # interactive menu
python install.py --check    # is the brain healthy, and what is already hooked up?
```

On Windows use `python install.py` (or `py install.py`) from Command Prompt, PowerShell or Git Bash. Python 3.8+ is all you need; the script uses only the standard library.

| You use | Best option | What it needs |
|---|---|---|
| Claude Code (terminal, VS Code, desktop) | [Section 1](#1-claude-code) | `python install.py --claude-code` |
| Claude desktop app (Cowork) | [Section 2](#2-claude-desktop-app-cowork) | Connect the brain folder |
| Claude.ai Project (web) | [Section 3](#3-claudeai-projects) | `python install.py --bundle`, then upload |
| ChatGPT Custom GPT | [Section 4](#4-chatgpt-custom-gpt-recommended-for-chatgpt) | `python install.py --bundle`, then upload |
| ChatGPT Project / plain chat | [Section 5](#5-chatgpt-projects-and-plain-chats) | Same bundle |
| Codex CLI, Cursor, Copilot, Windsurf | [Section 6](#6-codex-cursor-copilot-windsurf) | `--project DIR` flags |

**How much the AI can see decides the setup.** Tools that can read your disk (Claude Code, Claude desktop, Cursor, Codex) get the whole brain and search it themselves, so they never guess. Chat tools with uploads (ChatGPT, Claude.ai) only get a condensed bundle of about 0.7 MB (rules, environment, every resource API and a natives name index). They can't search the big data folders, so the instructions tell them to ask you to grep and paste instead of inventing values.

---

## Before you start

1. Clone the brain and fill it:
   ```bash
   git clone https://github.com/RexShackGaming/rsg-redm-brain.git
   cd rsg-redm-brain/tools && ./refresh.sh        # Windows: .\refresh.ps1 from PowerShell
   ```
   Or let the installer do it: `python install.py --pull --refresh`.
2. Edit `server/environment.md` so it matches your server. It overrides every other file in the brain.
3. Run `python install.py --check`. All `[ok]` lines mean the brain is complete. A `[warn]` on `source/` or `framework/resources` means you haven't run the refresh yet.

---

## 1. Claude Code

Claude Code can read, grep and edit files, so it gets the full brain.

### Once, for every project (recommended)

```bash
python install.py --claude-code
```

This writes a user-level skill to `~/.claude/skills/rsg-redm-brain/SKILL.md` (`%USERPROFILE%\.claude\...` on Windows, or `$CLAUDE_CONFIG_DIR` if you set it). The skill carries the absolute path of your brain. Claude Code loads it on its own whenever a task is about RedM or RSG, from any folder, and the skill tells it to read `CLAUDE.md` and then only the files the task needs. It costs almost no context when you work on something else.

### Per script folder

If you want the brain loaded every time in a specific resource folder:

```bash
python install.py --project D:\GitHub\rex-scripts\rsg-example --claude-project
```

This adds a managed block to that folder's `CLAUDE.md` containing `@<brain>/CLAUDE.md` (an import) and a short pointer, and adds the brain to `permissions.additionalDirectories` in `.claude/settings.json` so Claude can read it without asking each time. The first time Claude Code sees an external `@` import it asks you to approve it once.

### Without the installer

```bash
cd rsg-redm-brain && claude                       # brain as the project
claude --add-dir ../rsg-redm-brain                # brain next to the script you're building
```

### Tips
- Say what you want in one line: *"Create rsg-example, a script that does X. Use the brain."* The skill and `CLAUDE.md` do the rest.
- Use `/memory` in Claude Code to confirm the brain block or import is loaded.
- Re-run `python install.py --pull --refresh` whenever RSG resources update; nothing needs re-installing because the skill points at the live folder.

---

## 2. Claude desktop app (Cowork)

1. Open the chat, click **Add folder** (or choose a folder when you start a task) and select your `rsg-redm-brain` folder. If you are also working on a script, connect that folder too.
2. `CLAUDE.md` in the folder is picked up as project instructions automatically.
3. Start with: *"Read CLAUDE.md in the brain, then build X."*

The user-level skill from Section 1 also works here if you run Claude Code on the same machine. Skills you upload in Claude settings (for example `redm-brain` or `rsg-framework`) can sit alongside the folder; the folder is always the most current source.

---

## 3. Claude.ai Projects

The web app can't read your disk, so you give it the bundle.

1. Build the bundle:
   ```bash
   python install.py --bundle
   ```
   This creates `dist/` in the brain folder (git-ignored) containing:
   - `01-core.md` entry point, environment, conventions, patterns, NUI standard, framework guides, native guides, audit checklist, resource template
   - `02-api-reference-part-N.md` exports, events, callbacks, items, commands and DB tables for every RSG resource
   - `03-natives-index.txt` native names, hashes and namespaces
   - `INSTRUCTIONS-claude-project.txt` and `INSTRUCTIONS-chatgpt-custom-gpt.txt`
   - `UPLOAD-ME-FIRST.txt` a checklist
2. In Claude.ai go to **Projects → Create project** (name it *RedM RSG*).
3. Paste `INSTRUCTIONS-claude-project.txt` into **Set project instructions**.
4. Add `01-core.md`, every `02-api-reference-part-*.md` and `03-natives-index.txt` as **project knowledge**.
5. Start chats inside the project. Every chat now begins with the rules and can look up resource APIs.

Claude Projects switch to search-based retrieval when knowledge is large, which suits this bundle. Add `--no-natives` if you want a smaller bundle.

---

## 4. ChatGPT Custom GPT (recommended for ChatGPT)

A Custom GPT keeps the rules permanently and searches the knowledge files on demand. Creating one needs a paid ChatGPT plan.

1. `python install.py --bundle`
2. In ChatGPT open **Explore GPTs → Create** and switch to the **Configure** tab.
3. **Name:** `RSG RedM Script Builder`. **Description:** one line is enough.
4. **Instructions:** paste the whole of `INSTRUCTIONS-chatgpt-custom-gpt.txt`. It is kept under the 8,000 character limit (the installer warns if it ever grows past it).
5. **Knowledge:** upload `01-core.md`, all `02-api-reference-part-*.md` and `03-natives-index.txt`. That is three or four files, well inside the 20-file limit.
6. **Capabilities:** turn **Code Interpreter** on (lets the GPT build and hand you zip files of a full resource). Web search is optional; it helps for native lookups but can pull in non-RSG advice, so leave it off if you see it ignoring the knowledge files.
7. Set sharing to **Only me** (or a link for your team) and save.

Test it with *"What exports does rsg-gizmo have for placing a prop?"* and *"Which item name do we use for wood?"*. The answers should name `Place` / `Edit` and `resource_wood`. If it answers from memory or hedges, check the knowledge files finished processing.

---

## 5. ChatGPT Projects and plain chats

**Projects:** create a project, paste `INSTRUCTIONS-chatgpt-custom-gpt.txt` into the project instructions and add the bundle files as project files. Upload limits differ by plan, so if one is rejected, drop `03-natives-index.txt` first.

**Plain chat, no uploads:** paste the contents of `INSTRUCTIONS-chatgpt-custom-gpt.txt`, then attach `01-core.md` plus the one `framework/resources/<resource>.md` you need. For data values (peds, props, anims, scenarios) grep your local brain and paste the matching lines:

```bash
rg -i "a_c_horse_arabian" data/rdr3_discoveries/peds
rg "TASK_START_SCENARIO" natives/db/INDEX.tsv
```

Never attach the big data folders whole.

---

## 6. Codex, Cursor, Copilot, Windsurf

These read instruction files inside the folder you're working in. The installer writes a short managed pointer to the brain into each one:

```bash
python install.py --project D:\GitHub\rex-scripts\rsg-example --codex --cursor --copilot --windsurf
```

| Tool | File written |
|---|---|
| Codex CLI and other `AGENTS.md` readers | `AGENTS.md` |
| Cursor | `.cursor/rules/rsg-redm-brain.mdc` |
| GitHub Copilot | `.github/copilot-instructions.md` |
| Windsurf | `.windsurfrules` |

Also add the brain folder to the editor workspace (Cursor and Windsurf: **Add Folder to Workspace**) so the tool can search it. Codex needs read access to the brain path, for example `codex --add-dir <brain>`.

The brain also ships its own `AGENTS.md`, so opening the brain folder directly in Codex works with no setup.

---

## Keeping it up to date

| When | Do |
|---|---|
| RSG resources changed | `python install.py --pull --refresh` |
| You changed `server/environment.md` or conventions | Rebuild the bundle (`--bundle`) and re-upload `01-core.md` to Claude.ai / ChatGPT. Disk-based tools need nothing |
| New resources were added | `--refresh`, rebuild the bundle, re-upload the `02-api-reference` files |
| Moved the brain folder | Re-run the installer targets so the stored path updates |

## Removing it

```bash
python install.py --uninstall --claude-code --bundle
python install.py --uninstall --project D:\path\to\script --claude-project --cursor --codex --copilot --windsurf
```

Only the managed block between `<!-- rsg-redm-brain:start -->` and `<!-- rsg-redm-brain:end -->` is removed from shared files; the rest of the file is left alone. Add `--dry-run` to any command to preview.

## Installer reference

| Flag | Effect |
|---|---|
| *(none)* | Interactive menu |
| `--all` | Claude Code skill and bundle; with `--project` also every project target |
| `--claude-code` | User-level Claude Code skill |
| `--bundle` | Build upload files in `dist/` (`--out DIR` to change, `--no-natives` to skip the natives index) |
| `--project DIR` | Folder for the project-level targets below |
| `--claude-project` `--cursor` `--codex` `--copilot` `--windsurf` | Project-level hooks |
| `--check` | Health check of the brain and the hooks |
| `--pull` / `--refresh` | `git pull` the brain / run `tools/refresh` |
| `--uninstall` | Reverse the chosen targets |
| `--dry-run` | Show what would change, write nothing |

## Troubleshooting

| Symptom | Fix |
|---|---|
| `python` is not recognised on Windows | Reinstall Python with *Add python.exe to PATH* ticked, or use `py install.py` |
| The AI still guesses item names or exports | Check it actually loaded the brain: Claude Code `/memory`; Custom GPT test questions in Section 4. Make sure `server/environment.md` is correct |
| `[warn] source/` or `framework/resources` in `--check` | Run the refresh |
| Claude Code asks to approve an import | Expected once per project for the `@` import. Approve it |
| Custom GPT instructions rejected as too long | Re-run `--bundle`; the installer warns above 8,000 characters. Don't add extra text to the file |
| Upload rejected as too large | Re-run with `--no-natives`, or upload only `01-core.md` and the resource files you need |
