# Commit Style Guide

Use clear GitHub Desktop commit titles so the release workflow can understand what changed.

This repository uses Conventional Commit-style titles for automated semantic versioning.

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
docs: update release automation guide
chore: clean up unused assets
```

## Supported Types

Use these prefixes in commit titles:

| Type | Use when | Release effect |
| --- | --- | --- |
| `feat` | Adding a player-facing feature | Minor release |
| `fix` | Fixing a bug | Patch release |
| `docs` | Changing documentation | No release by default |
| `refactor` | Improving code without changing behavior | No release by default |
| `chore` | Maintenance that does not fit another type | No release by default |
| `build` | Changing build or tooling setup | No release by default |
| `test` | Adding or updating tests | No release by default |

Unknown prefixes are grouped under Other Changes but do not create a release by themselves.

## Version Meaning

The release workflow uses commit titles to choose releases:

- `feat:` creates a minor version bump.
- `fix:` creates a patch version bump.
- `!` creates a major version bump.
- `BREAKING CHANGE:` in the description creates a major version bump.
- Documentation, chores, refactors, build changes, tests, and unknown commits do not create a release by themselves after the first tag exists.

If there are no previous version tags, the first release starts at `v0.1.0`.

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

## Writing Good Titles

Good titles are short, specific, and action-oriented:

```text
feat(ui): add garage sorting controls
fix(spawn): reset vehicle after failed spawn
docs: clarify local setup steps
test: cover parts currency setup
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
Adds sorting by price and unlock status in the garage vehicle list.

Tested by opening the garage with locked, unlocked, cheap, and expensive vehicles.
```

## Manual Release Workflow

The release workflow runs automatically on pushes to `main`.

To manually trigger it:

1. Open the repository on GitHub.
2. Go to Actions.
3. Select Release.
4. Choose Run workflow.
5. Run it against `main`.

## Avoiding Accidental Releases

Before committing to `main`, check the title:

- Use `feat:` only when a minor release is intended.
- Use `fix:` only when a patch release is intended.
- Avoid `!` unless a major release is intended.
- Avoid `BREAKING CHANGE:` unless a major release is intended.
- Use `docs:`, `chore:`, `refactor:`, `build:`, or `test:` for changes that should not release by themselves.

## Quick Checklist

Before committing:

- The title starts with a supported type.
- The title says what changed.
- The description explains anything risky or non-obvious.
- Breaking changes are marked with `!` or `BREAKING CHANGE:`.
