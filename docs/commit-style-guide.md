# Commit Style Guide

Use clear GitHub Desktop commit titles so the release workflow can understand what changed.

This repository currently creates alpha prerelease tags from Conventional Commit-style titles.

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
chore: tune prototype parts income
```

## Supported Types

Use these prefixes in commit titles:

| Type | Use when | Alpha release effect |
| --- | --- | --- |
| `feat` | Adding a player-facing feature | Creates an alpha release |
| `fix` | Fixing a bug | Creates an alpha release |
| `ci` | Changing release/version automation | Creates an alpha release only for material release automation changes |
| `docs` | Changing documentation | No release by default |
| `refactor` | Improving code without changing behavior | No release by default |
| `chore` | Maintenance, balance, config, or prototype tuning | No release by default |
| `build` | Changing build or tooling setup | No release by default |
| `test` | Adding or updating tests | No release by default |

Unknown prefixes are grouped under Other Changes but do not create a release by themselves.

## Version Meaning

During the prototype alpha phase, automated releases use this sequence:

```text
v0.0.0-alpha.1
v0.0.0-alpha.2
v0.0.0-alpha.3
```

Existing normal tags like `v0.1.0` and `v0.2.0` can remain as early automation test releases, but they do not control future alpha numbering.

Release behavior:

- `feat:` creates the next alpha prerelease.
- `fix:` creates the next alpha prerelease.
- Material release automation `ci:` changes can create the next alpha prerelease.
- `docs:`, `chore:`, `refactor:`, `build:`, `test:`, and unknown commits do not create a release by themselves after an alpha tag exists.
- Balance/config/prototype tuning should usually be `chore:`.

Planned long-term path:

- `v0.0.0-alpha.N`: early prototype iterations.
- `v0.0.0-beta.N`: later playable beta iterations.
- `v1.0.0`: real release after beta.

Beta and `v1.0.0` promotion are not implemented yet.

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

During alpha, breaking changes still create the next alpha prerelease rather than a normal major version.

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

- Use `feat:` only when a new alpha release is intended.
- Use `fix:` only when a new alpha release is intended.
- Use `chore:` for prototype balance/config tuning.
- Use `docs:`, `chore:`, `refactor:`, `build:`, or `test:` for changes that should not release by themselves.
- Use `ci:` carefully for release automation work.

## Quick Checklist

Before committing:

- The title starts with a supported type.
- The title says what changed.
- The description explains anything risky or non-obvious.
- Prototype tuning uses `chore:` unless a release is intentional.
