FujiConcepts/
  README.md
  LICENSE
  .gitignore
  .gitattributes

  docs/
    ARCHITECTURE.md
    CAPABILITIES_MATRIX.md
    ROADMAP.md
    decisions/
      ADR-0001-repo-structure.md
      ADR-0002-fuji-services-backplane.md

  packages/                         # shared “building blocks”
    emu-core/                       # emulator core (C/C++)
    platform/                       # shared platform glue (Objective-C/Swift)
    render-metal/                   # Metal renderer + shaders
    audio/                          # audio engine + sync helpers
    input/                          # gamepad/keyboard abstractions
    media/                          # ATR/XEX/CAR/CAS loaders + hashing
    config/                         # profiles + fingerprints
    fuji-services/                  # session orchestration + transport + sync
    plugins/                        # plugin host + API (Dynasty uses most)

  apps/                             # shipping products
    fuji-swift/                     # macOS instant-play
    fuji-foundation/                # macOS full featured
    fuji-dynasty/                   # macOS foundation + modules
    fuji-vision/                    # visionOS app

  modules/                          # Dynasty add-ons (optional)
    fujinet-online/
    fuji-link/
    future/

  tools/                            # dev scripts, packaging, CI utilities
    scripts/
    signing/
    release/

  third_party/                      # vendored deps (if any)
  samples/                          # known-good ROM-less sample configs + tests
  .github/
    workflows/
