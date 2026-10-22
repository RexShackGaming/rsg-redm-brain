# RSG MDT

Mobile Data Terminal for RSG Framework (RedM)

## Features

- **Criminal Records** — Search, create, and manage citizen criminal records
- **Warrants** — Issue and manage active/served/expired warrants
- **BOLOs** — Create and view Be On LookOut bulletins
- **Reports** — Incident, arrest, investigation, traffic, witness, and evidence reports with comments
- **Citizen Profiles** — View citizen info, profile pictures, and notes
- **Charge Templates** — Configurable charge library with fines and jail time
- **Fines System** — Issue fines with grace periods, payment locations, overdue tracking
- **Jail System** — Sentence players with configurable timing and processing delays
- **Staff Management** — Role-based permissions, admin panel, audit logging
- **Role Sync** — Automatic role synchronisation between MDT and server jobs
- **Charge Attachments** — Link charges to reports for case building
- **Multi-Language** — 9 languages included (EN, ES, PT, DE, FR, TR, RU, IT, PL)
- **Configurable** — Law enforcement jobs, permissions, incident types, fines, jail settings

## Requirements

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [ox_lib](https://github.com/Rexshack-RedM/ox_lib)
- [oxmysql](https://github.com/CommunityOx/oxmysql/releases/latest/download/oxmysql.zip)

## Installation

1. Download the resource and place it in your `resources/[rsg]/` directory
2. Import `sql/mdt.sql` into your database
3. Add the following to `server.cfg`:
```
ensure ox_lib
ensure oxmysql
ensure rsg-core
ensure rsg-mdt
```
4. Configure jobs and settings in `shared/config.lua`
5. Restart your server

## Configuration

Edit `shared/config.lua`:

- **Config.LawJobs** — Add jobs/grades with record/warrant permissions
- **Config.Settings** — Command name, keybind, on-duty requirement, search limits
- **Config.IncidentTypes** — Report types with labels and badge colors
- **Config.Fines** — Grace period, payment location coords
- **Config.Jail** — Enable/disable, delay, max distance, coords

## Usage

- Open MDT with `/mdt` command (configurable)
- Use the keybind set in `Config.Settings.keybind` (optional)
- NPC payment locations are available at sheriff offices for fine payments
- Staff admin panel for role and permission management

## Locales

Language is auto-detected by ox_lib. Set server locale with:
```
setr ox:locale en
```

Available: `en`, `es`, `pt`, `de`, `fr`, `tr`, `ru`, `it`, `pl`

Edit JSON files in `locales/` to customize strings.

## Database

Run `sql/mdt.sql` for all required tables:
`mdt_records`, `mdt_warrants`, `mdt_bolos`, `mdt_reports`, `mdt_report_comments`, `mdt_citizen_profiles`, `mdt_staff`, `mdt_roles`, `mdt_audit_logs`, `mdt_charge_templates`, `mdt_issued_charges`, `mdt_charge_attachments`, `mdt_fines`
