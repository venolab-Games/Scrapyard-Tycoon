# Commit Style Guide

Use clear GitHub Desktop commit titles so release-note previews can group what changed.

This repository does not create alpha prerelease tags from Conventional Commit-style titles.

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

| Type | Use when | Release effect |
| --- | --- | --- |
| `feat` | Adding a player-facing feature | Does not create a release |
| `fix` | Fixing a bug | Does not create a release |
| `ci` | Changing release/version automation | Does not create a release |
| `docs` | Changing documentation | Does not create a release |
| `refactor` | Improving code without changing behavior | Does not create a release |
| `chore` | Maintenance, balance, config, or prototype tuning | Does not create a release |
| `build` | Changing build or tooling setup | Does not create a release |
| `test` | Adding or updating tests | Does not create a release |

Unknown prefixes are grouped under Other Changes and do not create a release.

## Version Meaning

During the prototype alpha phase, intentional manual releases may use this sequence:

```text
v0.0.0-alpha.1
v0.0.0-alpha.2
v0.0.0-alpha.3
```

Existing normal tags like `v0.1.0` and `v0.2.0` can remain as early automation test releases, but they do not control future alpha numbering.

Release behavior:

- Commit titles do not create alpha prereleases.
- `feat:`, `fix:`, `ci:`, `docs:`, `chore:`, `refactor:`, `build:`, `test:`, and unknown commits are allowed without publishing a release.
- Balance/config/prototype tuning can still use `chore:`.

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

During alpha, breaking-change labels are preserved in release-note previews but do not create a release.

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

The release workflow is a manual release-note preview.

To manually trigger it:

1. Open the repository on GitHub.
2. Go to Actions.
3. Select Release.
4. Choose Run workflow.
5. Run it against `main`.

## Manual Release Control

Commit names never automatically create or publish releases. Conventional commit labels are still encouraged because they keep generated release-note previews organized.

## Quick Checklist

Before committing:

- The title starts with a supported type.
- The title says what changed.
- The description explains anything risky or non-obvious.
- Prototype tuning uses `chore:` unless a release is intentional.
