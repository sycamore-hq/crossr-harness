#!/usr/bin/env python3
"""gan-layer-separation is closed as of gan-close-4b; it must not regress to in_progress.

gan-close-4b (work#6): the phase was left open after pr2b/pr3b/pr4-pin.
Dashboard then printed an active phase with 0 in-progress commits.
This is a closure guard for that phase, not a repo-wide invariant.
"""

from __future__ import annotations

import importlib.util
import json
import unittest
from importlib.machinery import SourceFileLoader
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "status-dashboard"
PHASE = "gan-layer-separation"

_loader = SourceFileLoader("status_dashboard", str(SCRIPT))
dash = importlib.util.module_from_spec(
    importlib.util.spec_from_loader(_loader.name, _loader)
)
_loader.exec_module(dash)


class LiveTree(unittest.TestCase):
    def test_gan_phase_is_not_left_open(self):
        features = json.loads((ROOT / "features.json").read_text())
        self.assertIn(PHASE, features, f"{PHASE} missing from features.json")
        phase = features[PHASE]
        self.assertNotEqual(
            dash.classify(phase.get("status", "")),
            dash.ACTIVE,
            "gan-layer-separation must not regress to in_progress",
        )


if __name__ == "__main__":
    unittest.main()
