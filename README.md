# crossr-harness

The CrossR project harness: `HARNESS-SPEC.md`, `harness-bootstrap`, the status dashboard, and the tracking ritual (`features.json`, `progress.md`, `/status`).

It installs pinned tags of [`crossr-skills`](https://github.com/sycamore-hq/crossr-skills) and [`crossr-loops`](https://github.com/sycamore-hq/crossr-loops). It does not own skill text or loop law.

**Extract in progress (split-04).** Tree copied from `sycamore-hq/crossr-skills`. Catalog still ships these files until dual-publish. See [MIGRATION.md](MIGRATION.md).

Charter: [`skills-loops-harness-split.html`](https://github.com/sycamore-hq/crossr-skills/blob/main/docs/plans/skills-loops-harness-split.html).

## What's here

- `HARNESS-SPEC.md` — artifact, ritual, PETC, verification. §12 points at loops; it does not define AVRIL/AXEL.
- `scripts/harness-bootstrap`, `sync-skills`, `status-dashboard`, `verify-docs`, `verify-opencode`
- `templates/harness/` — AGENTS/features templates, `/status` OpenCode bodies, `opencode.jsonc` skeleton
- `dashboard-prompt`, `chief-of-staff`
- `features.schema.json`, `test/harness-bootstrap-smoke.sh`

## Lockfile shape

Not a third tracker. `features.json` remains the work log. After first tags:

```
skills = <tag>
loops  = <tag>
```

See `lockfile.toml.example`. Bootstrap will read this once tags exist (split-08). No git submodules.

`sync-skills` later grows the same two pins. Today it still copies from a local tree.

## OpenCode prompt bodies

`/status` lives here. `/avril` and `/axel` bodies live in [`crossr-loops`](https://github.com/sycamore-hq/crossr-loops) (`templates/harness/opencode/{agent,command}/{avril,axel}.md`). Bootstrap copies both; never overwrites existing `.opencode/`.

## Status recipes (docs, not this remote's forever justfile)

```
status:
    @./scripts/status-dashboard

status-html:
    @./scripts/status-dashboard --html
```

Fragment: `templates/harness/justfile.status`.

## Not here

- Capability skills (`code-writer`, language GAN, BRICK stages, `agent-harness`, `skill-evaluator`) — catalog
- Loop conductors and personas — loops
- `/avril` `/axel` prompt bodies — loops
- `scripts/sync-claude-skills` — catalog
- Public site — landing (split-05)

## Sibling remotes

- [crossr-skills](https://github.com/sycamore-hq/crossr-skills) — catalog
- [crossr-loops](https://github.com/sycamore-hq/crossr-loops) — AVRIL / AXEL / BRICK / GAN
- [crossr-web-landing](https://github.com/sycamore-hq/crossr-web-landing) — public front door
