# Commit Style Guide

Use clear GitHub Desktop commit titles so the release-notes preview can organize what changed.

Commit prefixes help group release-note text. They do not create tags, publish GitHub releases, or bump versions.

## Commit Title Format

Use this format:

```text
type: short summary
```

Or, when a scope helps:

```text
type(scope): short summary
```

Examples:

```text
feat: add vehicle showroom filtering
fix: prevent duplicate purchase prompts
docs: update release notes preview guide
chore: tune prototype parts income
```

## Supported Types

Use these prefixes in commit titles:

| Type | Use when | Release-note section | Automatic release effect |
| --- | --- | --- | --- |
| `feat` | Adding a player-facing feature | New Features | None |
| `fix` | Fixing a bug | Fixes | None |
| `ci` | Changing workflow or CI setup | CI / Automation | None |
| `docs` | Changing documentation | Documentation | None |
| `refactor` | Improving code without changing behavior | Refactors | None |
| `chore` | Maintenance, balance, config, or prototype tuning | Chores | None |
| `build` | Changing build or tooling setup | Build | None |
| `test` | Adding or updating tests | Tests | None |

Unknown prefixes are grouped under Other Changes and still do not create a release.

## Version Meaning

Manual tags and manually created GitHub releases are the source of truth.

The release-notes preview reads commits since the latest reachable tag and writes formatted notes for review before a maintainer creates a release manually.

Planned long-term path:

- `v0.0.0-alpha.N`: early prototype iterations, if manually used.
- `v0.0.0-beta.N`: later playable beta iterations, if manually used.
- `v1.0.0`: real release after beta.

The workflow does not create these tags automatically.

## Breaking Changes

Use `!` when the change breaks existing behavior, data, setup, or expectations:

```text
feat!: replace vehicle save data format
fix(data)!: remove legacy inventory fallback
```

In the GitHub Desktop description field, explain the break:

```text
BREAKING CHANGE: Existing saved vehicle inventory data must be migrated.
```

Breaking changes are marked with `[BREAKING]` in the release-notes preview, but they still do not create tags, releases, or version bumps.

## Writing Good Titles

Good titles are short, specific, and action-oriented:

```text
feat(ui): add garage sorting controls
fix(spawn): reset vehicle after failed spawn
docs: clarify local setup steps
chore: tune scrapyard income timing
```

Avoid vague titles:

```text
update
fix
misc changes
wip
final
```

## Writing Descriptions

Use the GitHub Desktop description field when the title needs context.

Helpful description details:

- Why the change was made.
- Important implementation notes.
- Testing performed.
- Known follow-up work.
- Breaking change details.

Example:

```text
Reduces the prototype Motor Pool upgrade cost for faster local testing.

Tested by waiting for Parts income and buying the upgrade once.
```

## Manual Release Notes Preview

To run the preview locally:

```powershell
python scripts/generate_release.py --notes-file release_notes.md
```

To run the GitHub Actions preview:

1. Open the repository on GitHub.
2. Go to Actions.
3. Select Release Notes Preview.
4. Choose Run workflow.
5. Run it against the branch you want to preview.

The local script writes `release_notes.md`. The GitHub Actions workflow prints the preview in logs, adds it to the job summary, and uploads it as the `release-notes-preview` artifact.

## Quick Checklist

Before committing:

- The title starts with a supported type when one fits.
- The title says what changed.
- The description explains anything risky or non-obvious.
- Prototype tuning usually uses `chore:`.
- Release tags and GitHub releases are created manually only when ready.
