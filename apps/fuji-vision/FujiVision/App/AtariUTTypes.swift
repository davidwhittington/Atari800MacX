/* AtariUTTypes.swift — UTType constants for Atari media files
 *
 * These match the UTImportedTypeDeclarations in Info.plist.
 * Used by fileImporter to filter the file picker by media type.
 */

import UniformTypeIdentifiers

extension UTType {
    /// .atr, .atz disk images
    static let atariDiskATR = UTType("com.fujiconcepts.atari-disk-atr")!
    /// .xfd, .dcm disk images
    static let atariDiskXFD = UTType("com.fujiconcepts.atari-disk-xfd")!
    /// .car, .rom, .bin cartridge images
    static let atariCartridge = UTType("com.fujiconcepts.atari-cartridge")!
    /// .xex, .com, .exe, .obx executables
    static let atariExecutable = UTType("com.fujiconcepts.atari-executable")!
    /// .cas cassette images
    static let atariCassette = UTType("com.fujiconcepts.atari-cassette")!
    /// .a8s save states
    static let atariSaveState = UTType("com.fujiconcepts.atari-savestate")!

    /// All Atari media types combined
    static let allAtariMedia: [UTType] = [
        .atariDiskATR, .atariDiskXFD, .atariCartridge,
        .atariExecutable, .atariCassette, .atariSaveState
    ]
}
