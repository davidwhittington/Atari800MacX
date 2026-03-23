#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# setup.sh — fuji-concepts GitHub Issues Setup
#
# Applies the fuji-concepts project management label system and milestones
# to the GitHub repository.
#
# Usage:
#   bash docs/project-management/setup.sh              # auto-detect repo
#   bash docs/project-management/setup.sh OWNER/REPO   # explicit
#
# Requires: gh CLI authenticated (gh auth login)
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Resolve repo ──────────────────────────────────────────────────────────────
if [[ -n "${1:-}" ]]; then
  REPO="$1"
else
  REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
  if [[ -z "$REPO" ]]; then
    echo "ERROR: Could not detect repo. Run from inside a git repo, or pass OWNER/REPO."
    exit 1
  fi
fi

echo ""
echo "  fuji-concepts — GitHub Issues Setup"
echo "  Repo: $REPO"
echo ""

read -r -p "  Proceed? This will modify labels and milestones on $REPO. [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
echo ""

# ── Helpers ───────────────────────────────────────────────────────────────────
make_label() {
  local name="$1" color="$2" desc="$3"
  gh label create "$name" \
    --repo "$REPO" \
    --color "$color" \
    --description "$desc" \
    --force \
    2>/dev/null && echo "  [label]     $name" \
    || echo "  [skip]      $name"
}

make_milestone() {
  local title="$1" desc="$2"
  gh api "repos/$REPO/milestones" \
    --method POST \
    --field title="$title" \
    --field description="$desc" \
    --field state="open" \
    --silent 2>/dev/null && echo "  [milestone] $title" \
    || echo "  [skip]      $title (already exists)"
}

# ─────────────────────────────────────────────────────────────────────────────
# 1. Remove GitHub's default labels
# ─────────────────────────────────────────────────────────────────────────────
echo "Removing default GitHub labels..."
for label in \
  "bug" "documentation" "duplicate" "enhancement" \
  "good first issue" "help wanted" "invalid" "question" "wontfix"
do
  gh label delete "$label" --repo "$REPO" --yes 2>/dev/null \
    && echo "  [removed]   $label" \
    || true
done
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 2. Type labels
# ─────────────────────────────────────────────────────────────────────────────
echo "Creating type labels..."
make_label "type: feature"    "0075ca" "New capability or enhancement"
make_label "type: bug"        "d73a4a" "Something is broken or wrong"
make_label "type: chore"      "e4e669" "Maintenance, deps, cleanup, refactor"
make_label "type: discussion" "d876e3" "Needs a decision before any work starts"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 3. Priority labels
# ─────────────────────────────────────────────────────────────────────────────
echo "Creating priority labels..."
make_label "priority: quick-win" "2ea44f" "Low effort + high impact — ship this week"
make_label "priority: high"      "e99695" "Important, belongs in the next sprint"
make_label "priority: medium"    "f9d0c4" "Valuable — schedule it"
make_label "priority: low"       "fef2c0" "Nice to have, no urgency"
make_label "priority: someday"   "eeeeee" "Moonshot — revisit when there is momentum"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 4. App labels  ← the scope guard unique to this monorepo
# ─────────────────────────────────────────────────────────────────────────────
echo "Creating app labels..."
make_label "app: fuji-foundation" "e08b3a" "macOS Atari800MacX core (ObjC/Swift/C)"
make_label "app: fuji-vision"     "0e8a8a" "visionOS Apple Vision Pro app"
make_label "app: fuji-swift"      "00b4d8" "Lightweight macOS Swift variant"
make_label "app: fuji-dynasty"    "8b5cf6" "Modular feature-rich macOS variant"
make_label "app: fuji-services"   "0e8a16" "FSSP Go services: bridge, edge, relay"
make_label "app: fuji-remote"     "e4007e" "iOS remote play client (planned)"
make_label "app: fuji-server"     "24292e" "Headless multi-user emulation server (planned)"
make_label "app: web"             "c5def5" "fujiconcepts.com / beta website"
make_label "app: monorepo"        "eeeeee" "Cross-cutting: CI, shared C core, docs"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 5. Area labels
# ─────────────────────────────────────────────────────────────────────────────
echo "Creating area labels..."
make_label "area: emulation"  "f59e0b" "6502 core, POKEY, GTIA, ANTIC, memory"
make_label "area: metal"      "9ca3af" "Metal rendering pipeline"
make_label "area: audio"      "0d9488" "Sound system, POKEY audio output"
make_label "area: input"      "3b82f6" "Joystick, keyboard, gamepad, touch"
make_label "area: networking" "7c3aed" "FSSP, TNFS, relay, WebSocket"
make_label "area: storage"    "16a34a" "Media files, save states, disk images"
make_label "area: ui"         "ec4899" "SwiftUI, preferences, menus, windows"
make_label "area: spatial"    "a5b4fc" "visionOS spatial, RealityKit, ARKit"
make_label "area: vbxe"       "d97706" "VBXE emulation subsystem"
make_label "area: build"      "e4e669" "Xcode, Go modules, CI/CD, scripts"
make_label "area: docs"       "bfd4f2" "Documentation, specs, website content"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 6. Status labels
# ─────────────────────────────────────────────────────────────────────────────
echo "Creating status labels..."
make_label "status: blocked"     "e4e669" "Waiting on an external dependency"
make_label "status: in-progress" "0075ca" "Actively being worked right now"
make_label "status: needs-spec"  "d876e3" "Needs a design doc before dev starts"
make_label "status: wont-do"     "eeeeee" "Deliberately not pursuing"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 7. Milestones
# ─────────────────────────────────────────────────────────────────────────────
echo "Creating milestones..."
make_milestone "Active — fuji-foundation" "Current fuji-foundation sprint: macOS Atari800MacX core."
make_milestone "Active — fuji-vision"     "Current fuji-vision sprint: visionOS Apple Vision Pro."
make_milestone "Active — fuji-services"   "Current fuji-services sprint: FSSP Go implementation."
make_milestone "Roadmap — Near Term"      "Next 1–3 months: VBXE-2, video delta encoding, SDL3 eval."
make_milestone "Roadmap — Mid Term"       "3–6 months: fuji-server FS2+, fuji-remote iOS app, fuji-dynasty scaffold."
make_milestone "Roadmap — Long Term"      "6+ months: spatial audio, hand tracking, netplay, fuji-swift."
make_milestone "Backlog"                  "Captured but not yet phased or scheduled."
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 8. Install issue templates
# ─────────────────────────────────────────────────────────────────────────────
echo "Installing issue templates..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_SRC="$SCRIPT_DIR/issue-templates"
TEMPLATE_DST=".github/ISSUE_TEMPLATE"

if [[ -d "$TEMPLATE_SRC" ]]; then
  mkdir -p "$TEMPLATE_DST"
  cp "$TEMPLATE_SRC"/*.yml "$TEMPLATE_DST/"
  echo "  Copied templates to $TEMPLATE_DST"
  echo "  Commit and push .github/ to activate them on GitHub."
else
  echo "  [skip] No issue-templates/ directory found."
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
echo "Done."
echo ""
echo "  Next steps:"
echo "  1. git add .github/ && git commit -m 'Add GitHub issue templates'"
echo "  2. git push"
echo "  3. Create first issues: https://github.com/$REPO/issues/new/choose"
echo "  4. Set milestone due dates: https://github.com/$REPO/milestones"
echo ""
