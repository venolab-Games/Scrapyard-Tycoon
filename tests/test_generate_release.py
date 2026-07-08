import unittest

from scripts.generate_release import Commit, build_release_notes, should_create_alpha_release


class BuildReleaseNotesTests(unittest.TestCase):
    def test_commit_titles_do_not_request_alpha_release(self):
        commits = [
            Commit("1" * 40, "feat: add player sprint", ""),
            Commit("2" * 40, "fix: prevent stuck sprint speed", ""),
            Commit("3" * 40, "ci: update release workflow", "release tag version"),
        ]

        self.assertFalse(should_create_alpha_release(commits, None))
        self.assertFalse(should_create_alpha_release(commits, "v0.0.0-alpha.9"))

    def test_body_starts_with_changes_line_without_version_heading(self):
        notes = build_release_notes(
            "v0.0.0-alpha.4",
            [Commit("a" * 40, "feat: add player-facing build button signs", "")],
            "v0.0.0-alpha.3",
        )

        self.assertTrue(notes.startswith("Changes since v0.0.0-alpha.3.\n"))
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


if __name__ == "__main__":
    unittest.main()
