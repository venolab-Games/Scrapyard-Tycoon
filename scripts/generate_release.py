#!/usr/bin/env python3
"""Generate semantic release metadata from Conventional Commit-style commits."""

from __future__ import annotations

import argparse
import os
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path


VERSION_TAG_RE = re.compile(r"^v(\d+)\.(\d+)\.(\d+)$")
ALPHA_TAG_RE = re.compile(r"^v0\.0\.0-alpha\.(\d+)$")
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

BUMP_LEVELS = {
    "none": 0,
    "patch": 1,
    "minor": 2,
    "major": 3,
}

DEFAULT_GITHUB_REPOSITORY = "venolab-Games/roblox-vehicle-tycoon"
ALPHA_TAG_PREFIX = "v0.0.0-alpha."


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


def parse_alpha_tag(tag: str) -> int | None:
    match = ALPHA_TAG_RE.match(tag)
    if not match:
        return None

    return int(match.group(1))


def get_tags() -> list[str]:
    return run_git(["tag", "--list", "v*"]).splitlines()


def get_latest_version_tag() -> str | None:
    tags = get_tags()
    version_tags = [(parse_version_tag(tag), tag) for tag in tags]
    valid_tags = [(version, tag) for version, tag in version_tags if version is not None]

    if not valid_tags:
        return None

    valid_tags.sort(key=lambda item: item[0])
    return valid_tags[-1][1]


def get_latest_alpha_tag() -> str | None:
    tags = get_tags()
    alpha_tags = [(parse_alpha_tag(tag), tag) for tag in tags]
    valid_tags = [(version, tag) for version, tag in alpha_tags if version is not None]

    if not valid_tags:
        return None

    valid_tags.sort(key=lambda item: item[0])
    return valid_tags[-1][1]


def get_compare_tag(latest_alpha_tag: str | None) -> str | None:
    if latest_alpha_tag:
        return latest_alpha_tag

    return get_latest_version_tag()


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


def is_material_release_ci(commit: Commit, match: re.Match[str] | None) -> bool:
    if not match or match.group("type") != "ci":
        return False

    text = f"{commit.subject}\n{commit.body}".lower()
    release_terms = ["release", "version", "tag", "prerelease", "pre-release"]
    return any(term in text for term in release_terms)


def should_commit_create_alpha_release(commit: Commit) -> bool:
    match = COMMIT_RE.match(commit.subject)
    if is_breaking_change(commit, match):
        return True

    if not match:
        return False

    commit_type = match.group("type")
    return commit_type in {"feat", "fix"} or is_material_release_ci(commit, match)


def should_create_alpha_release(commits: list[Commit], latest_alpha_tag: str | None) -> bool:
    if latest_alpha_tag is None:
        return True

    return any(should_commit_create_alpha_release(commit) for commit in commits)


def get_highest_bump(commits: list[Commit]) -> str:
    highest = "none"

    for commit in commits:
        bump = get_bump_for_commit(commit)
        if BUMP_LEVELS[bump] > BUMP_LEVELS[highest]:
            highest = bump

    return highest


def next_alpha_tag(latest_alpha_tag: str | None) -> str:
    if latest_alpha_tag is None:
        return f"{ALPHA_TAG_PREFIX}1"

    alpha_number = parse_alpha_tag(latest_alpha_tag)
    if alpha_number is None:
        raise ValueError(f"Invalid alpha tag: {latest_alpha_tag}")

    return f"{ALPHA_TAG_PREFIX}{alpha_number + 1}"


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

    latest_alpha_tag = get_latest_alpha_tag()
    compare_tag = get_compare_tag(latest_alpha_tag)
    commits = get_commits(compare_tag)
    bump = get_highest_bump(commits)
    release_needed = should_create_alpha_release(commits, latest_alpha_tag)
    tag = next_alpha_tag(latest_alpha_tag) if release_needed else latest_alpha_tag or ""
    notes_path = Path(args.notes_file)

    if release_needed:
        notes_path.write_text(build_release_notes(tag, commits, compare_tag), encoding="utf-8")
    else:
        notes_path.write_text("No release needed.\n", encoding="utf-8")

    outputs = {
        "release_needed": "true" if release_needed else "false",
        "tag": tag,
        "bump": bump,
        "latest_tag": latest_alpha_tag or "",
        "compare_tag": compare_tag or "",
        "notes_file": str(notes_path),
    }

    if args.github_output:
        write_github_output(Path(args.github_output), outputs)

    for key, value in outputs.items():
        print(f"{key}={value}")


if __name__ == "__main__":
    main()
