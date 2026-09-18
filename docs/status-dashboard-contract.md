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
  CONFIG           = dashboard.config.json
  SOURCES          = see SOURCES below
  CHECKPOINTS      = see CHECKPOINTS below

SOURCE OF TRUTH (read-only; the dashboard renders it, it never replaces it)
  Board          : Linear — team Sycamore HQ (SYC)
                   https://linear.app/scull7/team/SYC/overview
  Board adapter  : `scripts/linear-board` (needs $LINEAR_API_KEY or $LINEAR_TOKEN).
                   Without credentials, an agent holding Linear MCP tools writes
                   the same payload to board.json and the `file` adapter reads it.
                   Payload: docs/board-contract.md
  Item ids       : SYC-<n>. They appear in commit subjects and PR titles.
  Status words   : classified on Linear's lifecycle type, not its column names —
                   done   = completed
                   active = started  (In Progress, In Review)
                   todo   = everything else (Backlog, Todo)
                   Canceled and duplicate issues are dropped by the adapter: they
                   are not work, and counting them makes progress look worse than
                   it is.
  There is no file-based tracker in this repository, by design. features.json and
  progress.md were removed when the board became the single source of truth. If
  you find yourself wanting to write work state into a file, that is the board's
  job — open the issue instead.
  If the board cannot be read, the dashboard says so. Report the absence. Do not
  fill the gap with a guess, and do not reconstruct counts from git log.

CHECKPOINTS (refresh at each; never batch them to the end)
  - After moving an item on the board (state change, new item, closure).
  - After recording a Completion Record on an item.
  - After merging a stacked PR that an item tracks.
  The rule behind the list: refresh immediately after the underlying state changes,
  because the window between the change and the refresh is the window in which the
  dashboard is lying.

RULES
  - Generated, never hand-written. Run REFRESH or PUBLISH. Do not hand-author
    DASHBOARD_FILE, and do not edit it to say something the board does not.
  - The dashboard is a view, not a record. When it disagrees with the board, the
    board wins and the disagreement is itself a finding worth reporting.
  - board.json is a view too. It is gitignored; a committed snapshot is a tracking
    file by another name.
  - Never show work as complete before its completion evidence exists.
  - A stale dashboard is worse than none. If you cannot refresh it, say so where
    you record progress — on the board item — and say why.
  - Commit DASHBOARD_FILE only at a phase or ticket boundary, not on
    every refresh, so the diff stays meaningful.
  - Report counts you read, never counts you expect. If REFRESH shows zeros where
    you believed there was work, that is a defect in the board or the config —
    investigate it, do not narrate around it.

WHEN THE NUMBERS LOOK WRONG
  A dashboard reporting "0 in progress" during active work usually means the status
  vocabulary does not match the board's. Check CONFIG's status words against the
  literal strings the adapter emits before concluding the work is untracked.
  `(board: none)` in the header is the other common case, and it means exactly what
  it says: no backend was available, so nothing was read. Check the credentials or
  the snapshot before reading anything into the zeros.
  Prove with: `python3 test/test_status_dashboard.py` and
  `python3 test/test_board_adapters.py`.

FIRST ACTION
  Run REFRESH now and state the current counts before doing anything else. That is
  your baseline, and every later claim of progress is measured against it.
