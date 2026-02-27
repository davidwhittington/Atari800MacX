# fuji-concepts

A monorepo for the **Fuji** family of Atari 800 emulators for macOS — modernized, arm64-native,
and built on the [atari800](https://atari800.github.io) core.

## Apps

| App | Description |
|-----|-------------|
| [fuji-foundation](apps/fuji-foundation) | **Atari800MacOS** — the modernized core. Full-featured Cocoa + Metal emulator. Tracks upstream atari800. |
| [fuji-swift](apps/fuji-swift) | Streamlined, lightweight variant derived from fuji-foundation. |
| [fuji-vision](apps/fuji-vision) | Display-focused variant with enhanced rendering fidelity. |
| [fuji-dynasty](apps/fuji-dynasty) | Feature-rich modular variant — opt-in modules extend the core. |

## Upstream

Upstream changes from [atari800/atari800](https://github.com/atari800/atari800) are integrated
into `apps/fuji-foundation` only. Other apps inherit selectively from there.

```
git remote add upstream https://github.com/atari800/atari800.git
git fetch upstream
# merge into apps/fuji-foundation branch
```

## Heritage

fuji-concepts is a fork of [Atari800MacX](http://atarimac.com) by David Whittington,
itself a macOS port of the Atari800 emulator. Original SDL port by Jacek Poplawski.
R: driver by Daniel Noguerol.
