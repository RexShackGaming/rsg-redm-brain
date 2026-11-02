# Documentation rules

Every session that creates or changes a resource must create `README.md` and `DOCS.md` in the resource root if they are missing, or update them to match the code before finishing. Write them from the actual code, never from guesses.

## README.md (for everyone)
1. Title, one-line description, version, dependencies, link to `DOCS.md`
2. Features
3. Installation: start order in `server.cfg`, items/images to add, database (tables created automatically; set `Config.AutoDatabase = false` and import `install.sql` to install manually)
4. Configuration table: option, default, description
5. How to use: controls, player flow, commands with permissions
6. Short developer examples
7. Locales: en, de, el, es, fr, ja, nl, pl, pt-br, ro
8. Footer: `Support: https://buymeacoffee.com/rexshack`

## DOCS.md (for server owners and developers)
1. Contents list
2. Architecture: file-by-file purpose
3. Data formats (items, metadata, config structures)
4. Every server and client export with parameters and returns
5. Events and callbacks other resources may use
6. Integration examples
7. Persistence / saving behaviour
8. Security model: what the script checks, and what calling scripts must check themselves
9. Database schema
10. Server owner how-tos
11. Troubleshooting table
12. Support footer

## Rules
- Keep both files in sync with config options, exports, commands, items and locales; remove anything that no longer exists.
- Code examples follow the coding rules (rsg-core notify/callbacks/locales, rsg-target, no ox_lib).
