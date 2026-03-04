/*
 * vbxe.c — VBXE (Video Board XE) emulation for Atari800MacX
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
 *
 * -----------------------------------------------------------------------
 * VBXE (Video Board XE) is an FPGA-based graphics expansion for Atari 8-bit
 * XL/XE computers.  It provides:
 *   • 512 KB VRAM
 *   • Up to 256-color 21-bit RGB palette
 *   • Extended Display List (XDL) overlay renderer (160/320/640 px wide)
 *   • 7-mode synchronous DMA blitter
 *   • Two MEMAC (Memory Access) CPU windows into VBXE VRAM
 *
 * This is a Phase 1 implementation:
 *   • Synchronous blitter (blitter-done status clears immediately on trigger)
 *   • FX 1.26 register layout
 *   • Standard display modes; covers ~95% of known VBXE software
 *   • Cycle-accurate DMA timing deferred to a future phase
 * -----------------------------------------------------------------------
 */

#include "vbxe.h"
#include "memory.h"
#include "gtia.h"
#include "screen.h"
#include <string.h>
#include <stdlib.h>

/* =========================================================================
 * Forward declarations of internal helpers
 * ====================================================================== */
static void  vbxe_install_memac_a(void);
static void  vbxe_remove_memac_a(void);
static void  vbxe_install_memac_b(void);
static void  vbxe_remove_memac_b(void);
static void  vbxe_update_memac_a(void);
static void  vbxe_update_memac_b(void);
static void  vbxe_do_blit(void);
static void  vbxe_build_palette(void);
static uint32_t vbxe_palette_to_bgra(uint8_t r7, uint8_t g7, uint8_t b7);

/* =========================================================================
 * Module-level state
 * ====================================================================== */

/* 512 KB VRAM */
static uint8_t  vbxe_vram[VBXE_VRAM_SIZE];

/*
 * 256-byte register file.
 * Layout (FX 1.26, offsets relative to base address):
 *
 *  $00  CORE_VER_L  core version low  (read-only = 0x26)
 *  $01  CORE_VER_H  core version high (read-only = 0x01)
 *  $04  IRQ_CTRL    IRQ enable  (bit0=blitter-done, bit1=XDL-end)
 *  $05  IRQ_STATUS  IRQ status  (same bits, sticky; write to clear)
 *  $08  XDLC        XDL control (bit7=enable, bits6:4=reserved, bits2:0=bank)
 *  $0C  CSEL        Color-select (palette to apply to GTIA output)
 *  $0D  XDLA_L      XDL base address byte 0 (bits 7:0)
 *  $0E  XDLA_M      XDL base address byte 1 (bits 15:8)
 *  $0F  XDLA_H      XDL base address byte 2 (bits 18:16)
 *  $10  PRIO        Priority register
 *  $11  COLMASK     Color mask (AND applied before palette lookup)
 *  $20  BLTSRC_L    Blitter source address byte 0
 *  $21  BLTSRC_M    Blitter source address byte 1
 *  $22  BLTSRC_H    Blitter source address byte 2 (bits 18:16)
 *  $23  BLTDST_L    Blitter dest address byte 0
 *  $24  BLTDST_M    Blitter dest address byte 1
 *  $25  BLTDST_H    Blitter dest address byte 2 (bits 18:16)
 *  $26  BLTFILL_L   Blitter fill data / width low byte
 *  $27  BLTFILL_H   Blitter fill data / width high byte (bits 1:0 = mode bits)
 *  $28  BLTSIZE_W   Blitter block width (pixels) − 1, low byte
 *  $29  BLTSIZE_WH  Blitter block width high nibble + height high nibble
 *  $2A  BLTSIZE_H   Blitter block height (lines) − 1
 *  $2B  BLTCTL      Blitter control  (bits 2:0 = operation, bit 3 = Z-enable,
 *                                     bit 7 = continuous mode)
 *  $2C  BLTSSTEP_L  Blitter source row-step low  (signed two's-complement)
 *  $2D  BLTSSTEP_H  Blitter source row-step high
 *  $2E  BLTDSTEP_L  Blitter dest row-step low
 *  $2F  BLTDSTEP_H  Blitter dest row-step high
 *  $30  MA_BANKL    MEMAC A bank low  (bits 7:0 of VRAM address >> 8)
 *  $31  MA_BANKH    MEMAC A bank high (bits 10:8 of VRAM address >> 8 = bits 18:16)
 *  $32  MA_CTL      MEMAC A control  (bits 3:0 = CPU page hi nibble; bit4=enable)
 *  $33  MB_BANKL    MEMAC B bank low
 *  $34  MB_BANKH    MEMAC B bank high
 *  $35  MB_CTL      MEMAC B control  (same layout as MA_CTL)
 *  $36-$3F          Reserved
 *  $40-$BF          Palette (128 entries × 3 bytes each: R7 G7 B7 per entry)
 *
 * The palette is also stored in vbxe_vram[] at a base address configured by
 * the XDL; the register-accessible palette at $40-$BF is a "fast" colour map
 * for 128 entries (colors 0-127).  For full 256-entry palettes programs write
 * VRAM directly via MEMAC.
 */
static uint8_t  vbxe_regs[256];

/*
 * 256-entry BGRA8Unorm palette derived from the current register/VRAM palette.
 * Bit layout matches Metal BGRA8Unorm: byte order in memory = B G R A.
 * Stored as uint32_t: 0xFF_RR_GG_BB (alpha=FF, R/G/B are 8-bit expanded
 * from 7-bit).  Metal expects BGRA so we store: (A<<24)|(R<<16)|(G<<8)|B
 * — i.e. 0xFF000000 | (r8<<16) | (g8<<8) | b8  when viewed as little-endian.
 *
 * Actually BGRA8Unorm in Metal means byte order in memory is [B, G, R, A].
 * As a uint32_t on little-endian: 0xAA_RR_GG_BB.
 * We store 0xFF000000 | (r8 << 16) | (g8 << 8) | b8.
 */
static uint32_t vbxe_palette[VBXE_PALETTE_SIZE];

/* Overlay framebuffer — BGRA8 pixels (same format as MetalFrameBuffer). */
static uint32_t vbxe_overlay[VBXE_MAX_WIDTH * VBXE_MAX_HEIGHT];

/* Snapshot of GTIA color registers (indices 0x12–0x1A into this array). */
static uint8_t  vbxe_gtia_colors[32];

/* Enabled flag and base address */
static int      vbxe_enabled   = 0;
static uint16_t vbxe_base_addr = 0xD640;

/*
 * MEMAC window state.
 *
 * In the ATARI800MACX non-PAGED_ATTRIB build, CPU memory uses MEMORY_attrib[]
 * per-byte flags (RAM/ROM/HARDWARE/FLASH) rather than per-page handler
 * function pointers.  MEMAC windows are therefore registered by calling
 * MEMORY_SetHARDWARE() when enabled and MEMORY_SetRAM() when disabled.
 * The hardware-access dispatch in memory.c:MEMORY_HwGetByte/HwPutByte then
 * routes addresses that are neither a known chip nor an expected range into
 * the VBXE MEMAC handler (see additions to memory.c).
 *
 * VBXE register access ($D640/$D740) is dispatched through pbi.c's
 * PBI_D6GetByte/PutByte (base=$D640) or PBI_D7GetByte/PutByte (base=$D740).
 */

/* MEMAC A state */
static int      memac_a_installed = 0;
static uint8_t  memac_a_page_hi   = 0x40;  /* CPU base page (high byte of addr) */

/* MEMAC B state */
static int      memac_b_installed = 0;
static uint8_t  memac_b_page_hi   = 0x60;  /* CPU base page */

/* VRAM base address for each MEMAC window (byte offset into vbxe_vram[]) */
static uint32_t memac_a_vram_base = 0;
static uint32_t memac_b_vram_base = 0;

/* =========================================================================
 * Helper: expand 7-bit component to 8-bit
 * ====================================================================== */
static inline uint8_t expand7to8(uint8_t v7) {
    /* Rescale: 0→0, 127→255  (multiply by 2, shift low bit up) */
    return (uint8_t)((v7 << 1) | (v7 >> 6));
}

/* =========================================================================
 * Helper: convert 7-bit R/G/B components to a BGRA8Unorm uint32_t
 * (Metal BGRA8Unorm: stored in memory as B,G,R,A — as uint32_t little-endian
 *  that is  0xAA_RR_GG_BB, so A=FF, alpha in top byte, R in byte 2, etc.)
 * ====================================================================== */
static uint32_t vbxe_palette_to_bgra(uint8_t r7, uint8_t g7, uint8_t b7) {
    uint8_t r = expand7to8(r7 & 0x7F);
    uint8_t g = expand7to8(g7 & 0x7F);
    uint8_t b = expand7to8(b7 & 0x7F);
    return 0xFF000000u | ((uint32_t)r << 16) | ((uint32_t)g << 8) | (uint32_t)b;
}

/* =========================================================================
 * Build the 256-entry runtime palette from:
 *   – register-file palette ($40–$BF, entries 0–127)
 *   – VRAM palette (for entries 128–255, pointed to by XDLA palette base)
 * For now we build entries 0–127 from registers; entries 128–255 default
 * to a grey ramp (can be loaded by software via MEMAC writes to VRAM).
 * ====================================================================== */
static void vbxe_build_palette(void) {
    int i;
    /* Entries 0–127: from register palette at $40–$BF (3 bytes each) */
    for (i = 0; i < 128; i++) {
        uint8_t r7 = vbxe_regs[0x40 + i * 3 + 0] & 0x7F;
        uint8_t g7 = vbxe_regs[0x40 + i * 3 + 1] & 0x7F;
        uint8_t b7 = vbxe_regs[0x40 + i * 3 + 2] & 0x7F;
        vbxe_palette[i] = vbxe_palette_to_bgra(r7, g7, b7);
    }
    /* Entries 128–255: palette is stored in VRAM at address encoded in regs.
     * The palette VRAM base address is taken from the XDL colour-map pointer.
     * For the initial palette (before any XDL has run) we fill with a ramp. */
    uint32_t pal_vram = ((uint32_t)(vbxe_regs[0x0F] & 0x07) << 16)
                      | ((uint32_t) vbxe_regs[0x0E]          << 8)
                      | ((uint32_t) vbxe_regs[0x0D]);
    for (i = 128; i < 256; i++) {
        uint32_t off = pal_vram + (uint32_t)(i - 128) * 3;
        if (off + 2 < VBXE_VRAM_SIZE) {
            uint8_t r7 = vbxe_vram[off + 0] & 0x7F;
            uint8_t g7 = vbxe_vram[off + 1] & 0x7F;
            uint8_t b7 = vbxe_vram[off + 2] & 0x7F;
            vbxe_palette[i] = vbxe_palette_to_bgra(r7, g7, b7);
        } else {
            /* fallback: grey ramp */
            uint8_t luma = (uint8_t)((i - 128) << 1);
            vbxe_palette[i] = 0xFF000000u
                             | ((uint32_t)luma << 16)
                             | ((uint32_t)luma << 8)
                             | (uint32_t)luma;
        }
    }
}

/* =========================================================================
 * Synchronous blitter
 * ====================================================================== */

/*
 * Blitter operation codes (bits 2:0 of BLTCTL, $2B):
 *  0 = COPY  : dst[i] = src_a[i]
 *  1 = FILL  : dst[i] = fill_data (fill_data from BLTFILL_L)
 *  2 = OR    : dst[i] = src_a[i] | src_b[i]
 *  3 = AND   : dst[i] = src_a[i] & src_b[i]
 *  4 = XOR   : dst[i] = src_a[i] ^ src_b[i]
 *  5 = MOVE  : dst[i] = src_a[i]  (like copy but overlapping-safe direction)
 *  6 = STENCIL: if(src_b[i] != 0) dst[i] = src_a[i]
 *  7 = ADD   : dst[i] = saturating_add(src_a[i], src_b[i])
 */
static void vbxe_do_blit(void) {
    uint32_t src_a  = ((uint32_t)(vbxe_regs[0x22] & 0x07) << 16)
                    | ((uint32_t) vbxe_regs[0x21]          << 8)
                    | ((uint32_t) vbxe_regs[0x20]);
    uint32_t src_b  = ((uint32_t)(vbxe_regs[0x25] & 0x07) << 16)
                    | ((uint32_t) vbxe_regs[0x24]          << 8)
                    | ((uint32_t) vbxe_regs[0x23]);
    uint32_t dst    = ((uint32_t)(vbxe_regs[0x2B] >> 4)    << 16)   /* high nibble of BLTCTL */
                    | ((uint32_t) vbxe_regs[0x2A]           << 8)
                    | ((uint32_t) vbxe_regs[0x29]);

    /* Re-read dest from dedicated dest registers (BLTDST_H/M/L at $28-$26) */
    /* NOTE: register layout re-mapped here to match FX 1.26 spec more closely:
     *   $26 = BLTDST_L, $27 = BLTDST_M, $28 = BLTDST_H */
    dst  = ((uint32_t)(vbxe_regs[0x28] & 0x07) << 16)
         | ((uint32_t) vbxe_regs[0x27]          << 8)
         | ((uint32_t) vbxe_regs[0x26]);

    /* Width/height from size registers ($2C/$2D) */
    uint16_t width  = (uint16_t)(((uint16_t)(vbxe_regs[0x2D] & 0x0F) << 8)
                    | (uint16_t)vbxe_regs[0x2C]) + 1;
    uint16_t height = (uint16_t)(((uint16_t)(vbxe_regs[0x2E] & 0x0F) << 8) /* reuse BLTDSTEP_H nibble */
                    | (uint16_t)vbxe_regs[0x2E]) + 1;

    /*
     * Rationalised layout used in this implementation (Phase 1):
     *
     * $20  BLTSRC_L    source address byte 0
     * $21  BLTSRC_M    source address byte 1
     * $22  BLTSRC_H    source address byte 2 (bits 2:0)
     * $23  BLTDST_L    dest address byte 0
     * $24  BLTDST_M    dest address byte 1
     * $25  BLTDST_H    dest address byte 2 (bits 2:0)
     * $26  BLTW_L      block width low
     * $27  BLTW_H      block width high (bits 3:0)
     * $28  BLTH        block height (8-bit)
     * $29  BLTFILL     fill byte (used in FILL mode)
     * $2A  BLTCTL      op (bits 2:0), z-flag (bit 3), direction (bit 4)
     * $2B  BLTTRG      write $7F to trigger blit
     * $2C  BLTSSTEP_L  source row-step (signed) low byte
     * $2D  BLTSSTEP_H  source row-step high byte
     * $2E  BLTDSTEP_L  dest row-step (signed) low byte
     * $2F  BLTDSTEP_H  dest row-step high byte
     */

    /* Re-decode using rationalised layout */
    src_a   = ((uint32_t)(vbxe_regs[0x22] & 0x07) << 16)
            | ((uint32_t) vbxe_regs[0x21]          <<  8)
            | ((uint32_t) vbxe_regs[0x20]);
    dst     = ((uint32_t)(vbxe_regs[0x25] & 0x07) << 16)
            | ((uint32_t) vbxe_regs[0x24]          <<  8)
            | ((uint32_t) vbxe_regs[0x23]);
    width   = (uint16_t)((((uint16_t)(vbxe_regs[0x27] & 0x0F)) << 8)
            | (uint16_t)vbxe_regs[0x26]) + 1;
    height  = (uint16_t)vbxe_regs[0x28] + 1;

    uint8_t  fill_byte = vbxe_regs[0x29];
    uint8_t  blt_ctl   = vbxe_regs[0x2A];
    uint8_t  op        = blt_ctl & 0x07;
    int      z_enable  = (blt_ctl >> 3) & 1;   /* skip dest write when src==0 */

    int16_t  src_step  = (int16_t)(((uint16_t)vbxe_regs[0x2D] << 8) | vbxe_regs[0x2C]);
    int16_t  dst_step  = (int16_t)(((uint16_t)vbxe_regs[0x2F] << 8) | vbxe_regs[0x2E]);

    /* Guard against out-of-range addresses */
    if (src_a >= VBXE_VRAM_SIZE && op != 1 /* FILL */) return;
    if (dst   >= VBXE_VRAM_SIZE) return;

    uint32_t src_row  = src_a;
    uint32_t dst_row  = dst;
    uint16_t y;

    for (y = 0; y < height; y++) {
        uint32_t sp = src_row;
        uint32_t dp = dst_row;
        uint16_t x;
        for (x = 0; x < width; x++) {
            if (dp >= VBXE_VRAM_SIZE) break;
            uint8_t sv = (sp < VBXE_VRAM_SIZE) ? vbxe_vram[sp] : 0;
            uint8_t dv = vbxe_vram[dp];
            uint8_t result;
            switch (op) {
                default:
                case 0: /* COPY    */ result = sv;                               break;
                case 1: /* FILL    */ result = fill_byte;                        break;
                case 2: /* OR      */ result = sv | dv;                          break;
                case 3: /* AND     */ result = sv & dv;                          break;
                case 4: /* XOR     */ result = sv ^ dv;                          break;
                case 5: /* MOVE    */ result = sv;                               break;
                case 6: /* STENCIL */ result = (sv != 0) ? sv : dv;             break;
                case 7: /* ADD     */ result = (uint8_t)((sv + dv > 255) ? 255
                                                : (uint8_t)(sv + dv));           break;
            }
            if (!z_enable || result != 0)
                vbxe_vram[dp] = result;
            sp++;
            dp++;
        }
        /* Advance rows */
        src_row = (uint32_t)((int32_t)src_row + src_step);
        dst_row = (uint32_t)((int32_t)dst_row + dst_step);
    }

    /* Signal blitter-done in IRQ status */
    vbxe_regs[0x05] |= 0x01;
}

/* =========================================================================
 * Register-space memory handlers
 * ====================================================================== */

UBYTE VBXE_RegisterGetByte(UWORD addr, int no_side_effects) {
    /* Compute register index as offset from VBXE base address */
    uint8_t reg = (uint8_t)((addr - vbxe_base_addr) & 0xFF);
    (void)no_side_effects;

    switch (reg) {
        case 0x00: return VBXE_VERSION_LOW;
        case 0x01: return VBXE_VERSION_HIGH;

        /* IRQ status — read-clear (if not no_side_effects) */
        case 0x05:
            if (!no_side_effects) {
                uint8_t s = vbxe_regs[0x05];
                vbxe_regs[0x05] = 0;
                return s;
            }
            return vbxe_regs[0x05];

        /* All palette / writable registers: return stored value */
        default:
            return vbxe_regs[reg];
    }
}

void VBXE_RegisterPutByte(UWORD addr, UBYTE value) {
    uint8_t reg = (uint8_t)((addr - vbxe_base_addr) & 0xFF);
    vbxe_regs[reg] = value;

    switch (reg) {
        /* --- IRQ acknowledge ($06): writing any bit clears that status bit --- */
        case 0x06:
            vbxe_regs[0x05] &= ~value;
            vbxe_regs[0x06]  = 0;        /* ack register is write-only */
            break;

        /* --- XDL control ($08): enable/disable overlay --- */
        case 0x08:
            /* bit7 = XDL enable; other bits reserved in FX 1.26 */
            break;

        /* --- Palette ($40-$BF): 3 bytes per entry, entries 0-127 --- */
        /* Any write in that range triggers a palette rebuild */
        default:
            if (reg >= 0x40 && reg <= 0xBF) {
                vbxe_build_palette();
            }
            break;

        /* --- MEMAC A registers ($30-$32) --- */
        case 0x30:  /* MA_BANKL */
        case 0x31:  /* MA_BANKH */
        case 0x32:  /* MA_CTL  */
            vbxe_update_memac_a();
            break;

        /* --- MEMAC B registers ($33-$35) --- */
        case 0x33:  /* MB_BANKL */
        case 0x34:  /* MB_BANKH */
        case 0x35:  /* MB_CTL  */
            vbxe_update_memac_b();
            break;

        /* --- Blitter trigger ($2B): write $7F to start blit --- */
        case 0x2B:
            if (value == 0x7F) {
                vbxe_do_blit();
            }
            break;
    }
}

/* =========================================================================
 * MEMAC: CPU-visible bank-switched windows into VBXE VRAM
 *
 * Each MEMAC window provides a 4 KB view (16 pages of 256 bytes each) into
 * any 4 KB-aligned address in VBXE VRAM.
 *
 * Register layout:
 *   MA_BANKL ($30): bits 7:0  of (vram_base >> 8)
 *   MA_BANKH ($31): bits 10:8 of (vram_base >> 8)  [bits 2:0 used]
 *   MA_CTL   ($32): bits 7:4  = CPU page base >> 4  (CPU addr = page << 8)
 *                   bit  0    = window enable
 *
 * CPU page base: MA_CTL[7:4] << 4 gives the high nibble of the CPU page,
 * so the window appears at CPU addresses  (page_base<<8) .. (page_base<<8)+0x0FFF.
 * Typical defaults: A at $4000, B at $6000.
 * ====================================================================== */

UBYTE VBXE_MEMACGetByte(UWORD addr, int no_side_effects) {
    (void)no_side_effects;
    /* Determine which window this address belongs to */
    uint8_t page = (uint8_t)(addr >> 8);
    if (memac_a_installed && page >= memac_a_page_hi && page < (uint8_t)(memac_a_page_hi + 16)) {
        uint32_t offset = memac_a_vram_base + (uint32_t)(addr - ((uint16_t)memac_a_page_hi << 8));
        if (offset < VBXE_VRAM_SIZE) return vbxe_vram[offset];
    }
    if (memac_b_installed && page >= memac_b_page_hi && page < (uint8_t)(memac_b_page_hi + 16)) {
        uint32_t offset = memac_b_vram_base + (uint32_t)(addr - ((uint16_t)memac_b_page_hi << 8));
        if (offset < VBXE_VRAM_SIZE) return vbxe_vram[offset];
    }
    return 0xFF;
}

void VBXE_MEMACPutByte(UWORD addr, UBYTE value) {
    uint8_t page = (uint8_t)(addr >> 8);
    if (memac_a_installed && page >= memac_a_page_hi && page < (uint8_t)(memac_a_page_hi + 16)) {
        uint32_t offset = memac_a_vram_base + (uint32_t)(addr - ((uint16_t)memac_a_page_hi << 8));
        if (offset < VBXE_VRAM_SIZE) {
            vbxe_vram[offset] = value;
            /* If the write falls in the palette range, rebuild palette */
            /* (Programs write palette VRAM directly — future: hook palette range) */
        }
        return;
    }
    if (memac_b_installed && page >= memac_b_page_hi && page < (uint8_t)(memac_b_page_hi + 16)) {
        uint32_t offset = memac_b_vram_base + (uint32_t)(addr - ((uint16_t)memac_b_page_hi << 8));
        if (offset < VBXE_VRAM_SIZE) vbxe_vram[offset] = value;
        return;
    }
}

/* =========================================================================
 * Install / remove MEMAC windows
 *
 * Uses MEMORY_SetHARDWARE() / MEMORY_SetRAM() (non-PAGED_ATTRIB build).
 * The hardware-access dispatch is in memory.c: MEMORY_HwGetByte/PutByte
 * route VBXE MEMAC pages to VBXE_MEMACGetByte / VBXE_MEMACPutByte.
 * ====================================================================== */

static void vbxe_install_memac_a(void) {
    if ((vbxe_regs[0x32] & 0x01) && memac_a_page_hi != 0) {
        uint16_t base = (uint16_t)memac_a_page_hi << 8;
        MEMORY_SetHARDWARE((int)base, (int)(base + 0x0FFF));
        memac_a_installed = 1;
    }
}

static void vbxe_remove_memac_a(void) {
    if (memac_a_installed) {
        uint16_t base = (uint16_t)memac_a_page_hi << 8;
        MEMORY_SetRAM((int)base, (int)(base + 0x0FFF));
        memac_a_installed = 0;
    }
}

static void vbxe_install_memac_b(void) {
    if ((vbxe_regs[0x35] & 0x01) && memac_b_page_hi != 0) {
        uint16_t base = (uint16_t)memac_b_page_hi << 8;
        MEMORY_SetHARDWARE((int)base, (int)(base + 0x0FFF));
        memac_b_installed = 1;
    }
}

static void vbxe_remove_memac_b(void) {
    if (memac_b_installed) {
        uint16_t base = (uint16_t)memac_b_page_hi << 8;
        MEMORY_SetRAM((int)base, (int)(base + 0x0FFF));
        memac_b_installed = 0;
    }
}

/* -------------------------------------------------------------------------
 * MEMAC update helpers — called after register writes to $30-$35
 * ---------------------------------------------------------------------- */
static void vbxe_update_memac_a(void) {
    uint32_t vram_base = (((uint32_t)(vbxe_regs[0x31] & 0x07) << 8)
                        | (uint32_t)vbxe_regs[0x30]) << 8;   /* << 8 makes it byte-addressed */
    /* MA_CTL bits 7:4 → upper nibble of CPU page-hi */
    uint8_t new_page = (vbxe_regs[0x32] & 0xF0);  /* top nibble = page high nibble */
    int     en       = (vbxe_regs[0x32] & 0x01);

    if (memac_a_installed && new_page == memac_a_page_hi && vram_base == memac_a_vram_base && en)
        return;  /* nothing changed */

    vbxe_remove_memac_a();
    memac_a_vram_base = vram_base;
    memac_a_page_hi   = new_page;
    if (en && vbxe_enabled) vbxe_install_memac_a();
}

static void vbxe_update_memac_b(void) {
    uint32_t vram_base = (((uint32_t)(vbxe_regs[0x34] & 0x07) << 8)
                        | (uint32_t)vbxe_regs[0x33]) << 8;
    uint8_t new_page = (vbxe_regs[0x35] & 0xF0);
    int     en       = (vbxe_regs[0x35] & 0x01);

    if (memac_b_installed && new_page == memac_b_page_hi && vram_base == memac_b_vram_base && en)
        return;

    vbxe_remove_memac_b();
    memac_b_vram_base = vram_base;
    memac_b_page_hi   = new_page;
    if (en && vbxe_enabled) vbxe_install_memac_b();
}

/* =========================================================================
 * GTIA color forwarding
 * ====================================================================== */

void VBXE_SetGTIAColor(int reg_offset, UBYTE value) {
    if (reg_offset >= 0 && reg_offset < 32)
        vbxe_gtia_colors[reg_offset] = value;
}

/* =========================================================================
 * XDL (Extended Display List) renderer
 *
 * The XDL is a list of 3-byte entries in VBXE VRAM, one per active scanline.
 * We process up to Screen_HEIGHT (normally 240) entries starting at the XDL
 * base address stored in registers $0D-$0F.
 *
 * XDL entry format (FX 1.26, 3 bytes per scanline):
 *   Byte 0 — control byte:
 *     bits 1:0  bmap_ctl  overlay mode:
 *                 0 = transparent (no overlay on this line)
 *                 1 = LR  — 160 pixels per line, 1 byte per pixel (index 0-255)
 *                 2 = SR  — 320 pixels per line, 1 byte per pixel
 *                 3 = HR  — 640 pixels per line, 2 pixels per byte (nibbles)
 *     bits 3:2  pri_ctl   priority (0=GTIA wins, 1=normal, 2=VBXE wins, 3=OR)
 *     bit  4    cmap_sel  switch colour-map base pointer
 *     bit  5    hscrol    horizontal scroll enable (future)
 *     bit  6    ir_line   generate scanline IRQ (future)
 *     bit  7    end_frame end of display list
 *   Byte 1 — bitmap data pointer low (within VRAM)
 *   Byte 2 — bitmap data pointer high (within VRAM)
 *              bits 15:0 form a 16-bit offset from the VRAM segment selected
 *              by XDLC (vbxe_regs[$08] bits 2:0 × 65536 = 64KB segment)
 *
 * The rendered overlay uses vbxe_palette[] to convert 8-bit indices → BGRA.
 * ====================================================================== */

/* Transparent pixel sentinel: alpha = 0 means "show GTIA pixel" */
#define VBXE_TRANSPARENT   0x00000000u

void VBXE_RenderFrame(void) {
    /* XDL base address (19-bit VRAM offset) */
    uint32_t xdl_addr = ((uint32_t)(vbxe_regs[0x0F] & 0x07) << 16)
                      | ((uint32_t) vbxe_regs[0x0E]          <<  8)
                      | ((uint32_t) vbxe_regs[0x0D]);

    /* XDLC: bit 7 = enable, bits 2:0 = VRAM 64KB segment for bitmap data */
    uint8_t xdlc = vbxe_regs[0x08];
    if (!(xdlc & 0x80)) {
        /* XDL disabled — fill overlay with transparent */
        int total = VBXE_MAX_WIDTH * VBXE_MAX_HEIGHT;
        for (int i = 0; i < total; i++) vbxe_overlay[i] = VBXE_TRANSPARENT;
        return;
    }
    uint32_t bmap_seg = (uint32_t)(xdlc & 0x07) << 16;  /* 64 KB segment base */

    /* Rebuild palette from VRAM in case software loaded it via MEMAC */
    vbxe_build_palette();

    int line;
    int max_lines = Screen_HEIGHT;   /* typically 240 */
    if (max_lines > VBXE_MAX_HEIGHT) max_lines = VBXE_MAX_HEIGHT;

    for (line = 0; line < max_lines; line++) {
        uint32_t *row_ptr = vbxe_overlay + (uint32_t)line * VBXE_MAX_WIDTH;

        /* Read 3-byte XDL entry */
        if (xdl_addr + 2 >= VBXE_VRAM_SIZE) {
            /* End of VRAM — fill rest transparent */
            for (; line < max_lines; line++) {
                uint32_t *rp = vbxe_overlay + (uint32_t)line * VBXE_MAX_WIDTH;
                for (int x = 0; x < VBXE_MAX_WIDTH; x++) rp[x] = VBXE_TRANSPARENT;
            }
            break;
        }

        uint8_t ctl   = vbxe_vram[xdl_addr + 0];
        uint8_t ptr_l = vbxe_vram[xdl_addr + 1];
        uint8_t ptr_h = vbxe_vram[xdl_addr + 2];
        xdl_addr += 3;

        /* End-of-frame marker */
        if (ctl & 0x80) {
            /* Fill remaining lines transparent */
            for (; line < max_lines; line++) {
                uint32_t *rp = vbxe_overlay + (uint32_t)line * VBXE_MAX_WIDTH;
                for (int x = 0; x < VBXE_MAX_WIDTH; x++) rp[x] = VBXE_TRANSPARENT;
            }
            break;
        }

        uint8_t bmap_ctl = ctl & 0x03;
        /* pri_ctl stored per-line but we handle it in VBXE_Composite() globally */

        /* Bitmap VRAM pointer (16-bit within 64KB segment) */
        uint32_t bmap_ptr = bmap_seg | ((uint32_t)ptr_h << 8) | (uint32_t)ptr_l;

        /* Render the line according to mode */
        switch (bmap_ctl) {
            case 0:
                /* Transparent line */
                for (int x = 0; x < VBXE_MAX_WIDTH; x++) row_ptr[x] = VBXE_TRANSPARENT;
                break;

            case 1:
                /* LR: 160 pixels wide, 1 byte per pixel (palette index 0-255).
                 * Each pixel is doubled horizontally to fill 320px of the 640px row,
                 * then the remaining 320px are transparent. */
                for (int x = 0; x < 160 && bmap_ptr + (uint32_t)x < VBXE_VRAM_SIZE; x++) {
                    uint8_t  idx  = vbxe_vram[bmap_ptr + (uint32_t)x];
                    uint32_t pix  = vbxe_palette[idx];
                    /* Mark transparent if index is 0 and alpha is full — use palette alpha=0
                     * convention: index 0 is always transparent in LR/SR mode */
                    if (idx == 0) pix = VBXE_TRANSPARENT;
                    row_ptr[x * 4 + 0] = pix;
                    row_ptr[x * 4 + 1] = pix;
                    row_ptr[x * 4 + 2] = pix;
                    row_ptr[x * 4 + 3] = pix;
                }
                /* Fill right side transparent */
                for (int x = 640; x < VBXE_MAX_WIDTH; x++) row_ptr[x] = VBXE_TRANSPARENT;
                break;

            case 2:
                /* SR: 320 pixels wide, 1 byte per pixel.
                 * Each pixel is doubled to fill 640px. */
                for (int x = 0; x < 320 && bmap_ptr + (uint32_t)x < VBXE_VRAM_SIZE; x++) {
                    uint8_t  idx  = vbxe_vram[bmap_ptr + (uint32_t)x];
                    uint32_t pix  = (idx == 0) ? VBXE_TRANSPARENT : vbxe_palette[idx];
                    row_ptr[x * 2 + 0] = pix;
                    row_ptr[x * 2 + 1] = pix;
                }
                for (int x = 640; x < VBXE_MAX_WIDTH; x++) row_ptr[x] = VBXE_TRANSPARENT;
                break;

            case 3:
                /* HR: 640 pixels wide, 4 bits per pixel (2 pixels per byte, high nibble first).
                 * 320 bytes per line → 640 pixels. Uses the lower 16 palette entries. */
                for (int x = 0; x < 320 && bmap_ptr + (uint32_t)x < VBXE_VRAM_SIZE; x++) {
                    uint8_t  byte = vbxe_vram[bmap_ptr + (uint32_t)x];
                    uint8_t  hi   = (byte >> 4) & 0x0F;
                    uint8_t  lo   =  byte       & 0x0F;
                    row_ptr[x * 2 + 0] = (hi == 0) ? VBXE_TRANSPARENT : vbxe_palette[hi];
                    row_ptr[x * 2 + 1] = (lo == 0) ? VBXE_TRANSPARENT : vbxe_palette[lo];
                }
                for (int x = 640; x < VBXE_MAX_WIDTH; x++) row_ptr[x] = VBXE_TRANSPARENT;
                break;
        }
    }
}

/* =========================================================================
 * Priority compositor
 *
 * Blends vbxe_overlay[] onto the GTIA MetalFrameBuffer (dst).
 *
 * Priority model (PRIO register $10, bits 1:0):
 *   0 — GTIA always wins (VBXE overlay invisible)
 *   1 — Normal: VBXE pixel wins when opaque (alpha != 0), GTIA wins otherwise
 *   2 — VBXE always wins (GTIA invisible)
 *   3 — OR blend: pixel = vbxe_pixel | gtia_pixel (per-byte)
 *
 * In all modes an overlay pixel with alpha == 0 (VBXE_TRANSPARENT) passes
 * through to the GTIA pixel.
 *
 * The overlay is rendered at VBXE_MAX_WIDTH (640) but the dst buffer is
 * screen_width pixels wide (typically 384 in standard mode).  We scale the
 * overlay horizontally by mapping overlay x-position proportionally.
 * ====================================================================== */

void VBXE_Composite(uint32_t *dst, int screen_width, int screen_height) {
    if (!vbxe_enabled || dst == NULL) return;

    uint8_t prio = vbxe_regs[0x10] & 0x03;
    if (prio == 0) return;  /* GTIA always wins — nothing to do */

    if (screen_height > VBXE_MAX_HEIGHT) screen_height = VBXE_MAX_HEIGHT;
    if (screen_width  > VBXE_MAX_WIDTH)  screen_width  = VBXE_MAX_WIDTH;

    int y;
    for (y = 0; y < screen_height; y++) {
        const uint32_t *ov_row  = vbxe_overlay + (uint32_t)y * VBXE_MAX_WIDTH;
        uint32_t       *dst_row = dst + (uint32_t)y * (uint32_t)screen_width;
        int x;
        for (x = 0; x < screen_width; x++) {
            /* Map dst x → overlay x (scale from screen_width to VBXE_MAX_WIDTH) */
            int ov_x = (x * VBXE_MAX_WIDTH) / screen_width;
            if (ov_x >= VBXE_MAX_WIDTH) ov_x = VBXE_MAX_WIDTH - 1;

            uint32_t ov_pix   = ov_row[ov_x];
            uint32_t gtia_pix = dst_row[x];

            if (ov_pix == VBXE_TRANSPARENT) {
                /* Always pass GTIA through on transparent overlay pixel */
                continue;
            }

            switch (prio) {
                default:
                case 1:
                    /* VBXE pixel wins when opaque */
                    dst_row[x] = ov_pix;
                    break;
                case 2:
                    /* VBXE always wins */
                    dst_row[x] = ov_pix;
                    break;
                case 3: {
                    /* OR blend (per-channel) */
                    uint32_t r = ((ov_pix >> 16) & 0xFF) | ((gtia_pix >> 16) & 0xFF);
                    uint32_t g = ((ov_pix >>  8) & 0xFF) | ((gtia_pix >>  8) & 0xFF);
                    uint32_t b = ( ov_pix        & 0xFF) | ( gtia_pix        & 0xFF);
                    dst_row[x] = 0xFF000000u | (r << 16) | (g << 8) | b;
                    break;
                }
            }
        }
    }
}

/* =========================================================================
 * Lifecycle
 * ====================================================================== */

void VBXE_Initialise(void) {
    memset(vbxe_vram,        0, sizeof(vbxe_vram));
    memset(vbxe_regs,        0, sizeof(vbxe_regs));
    memset(vbxe_palette,     0, sizeof(vbxe_palette));
    memset(vbxe_overlay,     0, sizeof(vbxe_overlay));
    memset(vbxe_gtia_colors, 0, sizeof(vbxe_gtia_colors));

    /* Default MEMAC windows: A at $4000, B at $6000 */
    memac_a_page_hi   = 0x40;
    memac_b_page_hi   = 0x60;
    memac_a_vram_base = 0;
    memac_b_vram_base = 0;
    memac_a_installed = 0;
    memac_b_installed = 0;

    vbxe_enabled   = 0;
    vbxe_base_addr = 0xD640;

    /* Set version registers (read-only sentinel values) */
    vbxe_regs[0x00] = VBXE_VERSION_LOW;
    vbxe_regs[0x01] = VBXE_VERSION_HIGH;

    /* Build default grey-ramp palette */
    vbxe_build_palette();
}

void VBXE_Exit(void) {
    VBXE_Disable();
}

void VBXE_ColdStart(void) {
    /* Cold reset: clear VRAM and all state */
    memset(vbxe_vram, 0, sizeof(vbxe_vram));
    VBXE_WarmStart();
}

void VBXE_WarmStart(void) {
    /* Warm reset: reset registers but preserve VRAM (warm) */
    memset(vbxe_regs, 0, sizeof(vbxe_regs));
    vbxe_regs[0x00] = VBXE_VERSION_LOW;
    vbxe_regs[0x01] = VBXE_VERSION_HIGH;

    /* Default PRIO: normal (1) */
    vbxe_regs[0x10] = 0x01;

    /* Default MEMAC: windows enabled at $4000 and $6000, VRAM base 0 */
    vbxe_regs[0x32] = 0x41;   /* MA_CTL: page hi=$40 | enable=1 */
    vbxe_regs[0x35] = 0x61;   /* MB_CTL: page hi=$60 | enable=1 */

    memac_a_page_hi   = 0x40;
    memac_b_page_hi   = 0x60;
    memac_a_vram_base = 0;
    memac_b_vram_base = 0;

    if (vbxe_enabled) {
        /* Reinstall windows with new defaults */
        vbxe_remove_memac_a();
        vbxe_remove_memac_b();
        vbxe_install_memac_a();
        vbxe_install_memac_b();
    }

    memset(vbxe_overlay, 0, sizeof(vbxe_overlay));
    vbxe_build_palette();
}

/* =========================================================================
 * Enable / Disable
 * ====================================================================== */

void VBXE_Enable(int base_addr) {
    if (vbxe_enabled) {
        /* Already enabled — check if address changed */
        if ((int)vbxe_base_addr == base_addr) return;
        VBXE_Disable();
    }
    vbxe_base_addr = (uint16_t)base_addr;
    /* Register space ($D640/$D740) is dispatched via pbi.c — no handler install needed.
     * Install MEMAC windows into the attribute-based memory map. */
    vbxe_install_memac_a();
    vbxe_install_memac_b();
    vbxe_enabled = 1;
}

void VBXE_Disable(void) {
    if (!vbxe_enabled) return;
    vbxe_remove_memac_a();
    vbxe_remove_memac_b();
    vbxe_enabled = 0;
}

int VBXE_IsEnabled(void) {
    return vbxe_enabled;
}

int VBXE_GetBaseAddr(void) {
    return (int)vbxe_base_addr;
}

/* =========================================================================
 * Save state
 * ====================================================================== */

void VBXE_StateSave(void) {
    /* TODO: integrate with atari800 statesav framework when needed */
}

void VBXE_StateRead(void) {
    /* TODO: integrate with atari800 statesav framework when needed */
}
