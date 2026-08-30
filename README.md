# crossr-harness

The CrossR project harness: `HARNESS-SPEC.md`, `harness-bootstrap`, the status dashboard, and the tracking ritual (`features.json`, `progress.md`, `/status`).

It installs pinned tags of [`crossr-skills`](https://github.com/sycamore-hq/crossr-skills) and [`crossr-loops`](https://github.com/sycamore-hq/crossr-loops). It does not own skill text or loop law.

**Dogfood is live (split-08).** Pins: `skills = "v0-last-monolith"`, `loops = "v0"`. See [lockfile.toml](lockfile.toml).

Charter: [`skills-loops-harness-split.html`](https://github.com/sycamore-hq/crossr-skills/blob/main/docs/plans/skills-loops-harness-split.html).

## New project

```bash
git clone https://github.com/sycamore-hq/crossr-harness.git
./crossr-harness/scripts/harness-bootstrap /path/to/your-project
```

Copies catalog skills from the skills tag, loop conductors + personas + `/avril` `/axel` from the loops tag, and harness templates (`/status`, `HARNESS-SPEC.md`, dashboard). Then generates `.opencode/agent/` from `.agents/agents/` personas. Never overwrites a `.opencode/` file that lacks the generated marker; marked files are regenerated every run. No git submodules.

**Graphs (split-09)** live on [`crossr-loops` `main`](https://github.com/sycamore-hq/crossr-loops/tree/main/graphs), not in pin `v0`. Bootstrap does not copy `graphs/`. Topology only — SKILL.md stays the law.

`--process-only` writes `AGENTS.md`, `features.json`, `progress.md`, `justfile`, `lockfile.toml` without copying skills (how the three product remotes consume this harness).

## Lockfile

Not a third tracker. `features.json` remains the work log.

```
skills = "v0-last-monolith"
loops  = "v0"
```

`sync-skills` with no path clones the skills pin. `CROSSR_SKILLS_PATH` / `CROSSR_LOOPS_PATH` skip the clone.

## What's here (product source)

- `HARNESS-SPEC.md` — artifact, ritual, PETC, verification. §12 points at loops; it does not define AVRIL/AXEL.
- `scripts/harness-bootstrap`, `generate-opencode-agent`, `sync-skills`, `status-dashboard`, `verify-docs`, `verify-opencode`
- `templates/harness/` — AGENTS/features templates, `/status` OpenCode bodies, `opencode.jsonc` skeleton
- `dashboard-prompt`, `chief-of-staff`
- `features.schema.json`, `test/harness-bootstrap-smoke.sh`

Consumer tracking files (`AGENTS.md`, `features.json`, `progress.md`, `justfile`) are a dogfood instance, not the product source.

## OpenCode prompt bodies

`/status` lives here. `/avril` and `/axel` bodies live in [`crossr-loops`](https://github.com/sycamore-hq/crossr-loops). Bootstrap copies both.

## Not here

- Capability skills (`code-writer`, language GAN, BRICK stages, `agent-harness`, `skill-evaluator`) — catalog
- Loop conductors and personas — loops
- `/avril` `/axel` prompt bodies — loops
- `scripts/sync-claude-skills` — catalog
- Public site — landing

## Sibling remotes

- [crossr-skills](https://github.com/sycamore-hq/crossr-skills) — catalog
- [crossr-loops](https://github.com/sycamore-hq/crossr-loops) — AVRIL / AXEL / BRICK / GAN
- [crossr-web-landing](https://github.com/sycamore-hq/crossr-web-landing) — public front door
