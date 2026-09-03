#!/usr/bin/env python3
"""status-dashboard calculations. The live-data case is the ticket:

A phase left in_progress after every child commit completed used to
count as 0 in progress. totals() must count that phase.
"""

from __future__ import annotations

import importlib.util
import json
import unittest
from importlib.machinery import SourceFileLoader
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "status-dashboard"

_loader = SourceFileLoader("status_dashboard", str(SCRIPT))
dash = importlib.util.module_from_spec(
    importlib.util.spec_from_loader(_loader.name, _loader)
)
_loader.exec_module(dash)

DONE, ACTIVE, TODO = dash.DONE, dash.ACTIVE, dash.TODO


def phases(features: dict):
    return dash.phases_from_features(features)


class FeatureUnits(unittest.TestCase):
    def test_phase_in_progress_all_commits_done_is_one_active(self):
        # The live harness / loops / skills shape that printed 0 in progress.
        shaped = phases({
            "gan-layer-separation": {
                "status": "in_progress",
                "commits": [
                    {"id": "pr2b", "title": "a", "status": "completed"},
                    {"id": "pr3b", "title": "b", "status": "completed"},
                    {"id": "pr4-pin", "title": "c", "status": "completed"},
                ],
            }
        })
        t = dash.totals(shaped, [])
        self.assertEqual(t[DONE], 3)
        self.assertEqual(t[ACTIVE], 1)
        self.assertEqual(t[TODO], 0)
        self.assertEqual(t["source"], "features.json")

    def test_does_not_double_count_when_a_commit_is_already_active(self):
        shaped = phases({
            "wip": {
                "status": "in_progress",
                "commits": [
                    {"id": "c1", "title": "done", "status": "completed"},
                    {"id": "c2", "title": "now", "status": "in_progress"},
                ],
            }
        })
        t = dash.totals(shaped, [])
        self.assertEqual(t[DONE], 1)
        self.assertEqual(t[ACTIVE], 1)
        self.assertEqual(t[TODO], 0)

    def test_completed_phase_with_completed_commits_does_not_inflate_done(self):
        shaped = phases({
            "shipped": {
                "status": "completed",
                "commits": [
                    {"id": "c1", "title": "a", "status": "completed"},
                    {"id": "c2", "title": "b", "status": "completed"},
                ],
            }
        })
        t = dash.totals(shaped, [])
        self.assertEqual(t[DONE], 2)
        self.assertEqual(t[ACTIVE], 0)
        self.assertEqual(t[TODO], 0)

    def test_empty_pending_phase_is_todo(self):
        shaped = phases({"next": {"status": "pending", "commits": []}})
        t = dash.totals(shaped, [])
        self.assertEqual(t[DONE], 0)
        self.assertEqual(t[ACTIVE], 0)
        self.assertEqual(t[TODO], 1)

    def test_empty_completed_phase_is_done(self):
        shaped = phases({"phase0": {"status": "completed", "commits": []}})
        t = dash.totals(shaped, [])
        self.assertEqual(t[DONE], 1)
        self.assertEqual(t[ACTIVE], 0)
        self.assertEqual(t[TODO], 0)

    def test_board_items_win_over_features(self):
        shaped = phases({
            "gan-layer-separation": {
                "status": "in_progress",
                "commits": [{"id": "c1", "title": "a", "status": "completed"}],
            }
        })
        board = [{"id": "1", "title": "card", "state": TODO, "status": "todo"}]
        t = dash.totals(shaped, board)
        self.assertEqual(t[DONE], 0)
        self.assertEqual(t[ACTIVE], 0)
        self.assertEqual(t[TODO], 1)
        self.assertEqual(t["source"], "board")


class OpenPhaseFeatures(unittest.TestCase):
    def test_all_done_commits_still_lists_an_in_progress_phase(self):
        shaped = phases({
            "gan-layer-separation": {
                "status": "in_progress",
                "commits": [
                    {"id": "pr2b", "title": "a", "status": "completed"},
                ],
            }
        })
        open_phases = dash.open_phase_features(shaped)
        self.assertEqual(len(open_phases), 1)
        self.assertEqual(open_phases[0]["name"], "gan-layer-separation")
        self.assertEqual(
            [item["state"] for item in open_phases[0]["items"]],
            [ACTIVE],
        )

    def test_fully_completed_phase_is_omitted(self):
        shaped = phases({
            "shipped": {
                "status": "completed",
                "commits": [{"id": "c1", "title": "a", "status": "completed"}],
            }
        })
        self.assertEqual(dash.open_phase_features(shaped), [])


class LiveHarnessFeatures(unittest.TestCase):
    """Prove the mapping against this repo's features.json, not a guess."""

    def test_live_in_progress_phases_are_visible_in_totals(self):
        features = json.loads((ROOT / "features.json").read_text())
        shaped = phases(features)
        t = dash.totals(shaped, [])
        live_active_phases = [
            name for name, body in features.items()
            if isinstance(body, dict) and dash.classify(body.get("status", "")) == ACTIVE
        ]
        live_active_commits = [
            c.get("id")
            for body in features.values() if isinstance(body, dict)
            for c in body.get("commits") or []
            if dash.classify(c.get("status", "")) == ACTIVE
        ]
        # The bug: 1 in_progress phase, 0 in_progress commits, totals said 0.
        self.assertTrue(live_active_phases, "features.json has no in_progress phase to prove against")
        self.assertEqual(live_active_commits, [])
        self.assertEqual(t[ACTIVE], len(live_active_phases))
        self.assertGreaterEqual(t[DONE], 1)


if __name__ == "__main__":
    unittest.main()
