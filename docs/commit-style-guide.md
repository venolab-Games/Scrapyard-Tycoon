# Commit Style Guide

Use clear GitHub Desktop commit titles so future release automation can understand what changed.

This guide uses Conventional Commit-style titles.

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
docs: add release automation plan
chore: clean up unused assets
```

## Common Types

Use these prefixes in commit titles:

| Type | Use when |
| --- | --- |
| `feat` | Adding a player-facing feature |
| `fix` | Fixing a bug |
| `perf` | Improving performance |
| `docs` | Changing documentation |
| `test` | Adding or updating tests |
| `refactor` | Improving code without changing behavior |
| `style` | Formatting or style-only changes |
| `build` | Changing build or tooling setup |
| `ci` | Changing continuous integration setup |
| `chore` | Maintenance that does not fit another type |
| `revert` | Reverting an earlier change |

## Version Meaning

Future automation may use commit titles to choose releases:

- `feat:` means a minor version bump.
- `fix:` means a patch version bump.
- `perf:` means a patch version bump.
- `!` means a major version bump.
- `BREAKING CHANGE:` in the description means a major version bump.

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
perf: cache dealership vehicle list
docs: clarify local setup steps
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

## Quick Checklist

Before committing:

- The title starts with a supported type.
- The title says what changed.
- The description explains anything risky or non-obvious.
- Breaking changes are marked with `!` or `BREAKING CHANGE:`.
