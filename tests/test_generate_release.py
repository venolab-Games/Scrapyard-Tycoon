import unittest

from scripts.generate_release import Commit, build_release_notes, should_create_release


class BuildReleaseNotesTests(unittest.TestCase):
    def test_body_starts_with_changes_line_without_version_heading(self):
        notes = build_release_notes(
            "v0.0.0-alpha.4",
            [Commit("a" * 40, "feat: add player-facing build button signs", "")],
            "v0.0.0-alpha.3",
        )

        self.assertIn("Release notes preview.\n", notes)
        self.assertIn("No tag, GitHub release, or version bump was created.\n", notes)
        self.assertIn("Changes since v0.0.0-alpha.3.\n", notes)
        self.assertNotIn("# v0.0.0-alpha.4", notes)
        self.assertNotIn("## v0.0.0-alpha.4", notes)

    def test_groups_all_commits_including_small_changes(self):
        notes = build_release_notes(
            "v0.0.0-alpha.4",
            [
                Commit("1" * 40, "feat: add player-facing build button signs", ""),
                Commit("2" * 40, "chore: tune prototype button label placement", ""),
                Commit("3" * 40, "fix: hide locked button labels until reveal", ""),
                Commit("4" * 40, "docs: clarify release note generation", ""),
                Commit("5" * 40, "ci: update release workflow permissions", ""),
                Commit("6" * 40, "polish button sign colors", ""),
            ],
            "v0.0.0-alpha.3",
        )

        expected_lines = [
            "## New Features",
            "- Add player-facing build button signs ([1111111]",
            "## Fixes",
            "- Hide locked button labels until reveal ([3333333]",
            "## Documentation",
            "- Clarify release note generation ([4444444]",
            "## CI / Automation",
            "- Update release workflow permissions ([5555555]",
            "## Chores",
            "- Tune prototype button label placement ([2222222]",
            "## Other Changes",
            "- Polish button sign colors ([6666666]",
        ]

        for line in expected_lines:
            with self.subTest(line=line):
                self.assertIn(line, notes)

        self.assertNotIn("## Build", notes)
        self.assertNotIn("## Tests", notes)

    def test_commit_prefixes_do_not_request_release_creation(self):
        commits = [
            Commit("1" * 40, "feat: add vehicle showroom filtering", ""),
            Commit("2" * 40, "fix: prevent duplicate purchase prompts", ""),
            Commit("3" * 40, "chore: tune prototype parts income", ""),
            Commit("4" * 40, "refactor: simplify upgrade lookup", ""),
        ]

        self.assertFalse(should_create_release(commits))

    def test_breaking_changes_do_not_request_release_creation(self):
        commits = [
            Commit("1" * 40, "feat!: replace vehicle save data format", ""),
            Commit(
                "2" * 40,
                "fix(data): remove legacy inventory fallback",
                "BREAKING CHANGE: Existing saved vehicle inventory data must be migrated.",
            ),
        ]

        self.assertFalse(should_create_release(commits))


if __name__ == "__main__":
    unittest.main()
