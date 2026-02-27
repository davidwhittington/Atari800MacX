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

Fuji-concepts is a fork maintained by David Whittington, built on [Atari800MacX](http://atarimac.com), the macOS port of the Atari800 emulator created by Perry McFarlane. Atari800 is developed by the Atari800 open-source community. Additional components include the SDL port by Jacek Poplawski and the R: device driver by Daniel Noguerol.


