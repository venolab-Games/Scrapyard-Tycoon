# Release Automation

This repository now has an automated semantic versioning and GitHub release workflow.

The active files are:

- `.github/workflows/release.yml`
- `scripts/generate_release.py`

The workflow creates version tags and GitHub releases from Conventional Commit-style commit titles.

## Purpose

The release automation turns commit history into predictable version numbers and clean GitHub release notes.

It is designed to:

- Read commits since the latest version tag.
- Decide the next version using `MAJOR.MINOR.PATCH`.
- Group release notes into readable sections.
- Create tags such as `v0.1.0`, `v0.1.1`, and `v0.2.0`.
- Create a GitHub release with generated notes.

It does not update `CHANGELOG.md` or README version/status sections yet.

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

| Prefix | Release-note section | Version impact |
| --- | --- | --- |
| `feat` | New Features | Minor |
| `fix` | Bug Fixes | Patch |
| `docs` | Documentation | No release by default |
| `refactor` | Refactors | No release by default |
| `chore` | Chores | No release by default |
| `build` | Build | No release by default |
| `test` | Tests | No release by default |
| Unknown prefixes | Other Changes | No release by default |

Any commit can trigger a major release when it includes `!` after the type or scope, or when its description contains `BREAKING CHANGE:`.

## Version Bump Rules

The automation chooses the highest required bump from commits since the latest version tag.

- No previous version tag: create `v0.1.0`.
- `BREAKING CHANGE:` or `!`: bump major.
- `feat:`: bump minor.
- `fix:`: bump patch.
- Only `docs:`, `chore:`, `refactor:`, `build:`, `test:`, or unknown commits: do not create a new release when a previous version tag exists.

Examples:

| Latest tag | Commits included | Next result |
| --- | --- | --- |
| No tag | Any commit history | `v0.1.0` |
| `v0.1.0` | `fix: repair parts display update` | `v0.1.1` |
| `v0.1.0` | `feat: add starter vehicle purchase` | `v0.2.0` |
| `v0.1.0` | `feat!: replace save data format` | `v1.0.0` |
| `v0.1.0` | `docs: clarify setup steps` | No release |

## Release Note Sections

Generated GitHub release notes can include:

- New Features
- Bug Fixes
- Documentation
- Refactors
- Chores
- Build
- Tests
- Other Changes

Breaking changes are marked inside their section with `[BREAKING]`.

Example:

```markdown
# v0.2.0

Changes since v0.1.0.

## New Features

- Add garage sorting controls (abc1234)

## Bug Fixes

- Prevent duplicate purchase prompt (def5678)
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

To avoid unintended releases:

- Use `docs:`, `chore:`, `refactor:`, `build:`, or `test:` for changes that should not release by themselves.
- Do not use `feat:` unless the change should create a minor release.
- Do not use `fix:` unless the change should create a patch release.
- Do not add `!` unless the change should create a major release.
- Do not include `BREAKING CHANGE:` unless the change should create a major release.
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
- Publishing prereleases.
- Supporting release branches.
- Requiring manual approval before tag and release creation.

Review the workflow before adding any of these behaviors.
