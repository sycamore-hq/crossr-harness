# HARNESS-SPEC.md

**The official specification for long-running, reliable AI agent harnesses in Nathan Sculli / Tensorwave projects.**

Version: 2.0 (Approved)  
Status: Canonical source of truth for all projects

---

## 1. Purpose

A **harness** is the persistent scaffolding that turns stateless AI coding sessions into reliable, multi-session, self-verifying agents that ship production-grade code with clean handovers.

This specification defines the minimum artifacts, rituals, processes, and patterns that every project must adopt so that:

- Work is incremental and reviewable (< 10 minutes deep review per PR)
- State survives context resets
- Large features can be decomposed safely (see the 16-PR authz chain precedent)
- Claude, Grok, Cursor, and other agentskills.io-compatible tools can all participate
- Security-sensitive and complex work follows the same discipline as simple tasks

Crossr-skills (`.agents/skills/`) are the reusable capability layer. This spec is the **process and artifact layer** that makes those capabilities effective over time.

---

## 2. Core Principles

1. **Strict agentskills.io Compliance**  
   All skills live under `.agents/skills/<name>/SKILL.md` and follow the official specification exactly (YAML frontmatter with `name` + `description`, Markdown body, progressive disclosure).  
   Claude compatibility (`.claude/skills/` and `.claude/commands/`) is **optional** and produced by a generator script — never hand-maintained duplicates. In this repository that generator is `scripts/sync-claude-skills` (`just claude-skills-sync`); `just harness-validate` reports drift between the canonical skills and the generated copies.

2. **Harness Relationship (Stratified) for Skills**  
   Skills are classified as generic/core (fully harness-agnostic) or harness-layer/domain (with a clean `## Harness Context (Stratified Disclosure)` block that isolates concrete artifact names, commands, and project examples as parameters supplied by the invoking harness). The canonical portable structure (YAML frontmatter, Verification with 6 observable behaviors, Specialization, One-Sentence Mandate, clean footer) is required for all skills. The `skill-evaluator` skill (and its permanent GAN personas) is the authority. This principle was proven and locked in during the 2026 skill-remediation campaign on this repository.

3. **Incremental & Reviewable by Design**  
   Every unit of work must be reviewable in under 10 minutes. Large features are decomposed into stacked, small PRs with explicit traceability.

3. **Multi-Tier Verification Harnesses**  
   "Harness" is not just meta — we literally build verification harnesses at multiple tiers (in-process, parity snapshots, real substrate VM/k8s, etc.).

4. **Traceability & Reviewability**  
   Every significant piece of work carries stable IDs (tw-xxx, ADR-0002, Phase N, CD-1873, etc.) in code comments, tests, PR titles, and progress tracking.

5. **Policy Gates Before Effects**  
   Security and correctness gates (especially mTLS CN-hostname binding, authz checks, etc.) must be enforced *before* any database lookup or side-effecting operation.

6. **Self-Verifying Handovers**  
   No session ends without tests, clippy, reviewer/tester/architect sign-off (GAN), and clean git state + updated artifacts.

---

## 3. Mandatory Artifacts (Every Project)

### 3.1 `AGENTS.md` (or `CLAUDE.md` / `AGENT.md`)

Project-specific rules file. Must contain:

- Reference to the skills in `.agents/skills/` (with activation examples)
- The **Plan Mode** contract:
  - Plans must be extremely concise
  - Every plan ends with a bulleted list of unresolved questions
- Link to this `HARNESS-SPEC.md`

### 3.2 `features.json`

Machine-readable work tracking. Real production shape (proven on ferro-wg and the 16-PR authz chain):

```json
{
  "phase7": {
    "status": "in_progress",
    "commits": [
      {
        "id": "commit3",
        "title": "Help overlay component",
        "status": "completed",
        "features": ["help_overlay_component", "help_overlay_tests", "keybindings_constant"]
      }
    ]
  },
  "review_remediation": { ... }
}
```

**Requirements**:
- Phases or major workstreams as top-level keys
- Each commit has stable `id`, human `title`, `status`, and array of granular `features` (these become the atomic units of traceability)
- A companion JSON Schema (`features.schema.json`) + validation step in the bootstrap/ritual

### 3.3 `progress.md`

Human-readable, commit-narrative log. Structure:

```markdown
# Phase 7: UX Polish — Implementation Progress

## Completed Phases

### Commit 3: Help overlay component (COMPLETED)
- ...
- All tests pass, clippy clean, no warnings

## Verification Status
- Tooling checks: PASSED
- Adversary reviews: PASSED (reviewer + tester + architect)
```

Append after every commit. Never rewrite history.

### 3.4 `justfile` (or `init.sh` + `Makefile`)

Canonical one-command entry points for the exact build/test/clippy matrices that appear in `CLAUDE.md` and CI. Agents always run the justfile targets.

### 3.5 Git Hygiene + Session Ritual

At the start of every session the agent **must** execute (at minimum):

```bash
git status
git log --oneline -10
cat progress.md | tail -n 30
# jq for pending work in the new features.json shape
./init.sh || just init
cargo check && cargo test --quiet
```

### 3.6 `.agents/skills/` (Canonical)

All reusable skills live here in strict `agentskills.io` format. This directory is the single source of truth.

---

## 4. Strongly Recommended Artifacts

- `CLAUDE.md` (root + per-workspace) with exact cargo matrices, platform notes, and "format first" rules
- `docs/phase-*.md` or `docs/IMPLEMENTATION_*.md` for larger bodies of work
- `.github/workflows/ci.yml` that mirrors the exact checks in CLAUDE.md
- `rust-toolchain.toml` + `install.sh`
- `tests/` crates or harnesses at multiple tiers (the authz pattern)
- `deploy-guide/` or equivalent beautiful, self-contained operator documentation (can be a single-file static webapp)

---

## 4.4 Choosing a Delivery Pipeline

Two pipelines are supported. They are peers; neither is the default, and the human picks per unit of work.

**AVRIL → AXEL** takes a blessed backlog and earns its guarantees through adversarial argument: PO/QA/CTO bless each PBI, then Reviewer/Tester/Architect bless each phase. Use it when scope is still being discovered.

**BRICK** takes one informal specification and earns its guarantees through transformation: prose → tasks → Gherkin → acceptance and unit tests → implementation → refactor with property tests → mutation testing with zero survivors. Use it when behaviour can be written down before it is built and correctness must be provable.

Do not run both on the same work at once. AVRIL's source of truth is a blessed backlog; BRICK's is a `.feature` file. Reconciling two sources of truth mid-flight costs more than either pipeline saves. Switch between units of work, never inside one, and record which pipeline a unit used so a later reader knows which guarantees apply.

BRICK's mutation gate is a hard requirement, not a recommendation. The tool is a harness parameter (`cargo-mutants`, `mutmut`, Stryker, or equivalent); if none is disclosed, BRICK stops rather than certifying an unverified run.

Normative loop law (AVRIL/AXEL/BRICK cycles, blessing language, intake gates) lives in [`crossr-loops`](https://github.com/sycamore-hq/crossr-loops). This section only chooses a pipeline.

## 4.5 HTML as the Primary Human-Facing Artifact Format

For any artifact whose primary audience is a human — specifications, architecture reviews, PR summaries, reports, dashboards, prototypes, deployment guides, etc. — **generate a self-contained HTML file** as the main deliverable.

The canonical example is the **orchestration status dashboard**: every orchestration skill keeps a live completed / in-progress / todo view of its own work, rendered by a generator from the harness's tracking artifacts (`scripts/status-dashboard`; `just status` for the terminal, `just status-html` for the HTML). It is generated, never hand-written, and never the source of truth.

**Rationale (The Unreasonable Effectiveness of HTML)**:
- Humans read, understand, and engage with well-designed HTML far more effectively than raw Markdown.
- Modern models produce exceptionally high-quality, single-file HTML (Tailwind via CDN + SVG/light JS) with very little prompting.
- This dramatically improves the quality of human-in-the-loop feedback in the harness.

**Guidelines**:
- Output a single `.html` file (fully self-contained, no local dependencies).
- Use Tailwind CSS via CDN for rapid, clean styling.
- Make the document scannable, visually rich, and interactive where it adds value.
- You may also produce a Markdown version for git or agent handoff, but treat the HTML as the primary human artifact.
- Name files descriptively (e.g., `architecture-review.html`, `pr-42-summary.html`).

This pattern is now a first-class recommendation in the harness.

---

## 5. The PETC Loop + Stacked PR Discipline

**P**lan → **E**xecute → **T**est → **C**ommit

- Plan is written first, is concise, and ends with unresolved questions.
- Every commit is a small, reviewable unit.
- Large features (see CD-1873 authz) are decomposed into 10–16 stacked PRs, each with explicit "this / next / verification".
- Traceability IDs appear in code, tests, PR titles, and features.json.

---

## 6. Verification Gates (Non-Negotiable)

Before a commit is considered done:

1. Self-critique + full test matrix + clippy (pedantic) + fmt
2. `code-review` ruthless pass
3. `testing` coverage + exhaustive error path pass
4. `architecture` architectural sign-off

Only after all four layers pass is the commit + artifacts updated.

---

## 7. Claude & Other Tool Compatibility

- The canonical skills are always in `.agents/skills/`.
- A `generate-claude-compat` (or equivalent) step in the bootstrap/harness script can derive:
  - `.claude/skills/<name>/SKILL.md` (full copy or symlink)
  - `.claude/commands/rust-*.md` (distilled, slash-command friendly versions)
- Projects may commit the generated files or gitignore them. The generator is the source of truth for keeping them in sync.

---

## 8. Bootstrap & Adoption

Every new project runs (or the human runs):

```bash
./scripts/harness-bootstrap .          # or the equivalent script
```

This produces a minimal but complete starting harness (AGENTS.md, features.json with phase 0, justfile, progress.md stub, `.agents/skills/` from the lockfile pins, OpenCode `/avril` `/axel` `/status`).

Pins live in `lockfile.toml` (not a third tracker — `features.json` remains the work log):

```
skills = "<tag>"
loops  = "<tag>"
books  = ["rust"]     # disclosed language books; ["ocaml"], ["rust", "ts"], ...
```

`books` is a disclosure filter, not a copy filter. `harness-bootstrap` copies every skill directory that has a `SKILL.md` and does not read `books`. Do not later turn bootstrap into a partial copy. Language consumers declare `books`; loops and this remote do not (absence of the key is not a failure). See §11 for how a session reads the list.

Bootstrap copies catalog skills from the skills tag, loop conductors + personas + `/avril` `/axel` from the loops tag, and harness templates from this remote, then generates `.opencode/agent/` from the copied personas. Never overwrites a `.opencode/` file that lacks the generated marker; marked files are regenerated every run. No git submodules. `--process-only` writes tracking files without copying skills (product-repo dogfood).

After the first commit of the empty harness, all future work is tracked inside it.

---

## 9. Special Patterns Proven at Scale (Authz Chain)

- **Stacked small PRs** for high-risk security work
- **Literal "verification harnesses"** at multiple fidelity levels
- **Policy gate before any effect** (mTLS CN-hostname check before Mongo lookup)
- **Distinct error semantics** for policy denials vs operational failures
- **Reviewability comments** and ticket linkage in almost every changed file
- **Decoupled documentation PR** so docs never block code

These patterns are now part of the expected discipline for any comparably large or sensitive feature.

---

## 10. Versioning & Evolution

This spec lives at the root of crossr-harness as `HARNESS-SPEC.md`.  
Changes are proposed via the same harness process the spec itself defines (features.json entries, small reviewable PRs, full verification gates).

## 11. Agent Definitions (GAN Mechanization)

As of the 2026 GAN mechanization effort, reusable agent personas live in `.agents/agents/`.

The canonical trio for quality enforcement is:
- `reviewer-agent`
- `tester-agent`
- `architect-agent`

Projects are encouraged to run the full GAN sequence (Reviewer → Tester → Architect) on significant changes. See `.agents/agents/README.md` for the recommended invocation pattern. Loop personas (AVRIL quartet, AXEL conductor, BRICK stage agents) are supplied by [`crossr-loops`](https://github.com/sycamore-hq/crossr-loops).

The book is disclosed per project. A consumer `lockfile.toml` may carry `books = ["rust"]` (or `["ocaml"]`, `["rust", "ts"]`, ...). The lockfile parser accepts that key. AXEL pre-flight step 4 reads it and states the language stack:

- Generator loads `code-writer` + the disclosed book (card + the references for the situation) + domain skills
- Adversaries load the gate card + `<book>/RULES.md`. Never `<book>/references/`
- Test verifier: rules tagged `test` in that same `RULES.md`

When more than one book is listed, the session discloses which applies per PBI. If unspecified, stop and ask. Do not default to first-listed. When a language consumer's `books` is missing or empty, stop and ask.

An explicit `books = []` on a consumer lockfile fails `verify-skill-refs` when a graph has `requires.book: true`. Absence of the key is not a failure. Loops is not a language consumer and does not carry `books`.

## 12. Loops (supplied, not defined here)

AVRIL, AXEL, and BRICK are **loop law**. They live in [`crossr-loops`](https://github.com/sycamore-hq/crossr-loops). This spec does not define their cycles, blessing language, or intake gates. A copy of this spec that still spells out AVRIL's adversary order or AXEL's per-PBI loop is stale — read the loops remote.

The harness **discloses** (stratified parameters at activation):

- Board backend (Pinto preferred when `.pinto/` exists; otherwise the project's backlog path)
- Tracking artifacts (`features.json`, `progress.md`)
- Ritual (`just` targets, session start, verification matrix)
- Dashboard command (`just status` / `just status-html` / `/status`)

Bootstrap installs pinned tags of the two catalogs. Not a third tracker — `features.json` remains the work log:

```
skills = <tag>
loops  = <tag>
books  = ["rust"]     # language consumers only; disclosure, not a copy filter
```

Conductor SKILL.md and loop personas come from the loops pin. Capability SKILL.md comes from the skills pin. Never git submodules.

---

**Whatever you do, work at it with all your heart, as working for the Lord.** — Colossians 3:23

This harness exists so that we can ship excellent, reliable software without burning out our agents or ourselves. Use it with discipline and joy.