#!/usr/bin/env python3
"""PR 7c acceptance: packet audit in the diff gate; scratch path disclosed.

Brief VALIDATE (work#12 / gan-layer-separation-plan §4 PR 7):
§6 names packet-audit brief/verdict; §12 names the scratch path
and the TMPDIR fallback; packets never land under docs/ or .pinto/;
pins are v1-packets / v1-packets-consumers; bootstrap installs
audit-packet.

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


class SpecCalculations(unittest.TestCase):
    def test_section_extracts_between_headings(self):
        text = "## 6. Gates\nhello\n\n## 7. Next\nbye\n"
        self.assertEqual(section(text, "6. Gates").strip(), "hello")


class LiveTree(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.spec = SPEC.read_text()
        cls.sec6 = section(cls.spec, "6. Verification Gates (Non-Negotiable)")
        cls.sec12 = section(cls.spec, "12. Loops (supplied, not defined here)")
        cls.lockfile = (ROOT / "lockfile.toml").read_text()
        cls.bootstrap = (ROOT / "scripts" / "harness-bootstrap").read_text()
        cls.features = json.loads((ROOT / "features.json").read_text())
        cls.progress = (ROOT / "progress.md").read_text()

    def test_section_6_names_packet_audit(self):
        self.assertTrue(self.sec6, "HARNESS-SPEC.md missing §6")
        self.assertIn("packet-audit brief", self.sec6)
        self.assertIn("packet-audit verdict", self.sec6)

    def test_section_12_names_scratch_path(self):
        self.assertTrue(self.sec12, "HARNESS-SPEC.md missing §12")
        self.assertIn("Packet scratch path", self.sec12)
        self.assertIn("${TMPDIR:-/tmp}/", self.sec12)

    def test_spec_does_not_place_a_packet_in_the_repo(self):
        for line in self.spec.splitlines():
            if "packet" not in line.lower():
                continue
            self.assertNotIn("docs/", line, line)
            self.assertNotIn(".pinto/", line, line)

    def test_lockfile_pins_are_the_packet_tags(self):
        self.assertIn('skills = "v1-packets"', self.lockfile)
        self.assertIn('loops  = "v1-packets-consumers"', self.lockfile)

    def test_bootstrap_has_audit_packet_block(self):
        for literal in (
            'if [ -f "$SKILLS_TREE/scripts/audit-packet" ]; then',
            'cp "$SKILLS_TREE/scripts/audit-packet" "$TARGET/scripts/audit-packet"',
            'echo "  = kept existing scripts/audit-packet"',
            r"packet-audit MODE +ARGS:\n    @./scripts/audit-packet {{MODE}} {{ARGS}}",
        ):
            self.assertIn(literal, self.bootstrap, literal)

    def test_features_records_pr7c(self):
        phase = self.features["gan-layer-separation"]
        self.assertNotEqual(phase.get("status"), "in_progress")
        ids = {
            c["id"]
            for c in phase.get("commits") or []
            if c.get("status") == "completed"
        }
        self.assertIn("pr7c", ids)

    def test_progress_records_pr7c(self):
        self.assertRegex(
            self.progress,
            r"(?m)^### gan-layer-separation — PR 7c \(COMPLETED\)",
        )


if __name__ == "__main__":
    unittest.main()
