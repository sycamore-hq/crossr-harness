crossr-harness — STATUS DASHBOARD CONTRACT (in-harness UI)

You are the agent doing the work in this project. This file tells you how to keep
its status view honest while you work. It is machine-facing: it assumes you already
know the project, and it never explains what a dashboard is.

PARAMETERS (resolved for this project)
  PROJECT_NAME     = crossr-harness
  REPO             = this checkout
  REFRESH          = `just status` (or `./scripts/status-dashboard`)
  PUBLISH          = `just status-html`
  DASHBOARD_FILE   = docs/status-dashboard.html
  CONFIG           = none — defaults apply
  SOURCES          = see SOURCES below
  CHECKPOINTS      = see CHECKPOINTS below

SOURCES OF TRUTH (read-only; the dashboard renders these, it never replaces them)
  Board          : `pinto list --json` when pinto is on PATH (DEFAULT_CONFIG); absent, the dashboard falls back to features.json and REFRESH prints `(from features.json)`
  Tracking file  : features.json — phases -> commits -> features; schema in features.schema.json
  Narrative log  : progress.md
  Status words   : done   = completed, complete, done, verified, merged, shipped
                   active = in progress, inprogress, building, built, review,
                            in review, started, wip, regressed
                   everything else counts as todo
  Literal strings collected from features.json across harness / loops / skills
  (2026-09-03): phase:completed, phase:in_progress, commit:completed.
  Schema also allows phase:pending, phase:verified, commit:pending, commit:in_progress.
  in_progress normalises to "in progress" and maps to active. pending is todo by
  omission. No dashboard.config.json — those defaults already fit.
  If a source is missing, the dashboard degrades to what remains. That is expected.
  Say which source is absent rather than filling the gap with a guess.

CHECKPOINTS (refresh at each; never batch them to the end)
  - After any features.json status change (phase or commit).
  - After appending a Verification Status block to progress.md.
  - After merging a stacked PR that this tracker records.
  The rule behind the list: refresh immediately after the underlying state changes,
  because the window between the change and the refresh is the window in which the
  dashboard is lying.

RULES
  - Generated, never hand-written. Run REFRESH or PUBLISH. Do not hand-author
    DASHBOARD_FILE, and do not edit it to say something the sources do not.
  - The dashboard is a view, not a record. When it disagrees with the board, the
    board wins and the disagreement is itself a finding worth reporting.
  - Never show work as complete before its completion evidence exists.
  - A stale dashboard is worse than none. If you cannot refresh it, say so in the
    same place you record progress, and say why.
  - Commit DASHBOARD_FILE only at a phase or ticket boundary, not on
    every refresh, so the diff stays meaningful.
  - Report counts you read, never counts you expect. If REFRESH shows zeros where
    you believed there was work, that is a defect in the sources or the config —
    investigate it, do not narrate around it.

WHEN THE NUMBERS LOOK WRONG
  A dashboard reporting "0 in progress" during active work usually means the status
  vocabulary does not match the tracker's. Check CONFIG's status words against the
  literal strings the board emits before concluding the work is untracked.
  Gotcha (sycamore-hq/work#10): totals() used to flatten commit items only. A phase
  left in_progress after every child commit completed printed 100% done and 0 in
  progress. feature_units() now counts that phase as a unit. Do not "fix" the
  number by editing features.json alone — that is a different ticket (gan-close-4b).
  Prove with: `python3 test/test_status_dashboard.py`.

FIRST ACTION
  Run REFRESH now and state the current counts before doing anything else. That is
  your baseline, and every later claim of progress is measured against it.
