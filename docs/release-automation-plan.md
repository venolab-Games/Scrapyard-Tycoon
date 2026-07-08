# Release Automation

This repository has a manual GitHub release workflow for early prototype release-note previews.

The active files are:

- `.github/workflows/release.yml`
- `scripts/generate_release.py`

The project is currently in the alpha phase, so future intentional releases may use prerelease tags like `v0.0.0-alpha.1`, `v0.0.0-alpha.2`, and `v0.0.0-alpha.3`.

Existing normal tags such as `v0.1.0` and `v0.2.0` can remain as early automation test releases. They do not control the next alpha number.

## Purpose

The release workflow turns commit history into readable GitHub release-note previews.

It is designed to:

- Read commits since the latest alpha tag.
- Fall back to the latest normal version tag only when no alpha tag exists yet.
- Group release notes into readable sections.
- Link short commit hashes to exact GitHub commit pages.
- Avoid creating tags or publishing GitHub releases automatically.

It does not update `CHANGELOG.md` or README version/status sections yet.

## Version Path

Planned release path:

- `v0.0.0-alpha.N`: early prototype iterations.
- `v0.0.0-beta.N`: later playable beta iterations.
- `v1.0.0`: real release after beta.

Only release-note preview generation is implemented right now.

## When It Runs

The workflow runs only when a maintainer manually starts it with `workflow_dispatch`.

The workflow does not run automatically for pushes, pull requests, or commit titles.

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

| Prefix | Release-note section | Release behavior |
| --- | --- | --- |
| `feat` | New Features | Does not create a release |
| `fix` | Fixes | Does not create a release |
| `ci` | CI / Automation | Does not create a release |
| `docs` | Documentation | Does not create a release |
| `refactor` | Refactors | Does not create a release |
| `chore` | Chores | Does not create a release |
| `build` | Build | Does not create a release |
| `test` | Tests | Does not create a release |
| Unknown prefixes | Other Changes | Does not create a release |

Balance, config, and prototype tuning can still use `chore:`, but commit prefixes no longer control release creation.

## Alpha Version Rules

Manual releases may use alpha prerelease numbering during the prototype phase.

- If no alpha tags exist, the next alpha release is `v0.0.0-alpha.1`.
- If `v0.0.0-alpha.1` exists, the next alpha release is `v0.0.0-alpha.2`.
- Existing normal tags such as `v0.1.0`, `v0.2.0`, or `v0.3.0` do not make the next alpha release become `v0.3.0`.
- Commit titles do not create new alpha releases.
- `feat:`, `fix:`, `ci:`, `docs:`, `chore:`, `refactor:`, `build:`, `test:`, and unknown commits are allowed without publishing a release.

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

Manual runs generate release-note previews only. They do not create tags or publish GitHub releases.

## Manual Release Control

Commit titles never automatically create or publish releases.

To publish a release, use an intentional manual release process such as a manually created tag, a user-triggered workflow that explicitly publishes, or another explicit version action.

The current workflow is intentionally limited to manual release-note previews.

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
- Adding a separate explicit release-publishing workflow.

Review the workflow before adding any of these behaviors.
