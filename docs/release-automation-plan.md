# Release Automation

This repository has an automated GitHub release workflow for early prototype releases.

The active files are:

- `.github/workflows/release.yml`
- `scripts/generate_release.py`

The project is currently in the alpha phase, so future automated releases use prerelease tags like `v0.0.0-alpha.1`, `v0.0.0-alpha.2`, and `v0.0.0-alpha.3`.

Existing normal tags such as `v0.1.0` and `v0.2.0` can remain as early automation test releases. They do not control the next alpha number.

## Purpose

The release automation turns commit history into readable GitHub release notes and alpha prerelease tags.

It is designed to:

- Read commits since the latest alpha tag.
- Fall back to the latest normal version tag only when no alpha tag exists yet.
- Create the next `v0.0.0-alpha.N` tag.
- Mark GitHub releases from alpha tags as prereleases.
- Group release notes into readable sections.
- Link short commit hashes to exact GitHub commit pages.

It does not update `CHANGELOG.md` or README version/status sections yet.

## Version Path

Planned release path:

- `v0.0.0-alpha.N`: early prototype iterations.
- `v0.0.0-beta.N`: later playable beta iterations.
- `v1.0.0`: real release after beta.

Only alpha prerelease automation is implemented right now.

## When It Runs

The workflow runs when:

- A commit is pushed to the `main` branch.
- A maintainer manually starts it with `workflow_dispatch`.

The workflow does not run for pull requests or other branches.

## Commit Title Format

Use this format:

```text
type: short summary
```

Or, when a scope helps:

```text
type(scope): short summary
```

Breaking changes can be marked with `!`:

```text
feat!: replace vehicle save format
fix(data)!: remove legacy inventory fallback
```

Breaking changes can also be marked in the commit description:

```text
BREAKING CHANGE: Existing saved vehicle inventory data must be migrated.
```

## Supported Prefixes

| Prefix | Release-note section | Alpha release behavior |
| --- | --- | --- |
| `feat` | New Features | Creates an alpha release |
| `fix` | Fixes | Creates an alpha release |
| `ci` | CI / Automation | Creates an alpha release only for material release automation changes |
| `docs` | Documentation | No release by itself after an alpha tag exists |
| `refactor` | Refactors | No release by itself after an alpha tag exists |
| `chore` | Chores | No release by itself after an alpha tag exists |
| `build` | Build | No release by itself after an alpha tag exists |
| `test` | Tests | No release by itself after an alpha tag exists |
| Unknown prefixes | Other Changes | No release by itself after an alpha tag exists |

Balance, config, and prototype tuning should usually use `chore:` so those changes do not create releases by themselves.

## Alpha Version Rules

The automation uses alpha prerelease numbering during the prototype phase.

- If no alpha tags exist, the next alpha release is `v0.0.0-alpha.1`.
- If `v0.0.0-alpha.1` exists, the next alpha release is `v0.0.0-alpha.2`.
- Existing normal tags such as `v0.1.0`, `v0.2.0`, or `v0.3.0` do not make the next alpha release become `v0.3.0`.
- `feat:` creates a new alpha release.
- `fix:` creates a new alpha release.
- `ci:` creates a release only when the title or description indicates material release/version/tag automation work.
- Only `docs:`, `chore:`, `refactor:`, `build:`, `test:`, or unknown commits do not create a new release when an alpha tag already exists.

## Release Note Sections

Generated GitHub release notes can include:

- New Features
- Fixes
- Documentation
- CI / Automation
- Refactors
- Chores
- Build
- Tests
- Other Changes

Breaking changes are marked inside their section with `[BREAKING]`.

Example:

```markdown
Changes since v0.0.0-alpha.1.

## New Features

- Add garage sorting controls ([abc1234](https://github.com/venolab-Games/roblox-vehicle-tycoon/commit/abc1234))

## Fixes

- Prevent duplicate purchase prompt ([def5678](https://github.com/venolab-Games/roblox-vehicle-tycoon/commit/def5678))
```

## Manual Trigger

To manually run the release workflow:

1. Open the repository on GitHub.
2. Go to the Actions tab.
3. Select the Release workflow.
4. Choose Run workflow.
5. Select the `main` branch.
6. Start the run.

Manual runs use the same rules as pushes to `main`.

## Avoiding Accidental Releases

To avoid unintended alpha releases:

- Use `docs:`, `chore:`, `refactor:`, `build:`, or `test:` for changes that should not release by themselves.
- Use `chore:` for prototype balance/config tuning unless a release is intentionally needed.
- Do not use `feat:` unless the change should create a new alpha release.
- Do not use `fix:` unless the change should create a new alpha release.
- Use `ci:` for release automation changes, but only material release automation changes should trigger a release.
- Keep release-triggering commits off `main` until they are ready.

The workflow is intentionally limited to `main` and manual runs.

## Current File Structure

```text
.github/
  workflows/
    release.yml
scripts/
  generate_release.py
docs/
  commit-style-guide.md
  release-automation-plan.md
```

## Future Options

These are not enabled yet:

- Updating `CHANGELOG.md`.
- Updating README version or status sections.
- Adding beta prerelease automation.
- Promoting to `v1.0.0`.
- Supporting release branches.
- Requiring manual approval before tag and release creation.

Review the workflow before adding any of these behaviors.
