# Board contract

The harness requires a tracking board. It does not require a *particular* tracking
board. This file is the whole interface: anything that produces the payload below
is a board backend the dashboard, the conductors and the status agent can read.

## Payload

A JSON object with a `tasks` array, or a bare array of the same items.

```json
{
  "backend": "linear",
  "tasks": [
    {
      "id": "SYC-1",
      "title": "Linear board adapter for the status dashboard",
      "status": "In Progress",
      "status_type": "started",
      "group": "Tracking SSOT → Linear",
      "url": "https://linear.app/scull7/issue/SYC-1",
      "labels": ["harness"],
      "depends_on": ["SYC-2"]
    }
  ]
}
```

| Field | Required | Meaning |
|---|---|---|
| `id` | yes | Stable, human-quotable item id. Appears in commits, PR titles, plans. |
| `title` | yes | One line, human-readable. |
| `status` | yes | The board's own status word, for display. |
| `status_type` | no | Canonical lifecycle type. Preferred for classification when present. |
| `group` | no | Workstream / project / epic the item belongs to. Drives the grouped view. |
| `url` | no | Link to the item. An agent that cannot clone the repo still needs to reach it. |
| `labels` | no | Strings. Feeds the label breakdown in `--detail`. |
| `depends_on` | no | Ids that must be done before this item is startable. Feeds ready-vs-blocked. |

Unknown keys are ignored, so a backend may emit more than this.

## Classification

`status_type` is classified first when present, `status` otherwise:

| Bucket | `status_type` | Default `status` words |
|---|---|---|
| done | `completed` | completed, complete, done, verified, merged, shipped |
| active | `started` | in progress, in review, review, building, built, started, wip, regressed |
| todo | anything else | everything else |

A board whose vocabulary differs supplies `status_map` in `dashboard.config.json`.
Do not rename a board's statuses to fit the dashboard; map them.

## Backends

`dashboard.config.json`:

```json
{
  "board": {
    "backend": "auto",
    "file": "board.json",
    "command": ["my-tracker", "list", "--json"],
    "items_path": "tasks",
    "fields": {"id": "id", "title": "title", "status": "status_type",
               "status_label": "status", "group": "group", "url": "url"}
  }
}
```

| `backend` | Behaviour |
|---|---|
| `auto` | Default. Probe `linear`, then `file`. First one available wins; none means no board. |
| `linear` | Run the sibling `scripts/linear-board`. Available when `$LINEAR_API_KEY` or `$LINEAR_TOKEN` is set. |
| `file` | Read `board.file` (default `board.json`) from the project root. |
| `command` | Run `board.command` as an argv list. |
| `none` | No board read at all. |

`command` is run as an argv list, never through a shell, so a config cannot inject
shell syntax — but it does name a program the dashboard will execute. Trust a
`dashboard.config.json` exactly as far as you trust the project's `justfile`.

`fields` maps this contract's names onto whatever the backend emits; values are
dotted paths (`content.title` reaches into a nested payload).

### The `file` backend and MCP

Most agents reach Linear over MCP rather than a CLI, and MCP tools cannot be
called from a shell preflight. Such an agent writes the snapshot itself:

```
# agent, via its Linear MCP tools
list_issues(team: "SYC") → shape into the payload above → write board.json
```

The snapshot is a **view**, exactly like the dashboard. It is regenerated, never
hand-edited, and it is never the source of truth. `board.json` belongs in
`.gitignore`; a committed snapshot is a tracking file by another name, and the
harness has just finished removing those.

## Writes

This contract is read-only. Moving an item, opening one, or recording a
Completion Record happens against the board's own API or UI — the conductor does
it through its Linear MCP tools (or the board's equivalent), not through the
dashboard. Nothing in the harness writes the board on the agent's behalf.
