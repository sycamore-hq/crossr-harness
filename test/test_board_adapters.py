#!/usr/bin/env python3
"""Board adapter layer: which backend gets picked, and what its payload becomes.

The harness names no tracking vendor. What it owns is the contract in
docs/board-contract.md — these tests hold that contract, on both sides: the
dashboard reading a payload, and the Linear adapter producing one.
"""

from __future__ import annotations

import importlib.util
import json
import os
import tempfile
import unittest
from importlib.machinery import SourceFileLoader
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def _load(name: str, filename: str):
    loader = SourceFileLoader(name, str(ROOT / "scripts" / filename))
    module = importlib.util.module_from_spec(
        importlib.util.spec_from_loader(loader.name, loader)
    )
    loader.exec_module(module)
    return module


dash = _load("status_dashboard", "status-dashboard")
linear = _load("linear_board", "linear-board")

DONE, ACTIVE, TODO = dash.DONE, dash.ACTIVE, dash.TODO

PAYLOAD = {
    "backend": "file",
    "tasks": [
        {"id": "SYC-1", "title": "adapter", "status": "In Progress",
         "status_type": "started", "group": "Tracking", "url": "https://x/SYC-1",
         "labels": ["harness"], "depends_on": []},
        {"id": "SYC-2", "title": "inversion", "status": "Todo",
         "status_type": "unstarted", "group": "Tracking", "url": "",
         "labels": [], "depends_on": ["SYC-1"]},
        {"id": "SYC-9", "title": "shipped", "status": "Done",
         "status_type": "completed", "group": "Old", "url": "", "labels": [],
         "depends_on": []},
    ],
}


class Resolution(unittest.TestCase):
    """`auto` picks by availability. No backend is preferred over another."""

    def resolve(self, root: Path, board: dict | None = None):
        cfg = dash.load_config(root, None)
        if board is not None:
            cfg = {**cfg, "board": dash.merge_board(dash.DEFAULT_CONFIG["board"], board),
                   "board_overrides": board}
        return dash.resolve_board(root, cfg, cfg.get("board_overrides", {}))

    def test_auto_with_nothing_available_resolves_to_no_board(self):
        with tempfile.TemporaryDirectory() as tmp:
            with _without_linear_env():
                backend, _ = self.resolve(Path(tmp))
        self.assertIsNone(backend)

    def test_auto_finds_a_snapshot_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "board.json").write_text(json.dumps(PAYLOAD))
            with _without_linear_env():
                backend, cfg = self.resolve(Path(tmp))
        self.assertEqual(backend, "file")
        self.assertEqual(cfg["fields"]["status"], "status_type")

    def test_auto_prefers_a_live_board_over_a_snapshot(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "board.json").write_text(json.dumps(PAYLOAD))
            os.environ["LINEAR_API_KEY"] = "lin_api_test"
            try:
                backend, _ = self.resolve(Path(tmp))
            finally:
                del os.environ["LINEAR_API_KEY"]
        self.assertEqual(backend, "linear")

    def test_backend_none_reads_nothing_even_with_a_snapshot_present(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "board.json").write_text(json.dumps(PAYLOAD))
            backend, _ = self.resolve(Path(tmp), {"backend": "none"})
            self.assertIsNone(backend)
            self.assertIsNone(dash.read_board(Path(tmp), backend, {}))

    def test_project_overrides_win_over_the_adapter(self):
        board = {"backend": "file", "fields": {"status": "status"}}
        with tempfile.TemporaryDirectory() as tmp:
            _, cfg = self.resolve(Path(tmp), board)
        self.assertEqual(cfg["fields"]["status"], "status")
        # Untouched adapter keys still come through.
        self.assertEqual(cfg["items_path"], "tasks")

    def test_command_backend_without_a_command_is_no_board(self):
        with tempfile.TemporaryDirectory() as tmp:
            backend, _ = self.resolve(Path(tmp), {"backend": "command"})
        self.assertIsNone(backend)


class PayloadShaping(unittest.TestCase):
    def items(self):
        cfg = dash.merge_board(dash.DEFAULT_CONFIG["board"], dash.BOARD_ADAPTERS["file"])
        return dash.board_items(PAYLOAD, cfg)

    def test_status_type_classifies_and_the_label_is_kept_for_display(self):
        active = self.items()[0]
        self.assertEqual(active["state"], ACTIVE)
        self.assertEqual(active["status"], "In Progress")

    def test_group_and_url_survive(self):
        first = self.items()[0]
        self.assertEqual(first["group"], "Tracking")
        self.assertEqual(first["url"], "https://x/SYC-1")

    def test_every_bucket_is_represented(self):
        self.assertEqual([i["state"] for i in self.items()], [ACTIVE, TODO, DONE])

    def test_a_board_without_status_type_falls_back_to_the_status_word(self):
        raw = {"tasks": [{"id": "1", "title": "x", "status": "shipped"}]}
        cfg = dash.merge_board(dash.DEFAULT_CONFIG["board"], {"items_path": "tasks"})
        self.assertEqual(dash.board_items(raw, cfg)[0]["state"], DONE)

    def test_readiness_uses_depends_on(self):
        ready = dash.readiness(self.items(), PAYLOAD["tasks"])
        self.assertEqual([i["id"] for i in ready["ready"]], ["SYC-1"])
        self.assertEqual([i["id"] for i in ready["blocked"]], ["SYC-2"])

    def test_a_snapshot_file_reads_end_to_end(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "board.json").write_text(json.dumps(PAYLOAD))
            raw = dash.read_board(Path(tmp), "file", dash.BOARD_ADAPTERS["file"])
        self.assertEqual(len(raw["tasks"]), 3)

    def test_unreadable_snapshot_degrades_to_no_board_rather_than_raising(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "board.json").write_text("{not json")
            self.assertIsNone(
                dash.read_board(Path(tmp), "file", dash.BOARD_ADAPTERS["file"]))


class LinearAdapter(unittest.TestCase):
    """The Linear side of the same contract, shaped from real API node shapes."""

    NODE = {
        "identifier": "SYC-1",
        "title": "adapter",
        "url": "https://linear.app/x/issue/SYC-1",
        "updatedAt": "2026-09-18T00:00:00.000Z",
        "state": {"name": "In Progress", "type": "started"},
        "project": {"name": "Tracking"},
        "labels": {"nodes": [{"name": "harness"}]},
        "inverseRelations": {"nodes": [
            {"type": "blocks", "issue": {"identifier": "SYC-0"}},
            {"type": "related", "issue": {"identifier": "SYC-7"}},
        ]},
    }

    def test_a_node_becomes_a_contract_item(self):
        task = linear.to_task(self.NODE)
        self.assertEqual(task["id"], "SYC-1")
        self.assertEqual(task["status"], "In Progress")
        self.assertEqual(task["status_type"], "started")
        self.assertEqual(task["group"], "Tracking")
        self.assertEqual(task["labels"], ["harness"])

    def test_only_blocking_relations_become_dependencies(self):
        self.assertEqual(linear.depends_on(self.NODE), ["SYC-0"])

    def test_an_issue_with_no_project_or_labels_still_shapes(self):
        task = linear.to_task({"identifier": "SYC-3", "title": "loose",
                               "state": {"name": "Todo", "type": "unstarted"}})
        self.assertEqual(task["group"], "")
        self.assertEqual(task["labels"], [])
        self.assertEqual(task["depends_on"], [])

    def test_canceled_and_duplicate_issues_are_not_work(self):
        nodes = [self.NODE,
                 {"identifier": "SYC-4", "title": "dropped",
                  "state": {"name": "Canceled", "type": "canceled"}},
                 {"identifier": "SYC-5", "title": "dupe",
                  "state": {"name": "Duplicate", "type": "duplicate"}}]
        self.assertEqual([t["id"] for t in linear.shape(nodes, False)], ["SYC-1"])
        self.assertEqual(len(linear.shape(nodes, True)), 3)

    def test_filter_is_omitted_entirely_when_nothing_narrows_it(self):
        self.assertIsNone(linear.build_filter(None, None))
        self.assertEqual(linear.build_filter("SYC", None),
                         {"team": {"key": {"eq": "SYC"}}})

    def test_personal_keys_go_raw_and_oauth_tokens_are_bearer(self):
        self.assertEqual(linear.auth_header("lin_api_x"), "lin_api_x")
        self.assertEqual(linear.auth_header("lin_oauth_x"), "Bearer lin_oauth_x")

    def test_the_only_graphql_document_is_a_query(self):
        # The read-only status agent is allowed to run this script. That holds
        # only while the script cannot write.
        self.assertNotIn("mutation", linear.QUERY.lower())

    def test_what_linear_emits_is_what_the_dashboard_reads(self):
        payload = {"backend": "linear", "tasks": linear.shape([self.NODE], False)}
        cfg = dash.merge_board(dash.DEFAULT_CONFIG["board"],
                               dash.BOARD_ADAPTERS["linear"])
        item = dash.board_items(payload, cfg)[0]
        self.assertEqual(item["state"], ACTIVE)
        self.assertEqual(item["id"], "SYC-1")
        self.assertEqual(item["group"], "Tracking")


class _without_linear_env:
    """Ambient Linear credentials must not decide a test's outcome."""

    KEYS = ("LINEAR_API_KEY", "LINEAR_TOKEN")

    def __enter__(self):
        self.saved = {k: os.environ.pop(k) for k in self.KEYS if k in os.environ}

    def __exit__(self, *exc):
        os.environ.update(self.saved)
        return False


if __name__ == "__main__":
    unittest.main()
