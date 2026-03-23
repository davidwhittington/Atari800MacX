# Project Management — fuji-concepts Monorepo

This document defines the GitHub Issues-based tracking system for the
fuji-concepts monorepo. Apply it to the repo by running `setup.sh`.

---

## The Line in the Sand

| Where | What lives there |
|---|---|
| **GitHub Issues** | All active work: features, bugs, decisions, chores |
| **`docs/`** | Reference only: architecture, specs for built things |
| **`docs/project-management/`** | This system — templates and setup script |
| **Per-app `docs/`** | Detailed design specs for complex features (linked from Issues) |
| **Memory / session files** | Claude-specific context. Not a tracking system. |

If it has a status, it goes in Issues. If it's reference material with no action
required, it goes in `docs/`. If you're unsure, open a Discussion issue.

---

## The Multi-App Scope Problem

This monorepo contains multiple distinct apps that share C core code but have
independent roadmaps and different deployment targets:

| App | Platform | Language |
|---|---|---|
| `fuji-foundation` | macOS 13+ arm64 | ObjC / Swift / C |
| `fuji-vision` | visionOS 2+ | Swift / C |
| `fuji-swift` | macOS (lightweight) | Swift / C |
| `fuji-dynasty` | macOS (modular) | Swift / C |
| `fuji-services` | Linux / macOS server | Go |
| `fuji-remote` | iOS 16+ *(planned)* | Swift |
| `fuji-server` | Linux VPS *(planned)* | Go / CGo |
| `web` | fujiconcepts.com | HTML / CSS |
| `monorepo` | cross-cutting | — |

**A feature request for `fuji-services` MUST NOT be assumed to apply to
`fuji-vision` or any other app.** The `app:` label is the scope guard that
enforces this. Every issue must have exactly one `app:` label.

---

## Label System

Labels have **four dimensions**. A well-labelled issue has exactly one of each.

### 1. Type — what kind of item is this?

| Label | Color | Meaning |
|---|---|---|
| `type: feature` | Blue `#0075ca` | New capability or enhancement |
| `type: bug` | Red `#d73a4a` | Something is broken or wrong |
| `type: chore` | Yellow `#e4e669` | Maintenance, deps, cleanup, refactor |
| `type: discussion` | Purple `#d876e3` | Needs a decision before any work starts |

### 2. Priority — when does this need to happen?

| Label | Color | Meaning |
|---|---|---|
| `priority: quick-win` | Green `#2ea44f` | Low effort + high impact. Ship this week. |
| `priority: high` | Salmon `#e99695` | Important, belongs in the next sprint |
| `priority: medium` | Peach `#f9d0c4` | Valuable — schedule it |
| `priority: low` | Cream `#fef2c0` | Nice to have, no urgency |
| `priority: someday` | Grey `#eeeeee` | Moonshot. Revisit when there's momentum. |

### 3. App — which app does this apply to? *(scope guard)*

| Label | Color | Meaning |
|---|---|---|
| `app: fuji-foundation` | Orange `#e08b3a` | macOS Atari800MacX core |
| `app: fuji-vision` | Teal `#0e8a8a` | visionOS Apple Vision Pro |
| `app: fuji-swift` | Sky `#00b4d8` | lightweight macOS Swift variant |
| `app: fuji-dynasty` | Purple `#8b5cf6` | modular feature-rich macOS variant |
| `app: fuji-services` | Green `#0e8a16` | FSSP Go services (bridge/edge/relay) |
| `app: fuji-remote` | Pink `#e4007e` | iOS remote play client *(planned)* |
| `app: fuji-server` | Dark `#24292e` | headless multi-user server *(planned)* |
| `app: web` | Light blue `#c5def5` | fujiconcepts.com / beta website |
| `app: monorepo` | Grey `#eeeeee` | Cross-cutting: CI, build, shared C core, docs |

> **Rule:** A feature labelled `app: fuji-services` is ONLY for fuji-services.
> If the same feature is wanted in fuji-vision too, open a **separate issue**
> labelled `app: fuji-vision`. This keeps roadmaps independent and prevents
> unintended scope creep across apps.

### 4. Area — which technical subsystem?

| Label | Color | Meaning |
|---|---|---|
| `area: emulation` | Amber `#f59e0b` | 6502 core, POKEY, GTIA, ANTIC, memory |
| `area: metal` | Silver `#9ca3af` | Metal rendering pipeline |
| `area: audio` | Teal `#0d9488` | Sound system, POKEY audio output |
| `area: input` | Blue `#3b82f6` | Joystick, keyboard, gamepad, touch |
| `area: networking` | Purple `#7c3aed` | FSSP, TNFS, relay, WebSocket |
| `area: storage` | Green `#16a34a` | Media files, save states, disk images |
| `area: ui` | Pink `#ec4899` | SwiftUI, preferences, menus, windows |
| `area: spatial` | Lavender `#a5b4fc` | visionOS spatial, RealityKit, ARKit |
| `area: vbxe` | Gold `#d97706` | VBXE emulation subsystem |
| `area: build` | Yellow `#e4e669` | Xcode, Go modules, CI/CD, scripts |
| `area: docs` | Light blue `#bfd4f2` | Documentation, specs, website content |

### Status — only when open/closed isn't enough

| Label | Color | Meaning |
|---|---|---|
| `status: blocked` | Yellow `#e4e669` | Waiting on an external dependency |
| `status: in-progress` | Blue `#0075ca` | Actively being worked right now |
| `status: needs-spec` | Purple `#d876e3` | Good idea — needs design before dev starts |
| `status: wont-do` | Grey `#eeeeee` | Deliberately not pursuing |

---

## Milestones

| Milestone | Purpose |
|---|---|
| **Active — fuji-foundation** | Current fuji-foundation sprint (macOS core) |
| **Active — fuji-vision** | Current fuji-vision sprint (visionOS) |
| **Active — fuji-services** | Current fuji-services sprint (FSSP Go) |
| **Roadmap — Near Term** | Next 1–3 months: SDL3 eval, VBXE-2, video delta encoding |
| **Roadmap — Mid Term** | 3–6 months: fuji-server Phase FS2+, fuji-remote iOS app |
| **Roadmap — Long Term** | 6+ months: spatial audio, hand tracking, netplay, fuji-dynasty |
| **Backlog** | Captured but not yet phased or scheduled |

---

## Issue Lifecycle

```
Open (needs-spec) → Open → Open (in-progress) → Closed
                         → Open (blocked) ──→ Open (in-progress) → Closed
                                            → Closed (wont-do)
```

1. **Create** the issue with type + priority + app + area labels and a milestone
2. Add `status: needs-spec` if it needs a design doc before coding
3. Link to a `docs/` spec file if one exists (e.g. `docs/FEATURE_IOS_REMOTE_CLIENT.md`)
4. Add `status: in-progress` when work starts
5. Reference the issue number in commit messages: `Add TNFS proxy idle reaping (#42)`
6. `Closes #42` in a commit body auto-closes the issue on push

---

## Commit → Issue Linking

```
Add TNFS proxy idle reaping (#42)
Fix VIDEO frame stride mismatch in edge broadcaster (#51)
Closes #44 — Wire Telnet proxy to fssp-edge
```

`Closes #N` and `Fixes #N` auto-close. `#N` alone cross-references without closing.

---

## Issue Templates

Four templates in `.github/ISSUE_TEMPLATE/`:

| Template | Use for |
|---|---|
| `feature-request.yml` | New capabilities, enhancements |
| `bug-report.yml` | Broken behaviour, regressions |
| `discussion.yml` | Architectural decisions, open questions |
| `chore.yml` | Deps, cleanup, refactor, maintenance |

Every template includes an **App** dropdown — it is required. You cannot file an
issue without declaring which app it belongs to.

---

## What Goes Where — Quick Reference

| Item | Where |
|---|---|
| "fuji-vision should support hand tracking" | Issue: `type: feature`, `app: fuji-vision`, `area: spatial` |
| "fuji-services TNFS proxy drops packets on PAL timing" | Issue: `type: bug`, `app: fuji-services`, `area: networking` |
| "Should fuji-server use CGo or subprocess?" | Issue: `type: discussion`, `app: fuji-server`, `area: build` |
| "How the FSSP frame codec works" (built) | `apps/fuji-services/docs/` or inline README |
| "iOS remote client design spec" | `apps/fuji-services/docs/FEATURE_IOS_REMOTE_CLIENT.md` |
| "VBXE Phase 2 — cycle-accurate DMA" | Issue: `type: feature`, `app: fuji-foundation`, `area: vbxe` |
| Anything spanning all apps (e.g. shared C core change) | Issue: `app: monorepo` |

---

## Applying This System

```bash
# From the monorepo root:
bash docs/project-management/setup.sh

# Or explicit repo:
bash docs/project-management/setup.sh davidwhittington/fuji-concepts
```

Requires `gh` CLI authenticated (`gh auth login`).

---

*Same spirit as commodorecaverns — one script, four templates, four label
dimensions. The `app:` label is the only addition. Spend time building, not
managing the system.*
