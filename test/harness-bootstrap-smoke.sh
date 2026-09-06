#!/usr/bin/env bash
# Smoke test for harness-bootstrap (PR 5e pins + books disclosure).

set -euo pipefail

python3 -c 'import tomllib' 2>/dev/null || {
    echo "Error: harness-bootstrap-smoke needs python3 >= 3.11 (tomllib)" >&2
    exit 1
}

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
if grep -q 'skills = "v1-one-law"' "$TMPDIR/proc/lockfile.toml" \
   && grep -q 'loops  = "v1-one-law-consumers"' "$TMPDIR/proc/lockfile.toml"; then
    echo "✓ process-only wrote tracking files + pins"
else
    echo "✗ process-only lockfile pins wrong"
    cat "$TMPDIR/proc/lockfile.toml"
    exit 1
fi

echo "Testing python3 < 3.11 fails loud..."
REAL_PY="$(command -v python3)"
mkdir -p "$TMPDIR/oldpy"
cat > "$TMPDIR/oldpy/python3" << EOF
#!/usr/bin/env bash
if [ "\${1:-}" = "-c" ] && [ "\${2:-}" = "import tomllib" ]; then
    exit 1
fi
exec "$REAL_PY" "\$@"
EOF
chmod +x "$TMPDIR/oldpy/python3"
set +e
PATH="$TMPDIR/oldpy:$PATH" "$BOOTSTRAP" --process-only "$TMPDIR/oldpy-target" \
    > "$TMPDIR/oldpy.out" 2> "$TMPDIR/oldpy.err"
oldpy_rc=$?
set -e
if [ "$oldpy_rc" -eq 0 ]; then
    echo "✗ missing tomllib should exit 1"
    cat "$TMPDIR/oldpy.err"
    exit 1
fi
if [ "$(grep -c '^Error:' "$TMPDIR/oldpy.err")" -ne 1 ]; then
    echo "✗ want exactly one Error: line for old python"
    cat "$TMPDIR/oldpy.err"
    exit 1
fi
if ! grep -q 'python3 >= 3.11' "$TMPDIR/oldpy.err"; then
    echo "✗ old-python error did not name the version floor"
    cat "$TMPDIR/oldpy.err"
    exit 1
fi
echo "✓ python3 < 3.11 is one Error: line"

echo "Testing invalid lockfile is one-line error..."
mkdir -p "$TMPDIR/bad-toml"
printf '%s\n' 'skills = "v1-one-law"' 'loops  = "v1-one-law-consumers"' 'books = ["rust"' \
    > "$TMPDIR/bad-toml/lockfile.toml"
set +e
"$BOOTSTRAP" --process-only "$TMPDIR/bad-toml" > "$TMPDIR/bad-toml.out" 2> "$TMPDIR/bad-toml.err"
bad_rc=$?
set -e
if [ "$bad_rc" -eq 0 ]; then
    echo "✗ invalid TOML should exit 1"
    cat "$TMPDIR/bad-toml.err"
    exit 1
fi
if [ "$(grep -c '^Error:' "$TMPDIR/bad-toml.err")" -ne 1 ]; then
    echo "✗ want exactly one Error: line for invalid TOML"
    cat "$TMPDIR/bad-toml.err"
    exit 1
fi
if ! grep -q "Error: $TMPDIR/bad-toml/lockfile.toml: invalid TOML:" "$TMPDIR/bad-toml.err"; then
    echo "✗ error did not name the file as invalid TOML"
    cat "$TMPDIR/bad-toml.err"
    exit 1
fi
if grep -qiE 'Traceback|TOMLDecodeError' "$TMPDIR/bad-toml.err"; then
    echo "✗ traceback leaked on invalid TOML"
    cat "$TMPDIR/bad-toml.err"
    exit 1
fi
echo "✓ invalid lockfile is one Error: line (no traceback)"

echo "Testing example lockfile books..."
python3 - "$SCRIPT_DIR/lockfile.toml.example" <<'PY'
import sys, tomllib
with open(sys.argv[1], "rb") as f:
    data = tomllib.load(f)
books = data.get("books")
if not isinstance(books, list) or not books or not all(isinstance(b, str) for b in books):
    print("✗ lockfile.toml.example books must be a non-empty array of strings")
    sys.exit(1)
print("✓ example lockfile books =", books)
PY

echo "Testing lockfile parser accepts books..."
mkdir -p "$TMPDIR/with-books"
cp "$SCRIPT_DIR/lockfile.toml.example" "$TMPDIR/with-books/lockfile.toml"
"$BOOTSTRAP" --process-only "$TMPDIR/with-books" > "$TMPDIR/with-books.log"
if ! grep -q 'Books: \["rust"\]' "$TMPDIR/with-books.log"; then
    echo "✗ bootstrap did not accept lockfile books"
    cat "$TMPDIR/with-books.log"
    exit 1
fi
if ! grep -q 'books  = \["rust"\]' "$TMPDIR/with-books/lockfile.toml"; then
    echo "✗ process-only dropped books from an existing lockfile"
    cat "$TMPDIR/with-books/lockfile.toml"
    exit 1
fi
echo "✓ lockfile parser accepts books (reader i)"

echo "Testing process-only writes books from example lockfile onto a fresh target..."
FAKE_ROOT="$TMPDIR/harness-src"
mkdir -p "$FAKE_ROOT/scripts"
cp "$BOOTSTRAP" "$FAKE_ROOT/scripts/harness-bootstrap"
cp "$SCRIPT_DIR/lockfile.toml.example" "$FAKE_ROOT/lockfile.toml.example"
"$FAKE_ROOT/scripts/harness-bootstrap" --process-only "$TMPDIR/fresh-books" \
    > "$TMPDIR/fresh-books.log"
if ! grep -q 'books  = \["rust"\]' "$TMPDIR/fresh-books/lockfile.toml"; then
    echo "✗ fresh target lockfile missing books from example"
    cat "$TMPDIR/fresh-books/lockfile.toml"
    exit 1
fi
echo "✓ process-only writes books onto a fresh target (LOCK_SRC carries books)"

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

if ! grep -qF 'GENERATED from .agents/agents/avril-conductor-agent.md' \
        "$TMPDIR/full/.opencode/agent/avril.md"; then
    echo "✗ avril.md is not generated from avril-conductor-agent"
    tail -20 "$TMPDIR/full/.opencode/agent/avril.md"
    exit 1
fi
if ! grep -qE '^mode: primary$' "$TMPDIR/full/.opencode/agent/avril.md"; then
    echo "✗ generated avril.md is not mode: primary"
    exit 1
fi
if ! grep -qF '`avril`' "$TMPDIR/full/.opencode/agent/avril.md" \
   || ! grep -qF '`gan-verdict`' "$TMPDIR/full/.opencode/agent/avril.md"; then
    echo "✗ generated avril.md is not the lean load set (avril + gan-verdict)"
    tail -20 "$TMPDIR/full/.opencode/agent/avril.md"
    exit 1
fi
echo "✓ generated avril.md is primary (avril + gan-verdict)"

echo "Testing one-law catalog shape..."
for skill in rust ocaml code-review testing; do
    if [ ! -d "$TMPDIR/full/.agents/skills/$skill" ]; then
        echo "✗ missing skill $skill"
        exit 1
    fi
done
for f in rust/RULES.md ocaml/RULES.md; do
    if [ ! -s "$TMPDIR/full/.agents/skills/$f" ]; then
        echo "✗ missing committed $f"
        exit 1
    fi
done
for dead in rust-code-writer rust-errors ocaml-code-writer rust-code-reviewer rust-code-tester; do
    if [ -d "$TMPDIR/full/.agents/skills/$dead" ]; then
        echo "✗ dead skill $dead installed from one-law pin"
        exit 1
    fi
done
echo "✓ books + gate cards present; absorbed writers absent"

AXEL_B=$(wc -c < "$TMPDIR/full/.agents/skills/axel/SKILL.md")
GV_B=$(wc -c < "$TMPDIR/full/.agents/skills/gan-verdict/SKILL.md")
WINDOW=$((AXEL_B + GV_B))
if [ "$WINDOW" -gt 8192 ]; then
    echo "✗ conductor window is $WINDOW bytes (axel $AXEL_B + gan-verdict $GV_B); want <= 8192"
    exit 1
fi
for f in \
    "$TMPDIR/full/.agents/skills/axel/SKILL.md" \
    "$TMPDIR/full/.agents/skills/gan-verdict/SKILL.md" \
    "$TMPDIR/full/.opencode/agent/axel.md"
do
    if grep -qE '`rust`|`ocaml`' "$f"; then
        echo "✗ conductor window names a book: $f"
        grep -nE '`rust`|`ocaml`' "$f" || true
        exit 1
    fi
done
echo "✓ conductor window is $WINDOW bytes (<= 8192) and names no book"

echo "Testing full idempotency (does not clobber unmarked .opencode)..."
echo "kept" >> "$TMPDIR/full/.opencode/agent/status.md"
echo "MUTATED" >> "$TMPDIR/full/.opencode/agent/avril.md"
"$BOOTSTRAP" "$TMPDIR/full" > /dev/null
if grep -q kept "$TMPDIR/full/.opencode/agent/status.md"; then
    echo "✓ second run kept unmarked .opencode/agent/status.md"
else
    echo "✗ second run overwrote unmarked .opencode"
    exit 1
fi
if grep -q MUTATED "$TMPDIR/full/.opencode/agent/avril.md"; then
    echo "✗ generated avril.md was not regenerated"
    exit 1
fi
echo "✓ generated avril.md regenerated (mutation discarded)"

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

echo "Testing requires.book + books = [] fails..."
cat > "$TMPDIR/empty-books.toml" << 'EOF'
skills = "v1-one-law"
loops  = "v1-one-law-consumers"
books  = []
EOF
LOOPS_TAG="$(python3 - "$SCRIPT_DIR/lockfile.toml" <<'PY'
import sys, tomllib
with open(sys.argv[1], "rb") as f:
    print(tomllib.load(f)["loops"])
PY
)"
if [ -n "${CROSSR_LOOPS_PATH:-}" ]; then
    LOOPS_PIN="$CROSSR_LOOPS_PATH"
else
    LOOPS_PIN="$TMPDIR/loops-pin"
    git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$LOOPS_TAG" \
        "${CROSSR_LOOPS_URL:-https://github.com/sycamore-hq/crossr-loops.git}" \
        "$LOOPS_PIN"
fi
set +e
CROSSR_SKILLS_PATH="$TMPDIR/full" \
    CROSSR_CONSUMER_LOCKFILE="$TMPDIR/empty-books.toml" \
    "$LOOPS_PIN/scripts/verify-skill-refs" > "$TMPDIR/empty-books.log" 2>&1
empty_rc=$?
set -e
if [ "$empty_rc" -eq 0 ]; then
    echo "✗ requires.book + books = [] should fail"
    cat "$TMPDIR/empty-books.log"
    exit 1
fi
if ! grep -qF 'books = []' "$TMPDIR/empty-books.log"; then
    echo "✗ empty-books failure did not mention books = []"
    cat "$TMPDIR/empty-books.log"
    exit 1
fi
echo "✓ requires.book + books = [] fails (reader iii)"

echo "✓ All smoke tests passed"
