#!/usr/bin/env python3
"""Generate semantic release metadata from Conventional Commit-style commits."""

from __future__ import annotations

import argparse
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path


VERSION_TAG_RE = re.compile(r"^v(\d+)\.(\d+)\.(\d+)$")
COMMIT_RE = re.compile(r"^(?P<type>[a-z]+)(?:\([^)]+\))?(?P<breaking>!)?:\s*(?P<summary>.+)$")

SECTION_TITLES = {
    "feat": "New Features",
    "fix": "Bug Fixes",
    "docs": "Documentation",
    "refactor": "Refactors",
    "chore": "Chores",
    "build": "Build",
    "test": "Tests",
}

SECTION_ORDER = [
    "New Features",
    "Bug Fixes",
    "Documentation",
    "Refactors",
    "Chores",
    "Build",
    "Tests",
    "Other Changes",
]

BUMP_LEVELS = {
    "none": 0,
    "patch": 1,
    "minor": 2,
    "major": 3,
}


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


def parse_version_tag(tag: str) -> tuple[int, int, int] | None:
    match = VERSION_TAG_RE.match(tag)
    if not match:
        return None

    return tuple(int(part) for part in match.groups())


def get_latest_version_tag() -> str | None:
    tags = run_git(["tag", "--list", "v*"]).splitlines()
    version_tags = [(parse_version_tag(tag), tag) for tag in tags]
    valid_tags = [(version, tag) for version, tag in version_tags if version is not None]

    if not valid_tags:
        return None

    valid_tags.sort(key=lambda item: item[0])
    return valid_tags[-1][1]


def get_commits(latest_tag: str | None) -> list[Commit]:
    revision_range = f"{latest_tag}..HEAD" if latest_tag else "HEAD"
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


def get_bump_for_commit(commit: Commit) -> str:
    match = COMMIT_RE.match(commit.subject)

    if is_breaking_change(commit, match):
        return "major"

    if not match:
        return "none"

    commit_type = match.group("type")
    if commit_type == "feat":
        return "minor"
    if commit_type == "fix":
        return "patch"

    return "none"


def get_highest_bump(commits: list[Commit]) -> str:
    highest = "none"

    for commit in commits:
        bump = get_bump_for_commit(commit)
        if BUMP_LEVELS[bump] > BUMP_LEVELS[highest]:
            highest = bump

    return highest


def next_version(latest_tag: str | None, bump: str) -> str:
    if latest_tag is None:
        return "v0.1.0"

    version = parse_version_tag(latest_tag)
    if version is None:
        raise ValueError(f"Invalid version tag: {latest_tag}")

    major, minor, patch = version

    if bump == "major":
        major += 1
        minor = 0
        patch = 0
    elif bump == "minor":
        minor += 1
        patch = 0
    elif bump == "patch":
        patch += 1

    return f"v{major}.{minor}.{patch}"


def format_summary(subject: str) -> str:
    match = COMMIT_RE.match(subject)
    if not match:
        return subject

    summary = match.group("summary").strip()
    return summary[:1].upper() + summary[1:]


def section_for_commit(subject: str) -> str:
    match = COMMIT_RE.match(subject)
    if not match:
        return "Other Changes"

    return SECTION_TITLES.get(match.group("type"), "Other Changes")


def build_release_notes(tag: str, commits: list[Commit], latest_tag: str | None) -> str:
    sections = {section: [] for section in SECTION_ORDER}

    for commit in commits:
        match = COMMIT_RE.match(commit.subject)
        label = format_summary(commit.subject)
        if is_breaking_change(commit, match):
            label = f"[BREAKING] {label}"

        sections[section_for_commit(commit.subject)].append(f"- {label} ({commit.sha[:7]})")

    compared_from = latest_tag if latest_tag else "the beginning of the repository"
    lines = [
        f"# {tag}",
        "",
        f"Changes since {compared_from}.",
        "",
    ]

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
    parser = argparse.ArgumentParser(description="Generate release metadata.")
    parser.add_argument("--notes-file", default="release_notes.md")
    parser.add_argument("--github-output", default=None)
    args = parser.parse_args()

    latest_tag = get_latest_version_tag()
    commits = get_commits(latest_tag)
    bump = get_highest_bump(commits)
    release_needed = latest_tag is None or bump != "none"
    tag = next_version(latest_tag, bump) if release_needed else latest_tag or ""
    notes_path = Path(args.notes_file)

    if release_needed:
        notes_path.write_text(build_release_notes(tag, commits, latest_tag), encoding="utf-8")
    else:
        notes_path.write_text("No release needed.\n", encoding="utf-8")

    outputs = {
        "release_needed": "true" if release_needed else "false",
        "tag": tag,
        "bump": bump,
        "latest_tag": latest_tag or "",
        "notes_file": str(notes_path),
    }

    if args.github_output:
        write_github_output(Path(args.github_output), outputs)

    for key, value in outputs.items():
        print(f"{key}={value}")


if __name__ == "__main__":
    main()
