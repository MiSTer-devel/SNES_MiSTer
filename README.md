# SNES_MiSTer — RetroAchievements Fork

This is a fork of the official [SNES core for MiSTer](https://github.com/MiSTer-devel/SNES_MiSTer) with modifications to support **RetroAchievements** on MiSTer FPGA.

> **Status:** Experimental / Proof of Concept — works together with the [modified Main_MiSTer binary](https://github.com/odelot/Main_MiSTer).

## What's Different from the Original

The upstream SNES core is a cycle-accurate FPGA SNES replica. This fork adds a new module and minor wiring changes so the ARM side (Main_MiSTer) can read emulated SNES RAM for achievement evaluation. **No emulation logic was changed** — the core plays games identically to the original.

### Added File

| File | Purpose |
|------|---------|
| `rtl/ra_ram_mirror_snes.sv` | Reads emulated SNES RAM and writes it to DDRAM so the ARM CPU can access it |

### Modified Files

| File | Change |
|------|--------|
| `SNES.sv` | Instantiates `ra_ram_mirror_snes`, adds DDRAM read/write channels for RA, multiplexes SNI and BSRAM ports |
| `files.qip` | Adds `rtl/ra_ram_mirror_snes.sv` to the Quartus project |

### How the RAM Mirror Works

Unlike the NES core (which copies all RAM every frame), the SNES core uses a **selective address protocol** due to the much larger RAM space (128 KB WRAM + up to 256 KB BSRAM):

1. The **ARM binary** writes a list of addresses it needs to evaluate to DDRAM offset `0x40000` (typically ~185 addresses per frame).
2. On each **VBlank**, the FPGA module reads only those requested addresses from WRAM (via the SNI port) and BSRAM (via a dedicated port), and writes the values to DDRAM offset `0x48000`.
3. The ARM binary reads the values back and feeds them to the rcheevos achievement engine.

This request/response approach keeps per-frame overhead to ~30 µs instead of copying hundreds of kilobytes.

**Memory regions exposed:**

| Region | SNES Address | Size | DDRAM Offset | Description |
|--------|-------------|------|--------------|-------------|
| WRAM | $000000–$01FFFF | 128 KB | `0x100` | CPU work RAM |
| BSRAM | $020000+ | Up to 256 KB | `0x20100` | Cartridge save RAM (size from cart header) |

### DDRAM Layout

```
0x00000   Header:     magic ("RACH") + region count + flags + frame counter
0x00100   WRAM:       128 KB mirror
0x20100   BSRAM:      up to 256 KB mirror
0x40000   AddrReq:    ARM → FPGA address request list (count + request_id + addresses)
0x48000   ValResp:    FPGA → ARM value response cache (response_id + values)
```

### FPGA Integration Details

- **SNI port multiplexing**: when the RA mirror is active (`ra_active`), it takes over the SNI read port to fetch WRAM bytes; otherwise the port operates normally.
- **BSRAM port arbitration**: RA reads are interleaved with normal game access via priority logic.
- **DDRAM arbiter**: extended with dedicated read/write channels for the RA mirror, separate from savestates (ch0) and MSU-1 audio (ch1).
- **BSRAM size**: computed from `ram_mask` in the cartridge header and passed to the mirror module.

### Architecture Diagram

```
┌───────────────────────────────────────┐
│          SNES FPGA Core               │
│                                       │
│  WRAM (128KB)       BSRAM (≤256KB)    │
│   via SNI port       via BSRAM port   │
└─────────┬─────────────┬──────────────┘
          │  VBlank     │
          ▼             ▼
┌───────────────────────────────────────┐
│     ra_ram_mirror_snes.sv             │
│  Reads requested addrs from SNI/BSRAM │
│  Writes header + values to DDRAM      │
└─────────────┬─────────────────────────┘
              │  DDRAM @ 0x3D000000
              ▼
┌───────────────────────────────────────┐
│     Main_MiSTer (ARM binary)          │
│  mmap /dev/mem → reads mirror         │
│  Writes address list → reads values   │
│  rcheevos evaluates achievements      │
└───────────────────────────────────────┘
```

## How to Try It

1. Download the latest SNES core binary (`SNES_*.rbf`) from the [Releases](https://github.com/odelot/SNES_MiSTer/releases) page.
2. Copy the `.rbf` file to `/media/fat/_Console/` on your MiSTer SD card (replacing or alongside the stock SNES core).
3. You will also need the **modified Main_MiSTer binary** from [odelot/Main_MiSTer](https://github.com/odelot/Main_MiSTer) — follow the setup instructions there to configure your RetroAchievements credentials.
4. Reboot your MiSTer, load the SNES core, and open a game that has achievements on [retroachievements.org](https://retroachievements.org/).

## Building from Source

Open the project in Quartus Prime (use the same version as the upstream MiSTer SNES core) and compile. The `ra_ram_mirror_snes.sv` file is already included in `files.qip`.

## Links

- Original SNES core: [MiSTer-devel/SNES_MiSTer](https://github.com/MiSTer-devel/SNES_MiSTer)
- Modified Main binary (required): [odelot/Main_MiSTer](https://github.com/odelot/Main_MiSTer)
- RetroAchievements: [retroachievements.org](https://retroachievements.org/)

---

# Original SNES Core Documentation

*Everything below is from the upstream [SNES_MiSTer](https://github.com/MiSTer-devel/SNES_MiSTer) README and applies unchanged to this fork.*

## [Super Nintendo Entertainment System](https://en.wikipedia.org/wiki/Super_Nintendo_Entertainment_System) for [MiSTer Platform](https://github.com/MiSTer-devel/Main_MiSTer/wiki)

Written by [srg320](https://github.com/srg320)

## Features
* Cycle accurate SNES replica.
* Supports LoROM, HiROM, ExHiROM.
* Supports additional chips: DSP-1/2/3/4, ST010, CX4, SDD1, SuperFX(GSU-1/2), SA1, OBC1, SPC7110, S-RTC, BSX, Sufami Turbo.
* MSU-1 Support (1GB max).
* Save states support incl chips SA1, DSP and SuperFX.
* Cheat engine.
* Save/Load Backup RAM.
* Supports mouse.
* Light gun support via Wiimote, mouse or analog stick.
* [SuperFX Turbo and CPU Turbo.](https://github.com/MiSTer-devel/SNES_MiSTer/blob/master/SNES_Turbo.md)

## Installation
* Copy \*.rbf to root of SD card. Put some ROMs (\*.SFC, \*.SMC, \*.BIN) into games\SNES folder.
* Save states: Place [boot1.rom](https://github.com/MiSTer-devel/SNES_MiSTer/raw/master/releases/boot1.rom) in games\SNES folder.
* BSX: Place bsx_bios.rom in games\SNES folder.
