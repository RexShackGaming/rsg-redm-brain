#!/usr/bin/env python3
"""Refresh the generated sections of the root DOCS.md support playbook.

The root DOCS.md is partly hand-written and partly generated. This script
replaces only the regions marked with:

    <!-- BEGIN AUTO:NAME -->
    <!-- END AUTO:NAME -->

It is called at the end of tools/refresh.sh (which tools/refresh.ps1 runs), so
the environment snapshot and resource troubleshooting tables stay in sync with
the mirrored source.

Usage: python3 tools/build_support_docs.py
"""
from __future__ import annotations

import datetime
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOCS = ROOT / "DOCS.md"
SOURCE = ROOT / "source"
ENV = ROOT / "server" / "environment.md"

HEADING = re.compile(r"^(#{1,6})\s+(.*)$")
TABLE_SEPARATOR = re.compile(r"^:?-{2,}:?$")
SUPPORT = re.compile(r"buymeacoffee|^support\b", re.I)
EMOJI = re.compile(r"^[\U0001F300-\U0001FAFF\u2600-\u27BF\uFE0F\s]+")


def read(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def heading_level(line: str) -> int:
    match = HEADING.match(line)
    return len(match.group(1)) if match else 0


def find_section(lines: list[str], predicate) -> list[str] | None:
    """Return the body of the first heading whose title matches predicate."""
    for index, line in enumerate(lines):
        match = HEADING.match(line)
        if not match or not predicate(match.group(2)):
            continue
        level = len(match.group(1))
        body: list[str] = []
        for candidate in lines[index + 1 :]:
            inner = HEADING.match(candidate)
            if inner and len(inner.group(1)) <= level:
                break
            body.append(candidate)
        return body
    return None


def is_troubleshooting(title: str) -> bool:
    title = re.sub(r"^\d+[.)]\s*", "", title).strip()
    title = EMOJI.sub("", title)
    return title.lower().startswith("troubleshoot")


def split_table_row(line: str) -> list[str]:
    text = line.strip()
    if text.startswith("|"):
        text = text[1:]
    if text.endswith("|"):
        text = text[:-1]
    return [cell.replace("\\|", "|").strip() for cell in re.split(r"(?<!\\)\|", text)]


def table_rows(lines: list[str]) -> list[tuple[str, str]]:
    rows: list[tuple[str, str]] = []
    header_seen = False
    for line in lines:
        if not line.strip().startswith("|"):
            continue
        cells = [cell for cell in split_table_row(line) if cell != ""]
        if not cells:
            continue
        if all(TABLE_SEPARATOR.match(cell) for cell in cells):
            continue
        first = cells[0].strip().lower()
        if first in {"problem", "issue", "symptom", "cause", "error", "question", "scenario"}:
            header_seen = True
            continue
        # A repeated header row from a second table in the same section.
        if header_seen and first in {"problem", "issue", "symptom"}:
            continue
        if len(cells) < 2:
            continue
        problem = cells[0]
        fix = " — ".join(cells[1:])
        rows.append((problem, fix))
    return rows


def bullet_entries(lines: list[str]) -> tuple[list[tuple[str, str]], list[str]]:
    rows: list[tuple[str, str]] = []
    notes: list[str] = []
    in_code = False

    for line in lines:
        text = line.strip()
        if text.startswith("```"):
            in_code = not in_code
            continue
        if in_code or not text or text.startswith("|"):
            continue
        heading = HEADING.match(text)
        if heading:
            title = heading.group(2).strip()
            if title:
                notes.append(f"**{title}**")
            continue
        if SUPPORT.search(text):
            continue
        if text in {"---", "***", "___"}:
            continue

        if text.startswith(("- ", "* ")):
            item = text[2:].strip()
            bold = re.match(r"^\*\*(.+?)\*\*\s*[:—–-]\s*(.+)$", item)
            if bold:
                rows.append((bold.group(1).strip(), bold.group(2).strip()))
                continue
            bold_colon = re.match(r"^\*\*(.+?):\*\*\s*(.+)$", item)
            if bold_colon:
                rows.append((bold_colon.group(1).strip(), bold_colon.group(2).strip()))
                continue
            plain = re.match(r"^(.{1,80}?)\s*[:—–]\s*(.+)$", item)
            if plain:
                rows.append((plain.group(1).strip(), plain.group(2).strip()))
                continue
            notes.append(item)
            continue

        # A short prose paragraph (for example the rsg-cinema debug note).
        if len(text) <= 300:
            notes.append(text)

    return rows, notes


def clean_note(text: str) -> str:
    text = re.sub(r"\[([^\]]+)\]\(#[^)]+\)", r"\1", text)
    text = re.sub(r"\s+", " ", text).strip()
    if not text or SUPPORT.search(text):
        return ""
    return text


def collect_resource(resource_dir: pathlib.Path) -> tuple[list[tuple[str, str]], list[str], list[str]]:
    """Return (rows, notes, source files) for one resource."""
    rows: list[tuple[str, str]] = []
    notes: list[str] = []
    sources: list[str] = []
    seen: set[str] = set()
    seen_files: set[str] = set()
    available = {p.name.lower(): p.name for p in resource_dir.iterdir() if p.is_file()}

    for filename in ("DOCS.md", "README.md", "readme.md"):
        actual_name = available.get(filename.lower())
        if not actual_name:
            continue
        # Windows is case-insensitive: README.md and readme.md are the same file.
        if actual_name.lower() in seen_files:
            continue
        seen_files.add(actual_name.lower())
        path = resource_dir / actual_name
        lines = read(path).splitlines()
        sections: list[list[str]] = []
        for index, line in enumerate(lines):
            match = HEADING.match(line)
            if not match or not is_troubleshooting(match.group(2)):
                continue
            level = len(match.group(1))
            body: list[str] = []
            for candidate in lines[index + 1 :]:
                inner = HEADING.match(candidate)
                if inner and len(inner.group(1)) <= level:
                    break
                body.append(candidate)
            sections.append(body)

        if not sections:
            continue
        sources.append(actual_name)

        for body in sections:
            section_rows = table_rows(body)
            section_notes = bullet_entries(body)[1]
            for problem, fix in section_rows + bullet_entries(body)[0]:
                key = re.sub(r"\s+", " ", problem).strip().lower()
                if not key or key in seen:
                    continue
                seen.add(key)
                rows.append((problem, fix))
            for note in section_notes:
                note = clean_note(note)
                if note and note.lower() not in {n.lower() for n in notes}:
                    notes.append(note)

    # If a resource has identical wording in two source files, keep one.
    return rows, notes, sources


def md_cell(text: str) -> str:
    text = re.sub(r"\[([^\]]+)\]\(#[^)]+\)", r"\1", text)
    text = re.sub(r"\s+", " ", text).strip()
    text = text.replace("|", "\\|")
    return text or "—"


def demote_headings(lines: list[str]) -> list[str]:
    out: list[str] = []
    for line in lines:
        match = HEADING.match(line)
        if match:
            level = min(6, len(match.group(1)) + 1)
            out.append("#" * level + " " + match.group(2))
        else:
            out.append(line)
    return out


def trim_blank(lines: list[str]) -> list[str]:
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()
    return lines


def env_body(title_start: str) -> str | None:
    if not ENV.is_file():
        return None
    lines = read(ENV).splitlines()
    body = find_section(lines, lambda title: title.lower().startswith(title_start.lower()))
    if body is None:
        return None
    body = trim_blank(demote_headings(body))
    return "\n".join(body).strip()


def resource_troubleshooting() -> tuple[str, int, int]:
    resources: list[str] = []
    total_rows = 0
    total_notes = 0
    blocks: list[str] = []

    if not SOURCE.is_dir():
        return (
            "_No `source/` mirror found. Run `tools/refresh.sh` / `tools/refresh.ps1` first._",
            0,
            0,
        )

    for resource_dir in sorted(SOURCE.iterdir(), key=lambda p: p.name.lower()):
        if not resource_dir.is_dir() or resource_dir.name.startswith("."):
            continue
        rows, notes, sources = collect_resource(resource_dir)
        if not rows and not notes:
            continue

        resources.append(resource_dir.name)
        total_rows += len(rows)
        total_notes += len(notes)

        links = ", ".join(f"[{name}](source/{resource_dir.name}/{name})" for name in sources)
        api_page = ROOT / "framework" / "resources" / f"{resource_dir.name}.md"
        if api_page.is_file():
            links += f", [API reference](framework/resources/{resource_dir.name}.md)"
        block = [f"### {resource_dir.name}", "", f"Sources: {links}", ""]
        if rows:
            block.extend(["| Problem | Cause / fix |", "|---|---|"])
            for problem, fix in rows:
                block.append(f"| {md_cell(problem)} | {md_cell(fix)} |")
            block.append("")
        if notes:
            block.append("**Notes**")
            block.append("")
            for note in notes:
                block.append(f"- {note}")
            block.append("")

        blocks.append("\n".join(trim_blank(block)))

    if not blocks:
        return (
            "_No troubleshooting sections were found in `source/*/DOCS.md` or `source/*/README.md`._",
            0,
            0,
        )

    intro = (
        "Harvested from the `Troubleshooting` sections of the mirrored resource docs. "
        "The links open the read-only mirror in `source/`; apply fixes in the live resource folder on the server.\n\n"
        "Use this section after the [Symptom quick reference](#symptom-quick-reference) has narrowed the problem to a resource. "
        "If a resource is missing here, it has no troubleshooting section in its `DOCS.md` or `README.md`."
    )
    return "\n\n".join([intro, *blocks]), len(resources), total_rows + total_notes


def refresh_stamp() -> str:
    stamp_file = SOURCE / "LAST_REFRESH.txt"
    if stamp_file.is_file():
        stamp = stamp_file.read_text(encoding="utf-8", errors="replace").strip()
        if stamp:
            return stamp
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")


def replace_region(text: str, name: str, body: str) -> str:
    begin = f"<!-- BEGIN AUTO:{name} -->"
    end = f"<!-- END AUTO:{name} -->"
    try:
        start = text.index(begin) + len(begin)
        stop = text.index(end, start)
    except ValueError as exc:
        raise SystemExit(
            f"DOCS.md is missing the {begin} / {end} markers. "
            "Restore them or delete DOCS.md and re-create it from the repository."
        ) from exc
    return text[:start] + "\n" + body.strip() + "\n" + text[stop:]


def main() -> None:
    if not DOCS.is_file():
        raise SystemExit(f"{DOCS} does not exist. Restore it from the repository first.")

    text = read(DOCS)
    source_resources = [p for p in SOURCE.iterdir() if p.is_dir()] if SOURCE.is_dir() else []
    api_pages = list((ROOT / "framework" / "resources").glob("rsg-*.md"))
    resource_section, resource_count, entry_count = resource_troubleshooting()

    environment_parts: list[str] = []
    for heading in (
        "Core stack",
        "Installed systems (use these)",
        "Removed or not installed (never depend on these)",
        "Item names on this server",
    ):
        body = env_body(heading)
        if body:
            environment_parts.append(f"### {heading}\n\n{body}")
    if environment_parts:
        environment = (
            "_Copied from [`server/environment.md`](server/environment.md), which is the source of truth. "
            "If the server changes, edit that file and refresh._\n\n" + "\n\n".join(environment_parts)
        )
    else:
        environment = (
            "_`server/environment.md` was not found or has no recognised sections. "
            "Check that the file exists and keeps its `Core stack`, `Installed systems`, "
            "`Removed or not installed` and `Item names` headings._"
        )

    stats = (
        f"_Last refreshed: **{refresh_stamp()}** · "
        f"**{len(source_resources)}** resources in `source/` · "
        f"**{len(api_pages)}** generated API pages · "
        f"**{resource_count}** resources with troubleshooting notes "
        f"({entry_count} entries)._\n\n"
        "Auto-generated by `tools/build_support_docs.py` during `tools/refresh.sh` / `tools/refresh.ps1`. "
        "Edit the hand-written sections around the generated markers; generated regions are replaced on every refresh."
    )

    new_text = text
    new_text = replace_region(new_text, "ENVIRONMENT", environment)
    new_text = replace_region(new_text, "RESOURCE_TROUBLESHOOTING", resource_section)

    # Keep the top-of-file status readable without adding another marker.
    stat_begin = "<!-- BEGIN AUTO:STATS -->"
    stat_end = "<!-- END AUTO:STATS -->"
    if stat_begin in new_text and stat_end in new_text:
        new_text = replace_region(new_text, "STATS", stats)

    if new_text != text:
        DOCS.write_text(new_text, encoding="utf-8", newline="\n")
        print(f"DOCS.md updated ({resource_count} resources, {entry_count} troubleshooting entries)")
    else:
        print("DOCS.md is already up to date")


if __name__ == "__main__":
    main()
