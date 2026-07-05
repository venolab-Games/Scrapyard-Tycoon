# Release Automation Plan

This document plans a future automated versioning and release workflow for the Roblox Vehicle Tycoon project.

This is documentation only. No release automation is active yet.

## 1. Purpose

The future release automation should help the project turn clear commit history into predictable version numbers and clean GitHub release notes.

The intended system should eventually:

- Read Conventional Commit-style commit titles.
- Group commits into readable release-note sections.
- Decide semantic version bumps using `MAJOR.MINOR.PATCH`.
- Generate clean GitHub release notes.
- Optionally update `CHANGELOG.md`.
- Optionally update README version or status sections.

The workflow should reduce manual release work while keeping release decisions reviewable.

## 2. Commit Title Format Rules

Commit titles should use this format:

```text
type(scope): short summary
```

The `scope` is optional:

```text
type: short summary
```

Rules:

- Use a supported lowercase prefix such as `feat`, `fix`, or `docs`.
- Keep the title short and specific.
- Use the description/body for context, testing notes, or migration details.
- Mark breaking changes with either `!` in the title or `BREAKING CHANGE:` in the description.

Breaking change title format:

```text
feat!: replace save data format
feat(data)!: replace save data format
```

Breaking change description format:

```text
BREAKING CHANGE: Existing saved vehicle inventory data must be migrated.
```

## 3. Supported Commit Prefixes

The future automation should recognize these prefixes:

| Prefix | Release-note section | Version impact |
| --- | --- | --- |
| `feat` | Features | Minor |
| `fix` | Fixes | Patch |
| `perf` | Performance | Patch |
| `refactor` | Code Improvements | No bump by default |
| `docs` | Documentation | No bump by default |
| `test` | Tests | No bump by default |
| `build` | Build | No bump by default |
| `ci` | CI | No bump by default |
| `chore` | Maintenance | No bump by default |
| `style` | Style | No bump by default |
| `revert` | Reverts | Review manually |

Any supported prefix can become a major bump if it includes `!` or has a `BREAKING CHANGE:` note.

## 4. Version Bump Rules

The future automation should inspect all commits since the previous release tag and choose the highest required bump.

Rules:

- `BREAKING CHANGE:` in the commit description means a major bump.
- `!` after the type or scope means a major bump.
- `feat:` means a minor bump.
- `fix:` means a patch bump.
- `perf:` means a patch bump.
- Documentation, tests, chores, CI, and refactors should not bump the version by default.
- If multiple commits are included, the highest bump wins.

Examples:

| Current version | Commits included | Next version |
| --- | --- | --- |
| `1.4.2` | `fix: repair dealership button state` | `1.4.3` |
| `1.4.2` | `feat: add garage sorting controls` | `1.5.0` |
| `1.4.2` | `feat!: replace vehicle save format` | `2.0.0` |
| `1.4.2` | `docs: clarify setup steps` | No release by default |

## 5. Example Commit Titles

Good commit titles:

```text
feat: add vehicle showroom filtering
feat(ui): add garage sort controls
fix: prevent duplicate vehicle purchase prompt
fix(spawn): reset vehicle position after failed spawn
perf: cache dealership vehicle list
docs: document Rojo setup
test: cover currency reward calculation
chore: update release planning docs
feat!: replace player vehicle save schema
fix(data)!: remove legacy inventory fallback
```

Avoid vague titles:

```text
update stuff
fix bugs
changes
wip
final
```

## 6. Example Generated Release Sections

Example generated release notes:

```markdown
## v1.5.0

### Features

- Add garage sort controls
- Add vehicle showroom filtering

### Fixes

- Prevent duplicate vehicle purchase prompt
- Reset vehicle position after failed spawn

### Performance

- Cache dealership vehicle list

### Documentation

- Document Rojo setup
```

Example major release notes:

```markdown
## v2.0.0

### Breaking Changes

- Replace player vehicle save schema

### Features

- Add migration checks for vehicle inventory data

### Fixes

- Remove legacy inventory fallback
```

## 7. Suggested Future File Structure

This structure is a suggestion only. It should not be created until the project is ready to enable automation.

```text
.github/
  workflows/
    release.yml
scripts/
  release/
    generate-release-notes.js
    determine-version-bump.js
CHANGELOG.md
docs/
  commit-style-guide.md
  release-automation-plan.md
```

Possible responsibilities:

- `.github/workflows/release.yml`: Manual or controlled release workflow.
- `scripts/release/determine-version-bump.js`: Reads commit titles and chooses the next semantic version.
- `scripts/release/generate-release-notes.js`: Groups commits into release-note sections.
- `CHANGELOG.md`: Optional generated or curated release history.

## 8. Suggested GitHub Actions Approach

This section is NOT ACTIVE YET.

When the project is ready, start with a GitHub Actions workflow that is manual-only:

```yaml
on:
  workflow_dispatch:
```

Recommended early behavior:

- Run only when manually triggered.
- Calculate the proposed next version.
- Generate release notes as an artifact or job summary.
- Avoid creating tags or releases during the first test phase.
- Require a maintainer to review the proposed output before enabling write actions.

Possible later behavior:

- Create a tag after review.
- Create a GitHub release from generated notes.
- Optionally update `CHANGELOG.md`.
- Optionally update README version or status sections.

Do not enable automatic triggers such as `push`, `pull_request`, or scheduled runs until the team has reviewed the safety notes and completed the rollout plan.

## 9. Safety Notes

Before enabling automation, review:

- Whether commit titles are consistent enough to drive releases.
- Whether the first release should be generated from the full history or only from a chosen starting tag.
- Whether version tags should use `v1.2.3` or `1.2.3`.
- Which branches are allowed to create releases.
- Whether releases should require manual approval.
- Whether generated notes need human editing before publication.
- Whether changelog updates should be committed automatically or prepared for review.
- Whether README version/status updates should be automated or kept manual.
- Which token permissions the workflow needs.
- How to handle reverts, merge commits, and squash merge titles.

The first active version should be conservative and easy to inspect. Automation should propose changes before it publishes anything.

## 10. Rollout Plan

### Phase 1: Documentation and Commit Discipline

- Adopt the commit title style in `docs/commit-style-guide.md`.
- Use Conventional Commit-style titles in GitHub Desktop.
- Review commit history after a few changes to see whether release grouping is clear.
- Decide the initial version number and tag format.

### Phase 2: Dry-Run Automation

- Add a manual-only GitHub Actions workflow.
- Generate proposed version bumps and release notes without creating tags or releases.
- Save generated output as a workflow artifact or job summary.
- Compare generated notes with expected release notes.
- Adjust prefix handling and section names.

### Phase 3: Controlled Release Automation

- Enable reviewed tag creation and GitHub release creation.
- Keep the workflow manual-only at first.
- Optionally add `CHANGELOG.md` updates after generated notes are trusted.
- Optionally update README version or status sections after the release process is stable.
- Consider automatic triggers only after successful manual releases.
