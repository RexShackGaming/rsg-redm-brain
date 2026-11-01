## Contributor Terms

By submitting any contribution to this project, you agree that your contribution is provided under [license.md](license.md) and that submitting a contribution does not give you ownership or co-ownership of the project.

The project owner may use, modify, relicense, or remove contributions at their discretion.

---

## Before you contribute

- Search for existing issues and pull requests to avoid duplicate work.
- For large features or API changes, discuss on [VORP Core Discord](https://discord.gg/JjNYMnDKMf) before investing significant effort.
- Reproduce bugs on RedM with current [VORP Core](https://github.com/VORPCORE/vorp_core) and the latest `vorp_inventory` from this repository.
- Read [README.md](README.md) for install requirements and [Inventory API documentation](https://docs.vorp-core.com/api-reference/inventory) for exports and events.

## Pull requests

Open pull requests against the `main` branch

- One logical change per pull request.
- Match the existing layout: `client/` and `server/` use `controllers/`, `services/`, and `models/`; shared logic lives in `shared/`; tunables in `config/`; user-facing strings in `languages/`.
- Changes must benefit other servers, not only your own setup. Server-specific behavior belongs in config files, not hardcoded in core services.
- Do not break documented exports, events, or API behavior without maintainer agreement. Prefer backward-compatible additions.
- If you change the database schema, include or update SQL in the repository (for example `sql_v2_update.sql` or a new migration file) and describe what to run in the pull request.
- New user-facing text should be added to `languages/language.lua` (at least English).
- Avoid unrelated refactors, drive-by formatting of untouched files, or replacing vendored minified assets without a clear reason.

## Issues

Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.md) for defects. Include reproduction steps, expected vs actual behavior, and your environment (RedM build, `vorp_core` and `vorp_inventory` versions if known).

## We typically decline

- Changes useful only on one server without a config toggle or generic hook
- Large unrelated refactors mixed with a feature or fix
- Breaking API or export changes without maintainer approval
- Secrets, license keys, or server-specific identifiers committed to core code

## Security

Do not open public issues for duplication exploits, item duplication, or other security-sensitive bugs. Report them privately via [VORP Core Discord](https://discord.gg/JjNYMnDKMf).

## Forks and private servers

You may fork this repository for your own server. Upstream improvements should be submitted here as pull requests when they are generic and reusable. Server-only customizations should stay in your fork’s config or a separate resource that depends on `vorp_inventory`, not in pull requests meant for everyone.
