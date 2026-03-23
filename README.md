# FujiConcepts (private)

A private monorepo for the **Fuji** family of Atari 800 emulators for macOS — modernized,
arm64-native, and built on the [atari800](https://atari800.github.io) core.

## Structure

```
apps/
  fuji-foundation/   ← git submodule → github.com/davidwhittington/FujiFoundation (public, GPL v2)
  fuji-vision/       ← visionOS app
  fuji-swift/        ← lightweight macOS variant (scaffold)
  fuji-dynasty/      ← modular feature-rich variant (scaffold)
  fuji-services/     ← Go backend services (FSSP, bridge, edge, TNFS proxy)
web/                 ← beta.fujiconcepts.com site
docs/                ← shared documentation
```

## Submodule: fuji-foundation

`apps/fuji-foundation` is a git submodule pointing to the public
[FujiFoundation](https://github.com/davidwhittington/FujiFoundation) repo — the
modernized macOS fork of [atarimacosx/Atari800MacX](https://github.com/atarimacosx/Atari800MacX).

After cloning FujiConcepts:

```bash
git submodule update --init --recursive
```

## Apps

| App | Description |
|-----|-------------|
| [fuji-foundation](apps/fuji-foundation) | **Atari800MacOS** — modernized core emulator. Public GPL v2 submodule. |
| [fuji-vision](apps/fuji-vision) | visionOS spatial emulator (Swift + Metal). |
| [fuji-swift](apps/fuji-swift) | Lightweight macOS variant (scaffold). |
| [fuji-dynasty](apps/fuji-dynasty) | Feature-rich modular variant (scaffold). |
| [fuji-services](apps/fuji-services) | Go backend: FSSP, Telnet proxy, relay, INPUT, VIDEO. |

## Heritage

FujiConcepts is maintained by David Whittington. The emulator core is based on
[Atari800MacX](http://atarimac.com) by Perry McFarlane, which ports the
[Atari800](https://atari800.github.io) open-source emulator to macOS.

## Changelog

See [CHANGELOG.md](./CHANGELOG.md) for the full change history.
