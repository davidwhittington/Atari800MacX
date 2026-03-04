/*
 * vbxe.h — VBXE (Video Board XE) emulation for Atari800MacX
 *
 * Derived from Altirra vbxe.cpp
 * Copyright (C) 2009-2023 Avery Lee (Altirra)
 * Copyright (C) 2026 fuji-concepts contributors
 *
 * SPDX-License-Identifier: GPL-2.0-only
 *
 * This file is part of the Atari800 emulator project.
 * Atari800 is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 2 of the License.
 */

#pragma once
#ifndef VBXE_H_
#define VBXE_H_

#include "atari.h"
#include <stdint.h>

/* -------------------------------------------------------------------------
 * Lifecycle
 * ---------------------------------------------------------------------- */

/** Called once at emulator startup: allocates state, builds tables. */
void  VBXE_Initialise(void);

/** Called at emulator shutdown: frees any dynamic resources. */
void  VBXE_Exit(void);

/** Cold reset: resets all VBXE state including VRAM (but not ROM-held data). */
void  VBXE_ColdStart(void);

/** Warm reset: resets register state but preserves VRAM contents. */
void  VBXE_WarmStart(void);

/* -------------------------------------------------------------------------
 * Enable / disable
 * ---------------------------------------------------------------------- */

/**
 * Enable VBXE at the given base address (0xD640 or 0xD740).
 * Installs register-space memory handlers and arms MEMAC windows.
 */
void  VBXE_Enable(int base_addr);

/**
 * Disable VBXE: removes all installed memory handlers.
 */
void  VBXE_Disable(void);

/** Returns non-zero if VBXE is currently enabled. */
int   VBXE_IsEnabled(void);

/** Returns the current VBXE register base address (0xD640 or 0xD740). */
int   VBXE_GetBaseAddr(void);

/* -------------------------------------------------------------------------
 * Memory handlers — installed into MEMORY_readmap/writemap when enabled
 * ---------------------------------------------------------------------- */

/** Register read: addresses in the 256-byte VBXE register page ($D6xx or $D7xx). */
UBYTE VBXE_RegisterGetByte(UWORD addr, int no_side_effects);

/** Register write. */
void  VBXE_RegisterPutByte(UWORD addr, UBYTE value);

/** MEMAC read: CPU access to a mapped window in VBXE VRAM. */
UBYTE VBXE_MEMACGetByte(UWORD addr, int no_side_effects);

/** MEMAC write. */
void  VBXE_MEMACPutByte(UWORD addr, UBYTE value);

/* -------------------------------------------------------------------------
 * GTIA color forwarding
 * Called from GTIA_PutByte() for registers COLPM0–COLPM3, COLPF0–COLPF3, COLBK.
 * reg_offset is the GTIA register offset (0x12–0x1A).
 * ---------------------------------------------------------------------- */
void  VBXE_SetGTIAColor(int reg_offset, UBYTE value);

/* -------------------------------------------------------------------------
 * Rendering — called from Atari_DisplayScreen() post-GTIA raster
 * ---------------------------------------------------------------------- */

/**
 * Walk the VBXE XDL (Extended Display List) for the current frame and render
 * the overlay layer into the internal vbxe_overlay[] buffer.
 * Must be called after all GTIA/ANTIC scanlines have been rendered.
 */
void  VBXE_RenderFrame(void);

/**
 * Composite the VBXE overlay onto the GTIA Metal frame buffer.
 *
 * @param dst          Pointer to MetalFrameBuffer (BGRA8Unorm uint32_t pixels).
 * @param screen_width  Width in pixels of the current display mode.
 * @param screen_height Height in pixels of the current display mode.
 */
void  VBXE_Composite(uint32_t *dst, int screen_width, int screen_height);

/* -------------------------------------------------------------------------
 * Save state (atari800 statesav framework)
 * ---------------------------------------------------------------------- */
void  VBXE_StateSave(void);
void  VBXE_StateRead(void);

/* -------------------------------------------------------------------------
 * VBXE hardware constants
 * ---------------------------------------------------------------------- */

/** VBXE FX version returned by read of $00/$01: 1.26 → low=$26, high=$01 */
#define VBXE_VERSION_LOW   0x26
#define VBXE_VERSION_HIGH  0x01

/** VRAM size in bytes (512 KB) */
#define VBXE_VRAM_SIZE     0x80000

/** Maximum overlay width in pixels */
#define VBXE_MAX_WIDTH     640

/** Maximum overlay height in lines */
#define VBXE_MAX_HEIGHT    240

/** Number of palette entries */
#define VBXE_PALETTE_SIZE  256

#endif /* VBXE_H_ */
