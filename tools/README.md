# Tools

- `refresh.sh` / `refresh.ps1`: pull the latest Rexshack-RedM resources into `source/` (code only, no images) and regenerate `framework/resources/`. Run it whenever RSG updates.
- `extract.py`: the generator. It reads the Lua, SQL and fxmanifest files and writes one API file per resource.
- VORP: `refresh.sh` also mirrors the VORPCORE repos into `vorp/source/`, copies the official docs to `vorp/docs/` and generates `vorp/resources/` (`extract.py` with `BRAIN_ORG=VORPCORE`). 
- Feather: `refresh.sh` also mirrors every non-archived FeatherFramework repo into `feather/source/`, copies the `feather-website` docs to `feather/docs/` and generates `feather/resources/` (`BRAIN_ORG=FeatherFramework`). `refresh.ps1` runs the same `refresh.sh` through Git Bash.
- `extra-repos.txt`: add repo names that aren't in the txAdmin recipe.
- `build_docs.py`: builds the public docs site (MkDocs) from the brain. See `docs-site/README.md`.
- `update-docs.ps1`: one-click refresh + rebuild + preview/publish of the docs site on Windows.
