#!/usr/bin/env bash
# Smoke test for harness-bootstrap (split-08 pins; PR 2b generated agents).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP="$SCRIPT_DIR/scripts/harness-bootstrap"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "Testing --process-only..."
"$BOOTSTRAP" --process-only "$TMPDIR/proc" > /dev/null
for f in AGENTS.md features.json progress.md justfile lockfile.toml; do
    if [ ! -f "$TMPDIR/proc/$f" ]; then
        echo "✗ process-only missing $f"
        exit 1
    fi
done
if grep -q 'skills = "v1-gan-layers"' "$TMPDIR/proc/lockfile.toml" \
   && grep -q 'loops  = "v1-no-rtl"' "$TMPDIR/proc/lockfile.toml"; then
    echo "✓ process-only wrote tracking files + pins"
else
    echo "✗ process-only lockfile pins wrong"
    cat "$TMPDIR/proc/lockfile.toml"
    exit 1
fi

echo "Testing process-only idempotency (keeps AGENTS.md)..."
echo "marker" >> "$TMPDIR/proc/AGENTS.md"
"$BOOTSTRAP" --process-only "$TMPDIR/proc" > /dev/null
if grep -q marker "$TMPDIR/proc/AGENTS.md"; then
    echo "✓ process-only did not overwrite AGENTS.md"
else
    echo "✗ process-only overwrote AGENTS.md"
    exit 1
fi

echo "Testing full bootstrap from pins..."
"$BOOTSTRAP" "$TMPDIR/full" > "$TMPDIR/full.log"
if [ ! -f "$TMPDIR/full/.agents/skills/code-writer/SKILL.md" ]; then
    echo "✗ missing catalog skill code-writer"
    tail -20 "$TMPDIR/full.log"
    exit 1
fi
if [ ! -f "$TMPDIR/full/.agents/skills/avril/SKILL.md" ]; then
    echo "✗ missing loops conductor avril"
    tail -20 "$TMPDIR/full.log"
    exit 1
fi
if [ ! -f "$TMPDIR/full/.opencode/agent/status.md" ]; then
    echo "✗ missing /status from harness"
    exit 1
fi
if [ ! -f "$TMPDIR/full/.opencode/agent/avril.md" ]; then
    echo "✗ missing /avril from loops"
    exit 1
fi
if [ ! -f "$TMPDIR/full/.agents/skills/dashboard-prompt/SKILL.md" ]; then
    echo "✗ missing dashboard-prompt from harness"
    exit 1
fi
if [ ! -f "$TMPDIR/full/HARNESS-SPEC.md" ]; then
    echo "✗ missing HARNESS-SPEC.md"
    exit 1
fi
echo "✓ full bootstrap installed catalog + loops + harness files"

if grep -q 'orphan persona' "$TMPDIR/full.log"; then
    echo "✗ orphan persona warning on fresh target"
    grep 'orphan persona' "$TMPDIR/full.log"
    exit 1
fi
echo "✓ fresh target has no orphan persona warnings"

if [ -d "$TMPDIR/full/.agents/skills/rust-team-lead" ]; then
    echo "✗ rust-team-lead skill installed from new pins"
    exit 1
fi
if [ ! -f "$TMPDIR/full/.opencode/agent/axel.md" ]; then
    echo "✗ missing generated axel.md"
    exit 1
fi
if ! grep -qF '`axel`' "$TMPDIR/full/.opencode/agent/axel.md" \
   || ! grep -qF '`gan-verdict`' "$TMPDIR/full/.opencode/agent/axel.md"; then
    echo "✗ generated axel.md is not the lean load set (axel + gan-verdict)"
    tail -20 "$TMPDIR/full/.opencode/agent/axel.md"
    exit 1
fi
if grep -qF 'rust-team-lead' "$TMPDIR/full/.opencode/agent/axel.md"; then
    echo "✗ generated axel.md still names rust-team-lead"
    exit 1
fi
echo "✓ generated conductor is lean (axel + gan-verdict)"

echo "Testing full idempotency (does not clobber unmarked .opencode)..."
echo "kept" >> "$TMPDIR/full/.opencode/agent/avril.md"
"$BOOTSTRAP" "$TMPDIR/full" > /dev/null
if grep -q kept "$TMPDIR/full/.opencode/agent/avril.md"; then
    echo "✓ second run kept unmarked .opencode/agent/avril.md"
else
    echo "✗ second run overwrote unmarked .opencode"
    exit 1
fi

echo "Testing unknown --force is rejected..."
if "$BOOTSTRAP" --force "$TMPDIR/x" > /dev/null 2>&1; then
    echo "✗ --force should exit 2"
    exit 1
fi
echo "✓ --force rejected"

GEN="$SCRIPT_DIR/scripts/generate-opencode-agent"

echo "Testing generate-opencode-agent name mapping..."
map_ok=0
for spec in \
    "axel-conductor-agent.md:axel" \
    "avril-conductor-agent.md:avril" \
    "reviewer-agent.md:reviewer-agent" \
    "tester-agent.md:tester-agent" \
    "architect-agent.md:architect-agent" \
    "planning-architect-agent.md:planning-architect-agent"
do
    name="${spec%%:*}"
    want="${spec##*:}"
    got="$("$GEN" --name "/tmp/$name")"
    if [ "$got" != "$want" ]; then
        echo "✗ name map $name → $got (want $want)"
        exit 1
    fi
    map_ok=$((map_ok + 1))
done
echo "✓ name mapping ($map_ok cases)"

# Fixture trees — no network. Personas use the PR 2a role names.
FIX="$TMPDIR/fix"
mkdir -p "$FIX/skills/.agents/skills/dummy"
cat > "$FIX/skills/.agents/skills/dummy/SKILL.md" << 'EOF'
---
name: dummy
description: fixture skill
---
# dummy
EOF

mkdir -p "$FIX/loops/.agents/agents" "$FIX/loops/templates/harness/opencode/agent"

cat > "$FIX/loops/.agents/agents/axel-conductor-agent.md" << 'EOF'
# axel-conductor-agent

**Role**: Conductor of the AXEL execution loop — fixture body.

Persona body line unique to the conductor source.
EOF

cat > "$FIX/loops/.agents/agents/reviewer-agent.md" << 'EOF'
# reviewer-agent

**Role**: Reviewer gate — fixture.

Reviewer persona body.
EOF

cat > "$FIX/loops/.agents/agents/tester-agent.md" << 'EOF'
# tester-agent

**Role**: Tester gate — fixture.

Tester persona body.
EOF

cat > "$FIX/loops/.agents/agents/architect-agent.md" << 'EOF'
# architect-agent

**Role**: Architect gate — fixture.

Architect persona body.
EOF

cat > "$FIX/loops/.agents/agents/override-agent.md" << 'EOF'
---
description: "passed through"
mode: primary
color: "#00ff00"
---
# override-agent

Override body. This persona carries its own frontmatter.
EOF

cat > "$FIX/loops/templates/harness/opencode/agent/axel.md" << 'EOF'
---
description: TEMPLATE AXEL — must be replaced by generation
mode: primary
---
TEMPLATE AXEL BODY
EOF

cat > "$FIX/loops/templates/harness/opencode/agent/avril.md" << 'EOF'
---
description: AVRIL template
mode: primary
---
TEMPLATE AVRIL BODY
EOF

mkdir -p "$FIX/target/.opencode/agent"
printf '%s\n' 'HANDWRITTEN STATUS' > "$FIX/target/.opencode/agent/status.md"
printf '%s\n' 'HANDWRITTEN AVRIL' > "$FIX/target/.opencode/agent/avril.md"
cat > "$FIX/target/lockfile.toml" << 'EOF'
skills = "v0-last-monolith"
loops  = "v1-runtime-agents"
EOF

echo "Testing generation from fixture personas..."
CROSSR_SKILLS_PATH="$FIX/skills" CROSSR_LOOPS_PATH="$FIX/loops" \
    "$BOOTSTRAP" "$FIX/target" > "$FIX/boot1.log"

fail_gen() { echo "✗ $1"; tail -20 "$FIX/boot1.log"; exit 1; }

[ -f "$FIX/target/.opencode/agent/axel.md" ] || fail_gen "missing generated axel.md"
[ -f "$FIX/target/.opencode/agent/reviewer-agent.md" ] || fail_gen "missing reviewer-agent.md"
[ -f "$FIX/target/.opencode/agent/tester-agent.md" ] || fail_gen "missing tester-agent.md"
[ -f "$FIX/target/.opencode/agent/architect-agent.md" ] || fail_gen "missing architect-agent.md"
[ -f "$FIX/target/.opencode/agent/override-agent.md" ] || fail_gen "missing override-agent.md"
echo "✓ generation produced conductor + adversary agent files"

for f in axel.md reviewer-agent.md tester-agent.md architect-agent.md override-agent.md; do
    if ! grep -qF "by harness-bootstrap — do not edit -->" "$FIX/target/.opencode/agent/$f"; then
        echo "✗ missing generated marker in $f"
        exit 1
    fi
done
echo "✓ generated marker present on every generated agent file"

if grep -q "TEMPLATE AXEL BODY" "$FIX/target/.opencode/agent/axel.md"; then
    echo "✗ axel.md still has template body"
    exit 1
fi
if ! grep -q "Persona body line unique to the conductor source." "$FIX/target/.opencode/agent/axel.md"; then
    echo "✗ axel.md missing conductor persona body"
    exit 1
fi
if ! grep -qE '^mode: primary$' "$FIX/target/.opencode/agent/axel.md"; then
    echo "✗ axel.md is not mode: primary"
    exit 1
fi
if ! grep -qE '^  edit: ask$' "$FIX/target/.opencode/agent/axel.md"; then
    echo "✗ axel.md missing conductor edit: ask"
    exit 1
fi
echo "✓ axel.md is primary, conductor permissions, persona body"

for f in reviewer-agent.md tester-agent.md architect-agent.md; do
    if ! grep -qE '^mode: subagent$' "$FIX/target/.opencode/agent/$f"; then
        echo "✗ $f is not mode: subagent"
        exit 1
    fi
    if ! grep -qE '^  edit: deny$' "$FIX/target/.opencode/agent/$f"; then
        echo "✗ $f missing edit: deny"
        exit 1
    fi
done
echo "✓ adversary agents are subagent + read-only"

if ! grep -qE '^mode: primary$' "$FIX/target/.opencode/agent/override-agent.md" \
   || ! grep -qE '^color: "#00ff00"$' "$FIX/target/.opencode/agent/override-agent.md" \
   || ! grep -q "Override body." "$FIX/target/.opencode/agent/override-agent.md"; then
    echo "✗ persona frontmatter override not passed through"
    cat "$FIX/target/.opencode/agent/override-agent.md"
    exit 1
fi
echo "✓ persona frontmatter override passed through"

if ! grep -qx 'HANDWRITTEN STATUS' "$FIX/target/.opencode/agent/status.md"; then
    echo "✗ hand-written status.md was touched"
    exit 1
fi
if ! grep -qx 'HANDWRITTEN AVRIL' "$FIX/target/.opencode/agent/avril.md"; then
    echo "✗ hand-written avril.md was touched"
    exit 1
fi
echo "✓ hand-written status.md and avril.md untouched"

echo "MUTATED" >> "$FIX/target/.opencode/agent/reviewer-agent.md"
CROSSR_SKILLS_PATH="$FIX/skills" CROSSR_LOOPS_PATH="$FIX/loops" \
    "$BOOTSTRAP" "$FIX/target" > /dev/null
if grep -q MUTATED "$FIX/target/.opencode/agent/reviewer-agent.md"; then
    echo "✗ marked reviewer-agent.md was not regenerated"
    exit 1
fi
if ! grep -q "Reviewer persona body." "$FIX/target/.opencode/agent/reviewer-agent.md"; then
    echo "✗ regenerated reviewer-agent.md lost persona body"
    exit 1
fi
echo "✓ regeneration overwrites marked files"

echo "still-handwritten" >> "$FIX/target/.opencode/agent/avril.md"
CROSSR_SKILLS_PATH="$FIX/skills" CROSSR_LOOPS_PATH="$FIX/loops" \
    "$BOOTSTRAP" "$FIX/target" > /dev/null
if ! grep -q still-handwritten "$FIX/target/.opencode/agent/avril.md"; then
    echo "✗ unmarked avril.md overwritten on later run"
    exit 1
fi
echo "✓ unmarked files stay untouched across regeneration"

# Restore avril.md to a known byte so the snapshot compare is clean.
printf '%s\n' 'HANDWRITTEN AVRIL' > "$FIX/target/.opencode/agent/avril.md"

echo "Testing second run is a no-op (byte-identical tree)..."
cp -a "$FIX/target/.opencode" "$FIX/snap-opencode"
cp -a "$FIX/target/.agents" "$FIX/snap-agents"
CROSSR_SKILLS_PATH="$FIX/skills" CROSSR_LOOPS_PATH="$FIX/loops" \
    "$BOOTSTRAP" "$FIX/target" > /dev/null
if ! diff -rq "$FIX/snap-opencode" "$FIX/target/.opencode" >/dev/null; then
    echo "✗ second run changed .opencode/"
    diff -rq "$FIX/snap-opencode" "$FIX/target/.opencode" || true
    exit 1
fi
if ! diff -rq "$FIX/snap-agents" "$FIX/target/.agents" >/dev/null; then
    echo "✗ second run changed .agents/"
    exit 1
fi
echo "✓ second run is a no-op"

mkdir -p "$FIX/custom/.opencode/agent"
printf '%s\n' 'CUSTOM AXEL' > "$FIX/custom/.opencode/agent/axel.md"
cat > "$FIX/custom/lockfile.toml" << 'EOF'
skills = "v0-last-monolith"
loops  = "v1-runtime-agents"
EOF
CROSSR_SKILLS_PATH="$FIX/skills" CROSSR_LOOPS_PATH="$FIX/loops" \
    "$BOOTSTRAP" "$FIX/custom" > /dev/null
if ! grep -qx 'CUSTOM AXEL' "$FIX/custom/.opencode/agent/axel.md"; then
    echo "✗ pre-existing unmarked axel.md was overwritten"
    exit 1
fi
echo "✓ pre-existing unmarked axel.md kept (no persona-source exception)"

echo "Testing quoted marker in a hand-written body does not clobber..."
mkdir -p "$FIX/quote/.opencode/agent" "$FIX/quote/.agents/agents"
# Pre-seed an unmarked axel.md that *quotes* the marker in its body.
cat > "$FIX/quote/.opencode/agent/axel.md" << 'EOF'
---
description: hand-written
mode: primary
---
Do not treat this quote as ownership:
<!-- GENERATED from .agents/agents/axel-conductor-agent.md by harness-bootstrap — do not edit -->
CUSTOM QUOTED
EOF
cat > "$FIX/quote/lockfile.toml" << 'EOF'
skills = "v0-last-monolith"
loops  = "v1-runtime-agents"
EOF
CROSSR_SKILLS_PATH="$FIX/skills" CROSSR_LOOPS_PATH="$FIX/loops" \
    "$BOOTSTRAP" "$FIX/quote" > /dev/null
if ! grep -q CUSTOM\ QUOTED "$FIX/quote/.opencode/agent/axel.md"; then
    echo "✗ quoting the marker in a hand-written body caused overwrite"
    exit 1
fi
echo "✓ quoted marker in body does not make a file machine-owned"

echo "Testing orphan persona warning (copy_agents keep + pin rename)..."
mkdir -p "$FIX/orphan/.agents/agents"
cat > "$FIX/orphan/.agents/agents/rust-reviewer-agent.md" << 'EOF'
# rust-reviewer-agent

**Role**: Stale leftover from v0.

Old reviewer voice.
EOF
cat > "$FIX/orphan/lockfile.toml" << 'EOF'
skills = "v0-last-monolith"
loops  = "v1-runtime-agents"
EOF
CROSSR_SKILLS_PATH="$FIX/skills" CROSSR_LOOPS_PATH="$FIX/loops" \
    "$BOOTSTRAP" "$FIX/orphan" > "$FIX/orphan.log"
if ! grep -q 'orphan persona rust-reviewer-agent.md' "$FIX/orphan.log"; then
    echo "✗ missing orphan warning for rust-reviewer-agent.md"
    cat "$FIX/orphan.log"
    exit 1
fi
if [ ! -f "$FIX/orphan/.opencode/agent/rust-reviewer-agent.md" ]; then
    echo "✗ orphan persona did not still generate an agent"
    exit 1
fi
if [ ! -f "$FIX/orphan/.opencode/agent/reviewer-agent.md" ]; then
    echo "✗ pin reviewer-agent.md was not also generated"
    exit 1
fi
echo "✓ orphan warning fired; both stale and current reviewer agents exist"

echo "Testing generator determinism..."
"$GEN" "$FIX/loops/.agents/agents/axel-conductor-agent.md" > "$FIX/g1"
"$GEN" "$FIX/loops/.agents/agents/axel-conductor-agent.md" > "$FIX/g2"
if ! cmp -s "$FIX/g1" "$FIX/g2"; then
    echo "✗ generator is not deterministic"
    exit 1
fi
if grep -qiE '20[0-9]{2}-[0-9]{2}-[0-9]{2}|T[0-9]{2}:[0-9]{2}' "$FIX/g1"; then
    echo "✗ generator output contains a timestamp"
    exit 1
fi
echo "✓ generator is deterministic and timestamp-free"

echo "✓ All smoke tests passed"
