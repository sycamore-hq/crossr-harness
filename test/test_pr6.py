#!/usr/bin/env python3
"""PR 6 acceptance: HARNESS-SPEC discloses plan-first load and gates.

Brief VALIDATE (work#11 / gan-layer-separation-plan §4 PR 6):
plan-time generator loads plan-writer, not code-writer; architecture
sits at plan time; the default diff gate is mechanical → testing →
code-review.

Calculations are pure. Loading the tree is the action.
"""

from __future__ import annotations

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPEC = ROOT / "HARNESS-SPEC.md"


def section(text: str, heading: str) -> str:
    pat = re.compile(
        rf"(?ms)^## {re.escape(heading)}\n(.*?)(?=^## |\Z)"
    )
    m = pat.search(text)
    return m.group(1) if m else ""


def names_plan_writer_at_plan_time(text: str) -> bool:
    return bool(
        re.search(r"(?i)plan[- ]time|plan phase", text)
        and "plan-writer" in text
    )


def code_writer_is_execute_only(section11: str) -> bool:
    plan = re.search(
        r"(?is)Generator \(plan[^)]*\)(.*?)(?=Generator \(execute|\Z)",
        section11,
    )
    if not plan:
        return False
    body = plan.group(1)
    loads_code_writer = bool(re.search(r"(?i)loads `code-writer`", body))
    return "plan-writer" in body and not loads_code_writer


class SpecCalculations(unittest.TestCase):
    def test_section_extracts_between_headings(self):
        text = "## 6. Gates\nhello\n\n## 7. Next\nbye\n"
        self.assertEqual(section(text, "6. Gates").strip(), "hello")

    def test_plan_writer_needs_plan_time_words(self):
        self.assertTrue(
            names_plan_writer_at_plan_time(
                "Generator (plan phase) loads plan-writer"
            )
        )
        self.assertFalse(names_plan_writer_at_plan_time("loads plan-writer"))

    def test_execute_paragraph_may_name_code_writer(self):
        body = (
            "Generator (plan phase) loads `plan-writer`.\n"
            "Generator (execute phase) loads `code-writer`.\n"
        )
        self.assertTrue(code_writer_is_execute_only(body))
        self.assertFalse(
            code_writer_is_execute_only(
                "Generator (plan phase) loads `plan-writer` and loads `code-writer`.\n"
                "Generator (execute phase) loads `code-writer`.\n"
            )
        )


class LiveTree(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.spec = SPEC.read_text()
        cls.sec6 = section(cls.spec, "6. Verification Gates (Non-Negotiable)")
        cls.sec11 = section(cls.spec, "11. Agent Definitions (GAN Mechanization)")
        cls.sec12 = section(cls.spec, "12. Loops (supplied, not defined here)")
        cls.features = json.loads((ROOT / "features.json").read_text())
        cls.progress = (ROOT / "progress.md").read_text()

    def test_section_6_exists(self):
        self.assertTrue(self.sec6, "HARNESS-SPEC.md missing §6")

    def test_plan_gate_is_audit_then_architecture(self):
        self.assertRegex(self.sec6, r"(?i)just plan-audit")
        self.assertRegex(self.sec6, r"(?i)plan time")
        self.assertRegex(self.sec6, r"`architecture`")
        self.assertNotRegex(self.sec6, r"→\s*(generator|Generator|<node>)")
        self.assertRegex(self.sec6, r"(?i)plan artifact path|§12")
        self.assertIn("docs/plans/pbi/", self.sec12)

    def test_diff_gate_is_not_architect_last(self):
        self.assertRegex(self.sec6, r"`testing`")
        self.assertRegex(self.sec6, r"`code-review`")
        self.assertRegex(self.sec6, r"(?i)unsatisfiable")
        self.assertNotIn("architectural sign-off", self.sec6)

    def test_section_11_splits_plan_and_execute_loads(self):
        self.assertTrue(names_plan_writer_at_plan_time(self.sec11), self.sec11)
        self.assertTrue(code_writer_is_execute_only(self.sec11), self.sec11)

    def test_spec_drops_the_old_diff_chain_slogan(self):
        self.assertNotIn("Reviewer → Tester → Architect", self.spec)

    def test_features_records_pr6c(self):
        phase = self.features["gan-layer-separation"]
        self.assertNotEqual(phase.get("status"), "in_progress")
        ids = {
            c["id"]
            for c in phase.get("commits") or []
            if c.get("status") == "completed"
        }
        self.assertIn("pr6c", ids)

    def test_progress_records_pr6c(self):
        self.assertRegex(
            self.progress,
            r"(?m)^### gan-layer-separation — PR 6c \(COMPLETED\)",
        )


if __name__ == "__main__":
    unittest.main()
