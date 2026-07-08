# Release Notes Preview

This repository uses a simple manual release-notes preview system.

The active files are:

- `.github/workflows/release.yml`
- `scripts/generate_release.py`

Manual tags and manually created GitHub releases are the source of truth. The preview system never creates tags, never publishes GitHub releases, and never bumps version numbers.

## Purpose

The preview turns commit history into readable release-note text before a maintainer creates a release manually.

It is designed to:

- Read commits since the latest reachable tag.
- Group release notes into readable sections.
- Link short commit hashes to exact GitHub commit pages.
- Clearly state that the output is only a preview.

It does not update `CHANGELOG.md`, README version/status sections, tags, GitHub releases, or project version numbers.

## When It Runs

The GitHub Actions workflow only runs when a maintainer starts it manually with `workflow_dispatch`.

The workflow does not run automatically on pushes, pull requests, or other branches.

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

Commit prefixes only choose the release-note section. They do not trigger releases.

| Prefix | Release-note section | Automatic release behavior |
| --- | --- | --- |
| `feat` | New Features | Never creates a release |
| `fix` | Fixes | Never creates a release |
| `ci` | CI / Automation | Never creates a release |
| `docs` | Documentation | Never creates a release |
| `refactor` | Refactors | Never creates a release |
| `chore` | Chores | Never creates a release |
| `build` | Build | Never creates a release |
| `test` | Tests | Never creates a release |
| Unknown prefixes | Other Changes | Never creates a release |

Breaking changes are marked inside their section with `[BREAKING]`, but they still do not create tags, releases, or version bumps.

## Release Note Sections

Generated release notes can include:

- New Features
- Fixes
- Documentation
- CI / Automation
- Refactors
- Chores
- Build
- Tests
- Other Changes

Example:

```markdown
Release notes preview.
No tag, GitHub release, or version bump was created.

Changes since v0.0.1.

## New Features

- Add garage sorting controls ([abc1234](https://github.com/venolab-Games/roblox-vehicle-tycoon/commit/abc1234))

## Fixes

- Prevent duplicate purchase prompt ([def5678](https://github.com/venolab-Games/roblox-vehicle-tycoon/commit/def5678))
```

## Manual Preview Flow

To run the preview locally:

```powershell
python scripts/generate_release.py --notes-file release_notes.md
```

The preview is written to `release_notes.md` and the script prints metadata including:

- `release_needed=false`
- `tag=`
- `version_bump=none`
- `compare_tag=<latest reachable tag>`

To run the GitHub Actions preview:

1. Open the repository on GitHub.
2. Go to the Actions tab.
3. Select the Release Notes Preview workflow.
4. Choose Run workflow.
5. Select the branch to preview.
6. Start the run.

The workflow prints the preview in the run logs, adds it to the job summary, and uploads `release_notes.md` as the `release-notes-preview` artifact.

## Manual Release Flow

To create a release such as `v0.0.1`:

1. Run the local or GitHub Actions preview.
2. Review `release_notes.md`.
3. Manually create the tag, such as `v0.0.1`, when the release is ready.
4. Manually create the GitHub release for that tag.
5. Paste or adapt the preview text into the GitHub release notes.

The preview does not create `v0.0.1`, `alpha.10`, or any other tag.

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

These are not enabled:

- Automatic tag creation.
- Automatic GitHub release publishing.
- Automatic version bumps.
- Updating `CHANGELOG.md`.
- Updating README version or status sections.
- Release branch management.

Review the workflow before adding any of these behaviors.
