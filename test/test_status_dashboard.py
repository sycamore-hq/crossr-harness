#!/usr/bin/env python3
"""status-dashboard calculations, over the board model.

The dashboard renders one source: the project's tracking board. The thing
worth guarding is that it never invents work state — an unread board reads as
unread, and grouping never loses an item.
"""

from __future__ import annotations

import importlib.util
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


def item(id_, state, group="Tracking", title="x"):
    return {"id": id_, "title": title, "state": state, "status": state,
            "group": group, "url": ""}


BOARD = [
    item("SYC-1", ACTIVE),
    item("SYC-2", TODO),
    item("SYC-9", DONE, group="Old"),
]


class Totals(unittest.TestCase):
    def test_counts_every_item_once(self):
        t = dash.totals(BOARD, "linear")
        self.assertEqual((t[DONE], t[ACTIVE], t[TODO]), (1, 1, 1))

    def test_source_names_the_backend_that_was_read(self):
        self.assertEqual(dash.totals(BOARD, "linear")["source"], "linear")

    def test_an_unread_board_is_zeros_and_says_so(self):
        t = dash.totals([], None)
        self.assertEqual((t[DONE], t[ACTIVE], t[TODO]), (0, 0, 0))
        self.assertEqual(t["source"], "none")


class Groups(unittest.TestCase):
    def test_every_item_lands_in_exactly_one_group(self):
        groups = dash.groups_from_board(BOARD)
        self.assertEqual(sum(g["total"] for g in groups), len(BOARD))

    def test_items_without_a_group_are_not_dropped(self):
        groups = dash.groups_from_board([item("X-1", TODO, group="")])
        self.assertEqual([g["name"] for g in groups], ["ungrouped"])

    def test_a_group_with_an_active_item_is_active(self):
        groups = dash.groups_from_board(BOARD)
        by_name = {g["name"]: g for g in groups}
        self.assertEqual(by_name["Tracking"]["state"], ACTIVE)

    def test_a_group_whose_items_are_all_done_is_done(self):
        groups = {g["name"]: g for g in dash.groups_from_board(BOARD)}
        self.assertEqual(groups["Old"]["state"], DONE)
        self.assertEqual(groups["Old"]["percent"], 100)

    def test_a_group_of_only_todo_items_is_todo_not_active(self):
        groups = dash.groups_from_board([item("A-1", TODO), item("A-2", TODO)])
        self.assertEqual(groups[0]["state"], TODO)

    def test_unfinished_groups_sort_ahead_of_finished_ones(self):
        self.assertEqual([g["name"] for g in dash.groups_from_board(BOARD)],
                         ["Tracking", "Old"])

    def test_open_groups_lists_only_what_is_outstanding(self):
        openg = dash.open_groups(dash.groups_from_board(BOARD))
        self.assertEqual([g["name"] for g in openg], ["Tracking"])
        self.assertEqual([i["id"] for i in openg[0]["items"]], ["SYC-1", "SYC-2"])

    def test_a_finished_group_is_omitted_entirely(self):
        groups = dash.groups_from_board([item("D-1", DONE)])
        self.assertEqual(dash.open_groups(groups), [])


class Model(unittest.TestCase):
    RAW = {"tasks": [
        {"id": "SYC-1", "title": "adapter", "status": "In Progress",
         "status_type": "started", "group": "Tracking"},
        {"id": "SYC-9", "title": "shipped", "status": "Done",
         "status_type": "completed", "group": "Old"},
    ]}

    def model(self, raw, backend="file"):
        cfg = {**dash.DEFAULT_CONFIG,
               "board": dash.merge_board(dash.DEFAULT_CONFIG["board"],
                                         dash.BOARD_ADAPTERS["file"])}
        return dash.build_model(raw, backend, ["abc123 a commit"],
                                "proj", "now", cfg)

    def test_a_payload_becomes_counts_groups_and_items(self):
        m = self.model(self.RAW)
        self.assertEqual(m["totals"][ACTIVE], 1)
        self.assertEqual([g["name"] for g in m["groups"]], ["Tracking", "Old"])
        self.assertEqual(m["backend"], "file")

    def test_an_unread_board_models_as_empty_rather_than_raising(self):
        m = self.model(None, backend=None)
        self.assertEqual(m["board"], [])
        self.assertEqual(m["groups"], [])
        self.assertEqual(m["totals"]["source"], "none")

    def test_commits_are_context_not_work_state(self):
        m = self.model(None, backend=None)
        self.assertEqual(m["commits"], ["abc123 a commit"])
        self.assertEqual(m["totals"][DONE], 0)


class Renderers(unittest.TestCase):
    """Every surface must survive an unread board — that is when it matters."""

    def empty_model(self):
        return dash.build_model(None, None, [], "proj", "now", dash.DEFAULT_CONFIG)

    def full_model(self):
        cfg = {**dash.DEFAULT_CONFIG,
               "board": dash.merge_board(dash.DEFAULT_CONFIG["board"],
                                         dash.BOARD_ADAPTERS["file"])}
        return dash.build_model(
            {"tasks": [{"id": "SYC-1", "title": "adapter", "status": "In Progress",
                        "status_type": "started", "group": "Tracking",
                        "url": "https://x", "depends_on": []}]},
            "file", ["abc123 a commit"], "proj", "now", cfg)

    def test_terminal_says_the_board_was_not_read(self):
        out = dash.render_terminal(self.empty_model())
        self.assertIn("no board read", out)

    def test_terminal_renders_a_board(self):
        out = dash.render_terminal(self.full_model())
        self.assertIn("SYC-1", out)
        self.assertIn("WORKSTREAMS", out)

    def test_html_renders_both_ways(self):
        self.assertIn("<!DOCTYPE html>", dash.render_html(self.empty_model()))
        self.assertIn("SYC-1", dash.render_html(self.full_model()))

    def test_markdown_renders_both_ways(self):
        self.assertIn("proj", dash.render_markdown(self.empty_model()))
        self.assertIn("SYC-1", dash.render_markdown(self.full_model()))

    def test_detail_renders_both_ways(self):
        for model in (self.empty_model(), self.full_model()):
            detail = dash.build_detail(model, model["commits"])
            self.assertIn("proj", dash.render_detail_terminal(model, detail))
            self.assertIn("proj", dash.render_detail_markdown(model, detail))

    def test_portfolio_renders(self):
        pf = dash.build_portfolio([self.full_model(), self.empty_model()], "now")
        self.assertEqual(pf["count"], 2)
        self.assertIn("SYC-1", dash.render_portfolio_markdown(pf))
        self.assertIn("<!DOCTYPE html>", dash.render_portfolio_html(pf))


if __name__ == "__main__":
    unittest.main()
