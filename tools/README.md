# Tools

- `refresh.sh` / `refresh.ps1`: pull the latest Rexshack-RedM resources into `source/` (code only, no images) and regenerate `framework/resources/`. Run it whenever RSG updates.
- GitHub API rate limits: set `GITHUB_TOKEN` (a GitHub personal access token) before running the refresh if the Feather repo list is rate-limited or the API returns an empty body. The script sends it automatically and skips Feather cleanly if the API is unavailable.
- `build_support_docs.py`: refreshes the generated sections of the root `DOCS.md` support playbook (environment snapshot plus troubleshooting harvested from `source/*/DOCS.md` and `source/*/README.md`). `refresh.sh` runs it automatically.
- `extract.py`: the generator. It reads the Lua, SQL and fxmanifest files and writes one API file per resource.
- VORP: `refresh.sh` also mirrors the VORPCORE repos into `vorp/source/`, copies the official docs to `vorp/docs/` and generates `vorp/resources/` (`extract.py` with `BRAIN_ORG=VORPCORE`). 
- Feather: `refresh.sh` also mirrors every non-archived FeatherFramework repo into `feather/source/`, copies the `feather-website` docs to `feather/docs/` and generates `feather/resources/` (`BRAIN_ORG=FeatherFramework`). `refresh.ps1` runs the same `refresh.sh` through Git Bash.
- `extra-repos.txt`: add repo names that aren't in the txAdmin recipe.
- `build_docs.py`: builds the public docs site (MkDocs) from the brain. See `docs-site/README.md`.
- `update-docs.ps1`: one-click refresh + rebuild + preview/publish of the docs site on Windows.
- `../install.py`: installer that hooks the brain into AI tools (Claude Code skill, upload bundle for ChatGPT/Claude.ai, Cursor/Codex/Copilot/Windsurf project files). `--pull --refresh` also updates the brain. See `INTEGRATION.md`.
