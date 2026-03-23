# Legal Notice — Third-Party Derivations

## VBXE Emulation (vbxe.c / vbxe.h)

The VBXE (Video Board XE) emulation module (`src/vbxe.c`, `src/vbxe.h`) is a derived
work of the **Altirra** emulator developed by **Avery Lee**.

### Original Work

| Attribute | Value |
|-----------|-------|
| Project   | Altirra — Atari 8-bit computer emulator |
| Author    | Avery Lee |
| Source    | https://github.com/irismessage/altirra |
| File      | `src/Altirra/source/vbxe.cpp` (~3,200 lines) |
| License   | GNU General Public License, version 2 only |

### Changes Made

The Altirra `vbxe.cpp` C++ implementation was ported to plain C for integration into
the atari800 emulator core:

1. **Language**: C++ → C (struct-based instead of class-based)
2. **Memory abstraction**: Altirra scheduler/memory API replaced with atari800's
   `MEMORY_readmap`/`MEMORY_writemap` page-handler registration pattern
3. **Render buffer**: Altirra's internal render surface replaced with `MetalFrameBuffer`
   (BGRA8Unorm `uint32_t` array) and a separate `vbxe_overlay` compositing buffer
4. **Blitter**: Synchronous (not DMA-deferred); blitter-done status clears immediately
   on trigger write; cycle-accurate DMA timing deferred to a future phase

### License

Both the original Altirra source and this derived work are licensed under:

```
GNU General Public License, version 2 only (GPL-2.0-only)
```

This is compatible with the Atari800MacX project which is also GPL v2.
See `apps/fuji-foundation/COPYING` for the full GPL v2 license text.

### Attribution

Every new VBXE source file (`vbxe.c`, `vbxe.h`) carries the following SPDX header:

```c
/*
 * Derived from Altirra vbxe.cpp
 * Copyright (C) 2009-2023 Avery Lee (Altirra)
 * Copyright (C) 2026 fuji-concepts contributors
 *
 * SPDX-License-Identifier: GPL-2.0-only
 */
```

---

## Ultimate 1MB Emulation (ultimate1mb.c)

The `ultimate1mb.c` module was also adapted from Altirra by Mark Grebe (2020),
under the same GPL v2 terms.  The attribution header is present at the top of that file.

---

_Last updated: 2026-03-03_
