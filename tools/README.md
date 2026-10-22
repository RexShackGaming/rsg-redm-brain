# Tools

- `refresh.sh` / `refresh.ps1`: pull the latest Rexshack-RedM resources into `source/` (code only, no images) and regenerate `framework/resources/`. Run it whenever RSG updates.
- `extract.py`: the generator. It reads the Lua, SQL and fxmanifest files and writes one API file per resource.
- `extra-repos.txt`: add repo names that aren't in the txAdmin recipe.
