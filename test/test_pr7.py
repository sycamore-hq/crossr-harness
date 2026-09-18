#!/usr/bin/env python3
"""PR 7c acceptance: packet audit in the diff gate; scratch path disclosed.

Brief VALIDATE (work#12 / gan-layer-separation-plan §4 PR 7):
§6 names packet-audit brief/verdict; §12 names the scratch path
and the TMPDIR fallback; packets never land inside the repo;
the pins are not pre-migration catalogs; bootstrap installs
audit-packet.

Calculations are pure. Loading the tree is the action.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Tags cut before the board cutover. Each still carries features.json /
# progress.md and a skill layer that names one tracking product, so pinning
# one reinstalls exactly what the migration removed. Append-only.
RETIRED_PINS = {
    "skills": {"v0-last-monolith", "v1-gan-layers", "v1-one-law", "v1-packets"},
    "loops": {
        "v0",
        "v1-cards",
        "v1-no-rtl",
        "v1-generator-consumers",
        "v1-runtime-agents",
        "v1-one-law-consumers",
        "v1-packets-consumers",
    },
}

PIN_LINE = re.compile(r'(?m)^(skills|loops)\s*=\s*"([^"]+)"')


def lockfile_pins(text: str) -> dict[str, str]:
    """The skills and loops pins a lockfile declares."""
    return {key: value for key, value in PIN_LINE.findall(text)}
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

    def test_lockfile_pins_no_pre_board_catalog(self):
        """Every tag below predates the board cutover, so each still ships
        features.json / progress.md and a skill layer naming one tracker.
        Pinning any of them reinstalls what the migration removed. Append
        when a pin is retired; asserting the current pin by literal made
        every legitimate bump edit a test instead."""
        for key, pin in lockfile_pins(self.lockfile).items():
            with self.subTest(key=key):
                self.assertNotIn(pin, RETIRED_PINS[key],
                                 f"{key} pin {pin!r} predates the board cutover")

    def test_bootstrap_has_audit_packet_block(self):
        for literal in (
            'if [ -f "$SKILLS_TREE/scripts/audit-packet" ]; then',
            'cp "$SKILLS_TREE/scripts/audit-packet" "$TARGET/scripts/audit-packet"',
            'echo "  = kept existing scripts/audit-packet"',
            r"packet-audit MODE +ARGS:\n    @./scripts/audit-packet {{MODE}} {{ARGS}}",
        ):
            self.assertIn(literal, self.bootstrap, literal)



if __name__ == "__main__":
    unittest.main()
