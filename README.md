# FujiFoundation

**FujiFoundation** is a macOS fork of [Atari800MacX](https://github.com/atarimacosx/Atari800MacX), the macOS port of the [Atari800](https://atari800.github.io/) emulator. It targets macOS 13+ (arm64/x86_64) and includes modernization work to bring the codebase up to current Xcode/macOS standards.

## What's Here

```
atari800-MacOSX/        ← macOS app (Xcode project, source, NIBs/XIBs, assets)
scripts/                ← build and release automation
ExportOptions.plist     ← notarization export config
MODERNIZATION_BLUEPRINT.md ← phase-by-phase modernization notes
LEGAL.md                ← third-party attribution
LICENSE                 ← GPL v2
```

## Building

```bash
cd atari800-MacOSX/src/Atari800MacX
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -configuration Development -scheme Atari800MacX
```

Requires: macOS 13+, Xcode 15+, SDL2.framework (bundled).

## Modernization

See [MODERNIZATION_BLUEPRINT.md](MODERNIZATION_BLUEPRINT.md) for the full history of changes from the upstream fork, including:

- Xcode project modernization (Phase 1)
- NIB → XIB migration (Phase 3)
- ARC migration (Phase 4.3)
- Metal rendering pipeline (Phase 5)
- Swift/SwiftUI interoperability (Phases 6–7)
- VBXE emulation (Phase VBXE)
- Code signing & notarization (Phase 9)

## Upstream

This project tracks [atarimacosx/Atari800MacX](https://github.com/atarimacosx/Atari800MacX).
Upstream changes are merged into this repo periodically.

## License

GPL v2. See [LICENSE](LICENSE) and [LEGAL.md](LEGAL.md).
