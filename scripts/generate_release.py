#!/usr/bin/env python3
"""Generate manual release-notes previews from Conventional Commit-style commits."""

from __future__ import annotations

import argparse
import os
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path


COMMIT_RE = re.compile(r"^(?P<type>[a-z]+)(?:\([^)]+\))?(?P<breaking>!)?:\s*(?P<summary>.+)$")

SECTION_TITLES = {
    "feat": "New Features",
    "fix": "Fixes",
    "docs": "Documentation",
    "ci": "CI / Automation",
    "refactor": "Refactors",
    "chore": "Chores",
    "build": "Build",
    "test": "Tests",
}

SECTION_ORDER = [
    "New Features",
    "Fixes",
    "Documentation",
    "CI / Automation",
    "Refactors",
    "Chores",
    "Build",
    "Tests",
    "Other Changes",
]

DEFAULT_GITHUB_REPOSITORY = "venolab-Games/roblox-vehicle-tycoon"


@dataclass
class Commit:
    sha: str
    subject: str
    body: str


def run_git(args: list[str]) -> str:
    result = subprocess.run(
        ["git", *args],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return result.stdout.strip()


def get_latest_tag() -> str | None:
    try:
        return run_git(["describe", "--tags", "--abbrev=0"])
    except subprocess.CalledProcessError:
        return None


def get_commits(compare_tag: str | None) -> list[Commit]:
    revision_range = f"{compare_tag}..HEAD" if compare_tag else "HEAD"
    output = run_git(["log", revision_range, "--pretty=format:%H%x1f%s%x1f%b%x1e"])

    commits: list[Commit] = []
    for raw_entry in output.split("\x1e"):
        entry = raw_entry.strip()
        if not entry:
            continue

        parts = entry.split("\x1f", 2)
        if len(parts) != 3:
            continue

        commits.append(Commit(sha=parts[0], subject=parts[1].strip(), body=parts[2].strip()))

    return commits


def is_breaking_change(commit: Commit, match: re.Match[str] | None) -> bool:
    if match and match.group("breaking"):
        return True

    return "BREAKING CHANGE:" in commit.body


def should_create_release(commits: list[Commit]) -> bool:
    return False


def format_summary(subject: str) -> str:
    match = COMMIT_RE.match(subject)
    if not match:
        return subject[:1].upper() + subject[1:]

    summary = match.group("summary").strip()
    return summary[:1].upper() + summary[1:]


def section_for_commit(subject: str) -> str:
    match = COMMIT_RE.match(subject)
    if not match:
        return "Other Changes"

    return SECTION_TITLES.get(match.group("type"), "Other Changes")


def get_commit_url(short_sha: str) -> str:
    repository = os.environ.get("GITHUB_REPOSITORY", DEFAULT_GITHUB_REPOSITORY)
    return f"https://github.com/{repository}/commit/{short_sha}"


def format_commit_link(sha: str) -> str:
    short_sha = sha[:7]
    return f"[{short_sha}]({get_commit_url(short_sha)})"


def build_release_notes(tag: str, commits: list[Commit], compare_tag: str | None) -> str:
    sections = {section: [] for section in SECTION_ORDER}

    for commit in commits:
        match = COMMIT_RE.match(commit.subject)
        label = format_summary(commit.subject)
        if is_breaking_change(commit, match):
            label = f"[BREAKING] {label}"

        sections[section_for_commit(commit.subject)].append(f"- {label} ({format_commit_link(commit.sha)})")

    compared_from = compare_tag if compare_tag else "the beginning of the repository"
    lines = [
        "Release notes preview.",
        "No tag, GitHub release, or version bump was created.",
        "",
        f"Changes since {compared_from}.",
        "",
    ]

    if not commits:
        lines.append("No commits found for this preview.")
        return "\n".join(lines).rstrip() + "\n"

    for section in SECTION_ORDER:
        items = sections[section]
        if not items:
            continue

        lines.append(f"## {section}")
        lines.append("")
        lines.extend(items)
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def write_github_output(path: Path, values: dict[str, str]) -> None:
    with path.open("a", encoding="utf-8") as output:
        for key, value in values.items():
            output.write(f"{key}={value}\n")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate a manual release-notes preview.")
    parser.add_argument("--notes-file", default="release_notes.md")
    parser.add_argument("--github-output", default=None)
    args = parser.parse_args()

    compare_tag = get_latest_tag()
    commits = get_commits(compare_tag)
    release_needed = should_create_release(commits)
    notes_path = Path(args.notes_file)

    notes_path.write_text(build_release_notes("", commits, compare_tag), encoding="utf-8")

    outputs = {
        "release_needed": "true" if release_needed else "false",
        "tag": "",
        "version_bump": "none",
        "latest_tag": compare_tag or "",
        "compare_tag": compare_tag or "",
        "notes_file": str(notes_path),
    }

    if args.github_output:
        write_github_output(Path(args.github_output), outputs)

    for key, value in outputs.items():
        print(f"{key}={value}")


if __name__ == "__main__":
    main()
