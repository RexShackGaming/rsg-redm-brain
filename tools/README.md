# Tools

- `refresh.sh` / `refresh.ps1`: pull the latest Rexshack-RedM resources into `source/` (code only, no images) and regenerate `framework/resources/`. Run it whenever RSG updates.
- `extract.py`: the generator. It reads the Lua, SQL and fxmanifest files and writes one API file per resource.
- VORP: `refresh.sh` also mirrors the VORPCORE repos into `vorp/source/`, copies the official docs to `vorp/docs/` and generates `vorp/resources/` (`extract.py` with `BRAIN_ORG=VORPCORE`). `refresh.ps1` does RSG only.
- `extra-repos.txt`: add repo names that aren't in the txAdmin recipe.
