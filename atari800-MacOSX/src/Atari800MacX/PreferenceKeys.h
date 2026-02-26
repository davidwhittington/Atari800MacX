/* PreferenceKeys.h - Typed NSString constants for all NSUserDefaults preference keys.
   Part of Atari800MacX — Phase 2 modernization (emulation core isolation).

   PURPOSE:
     Replaces the #define macros in Preferences.h with typed NSString * const values.
     Typed constants provide:
       - Compiler checking (no implicit conversion to arbitrary objects)
       - "Jump to definition" and rename support in Xcode
       - Cleaner Swift interoperability (imported as String constants)

   MIGRATION:
     The existing #define macros in Preferences.h remain valid during migration.
     New code should use these constants. Old code can be updated incrementally.

   USAGE (Objective-C):
       #import "PreferenceKeys.h"
       [[NSUserDefaults standardUserDefaults] boolForKey:PrefKeyShowFPS];

   USAGE (Swift — after adding PreferenceKeys.h to the bridging header):
       UserDefaults.standard.bool(forKey: PrefKey.showFPS)
*/

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/* -------------------------------------------------------------------------
   Display / Video
   ------------------------------------------------------------------------- */
extern NSString * const PrefKeyScaleFactor;          // @"ScaleFactor"
extern NSString * const PrefKeyScaleFactorFloat;     // @"ScaleFactorFloat"
extern NSString * const PrefKeyScaleMode;            // @"ScaleMode"
extern NSString * const PrefKeyWidthMode;            // @"WidthMode"
extern NSString * const PrefKeyTvMode;               // @"TvMode"
extern NSString * const PrefKeyEmulationSpeed;       // @"EmulationSpeed"
extern NSString * const PrefKeyRefreshRatio;         // @"RefreshRatio"
extern NSString * const PrefKeySpriteCollisions;     // @"SpriteCollisions"
extern NSString * const PrefKeyArtifactingMode;      // @"ArtifactingMode"
extern NSString * const PrefKeyArtifactNew;          // @"ArtifactNew"
extern NSString * const PrefKeyUseBuiltinPalette;    // @"UseBuiltinPalette"
extern NSString * const PrefKeyAdjustPalette;        // @"AdjustPalette"
extern NSString * const PrefKeyBlackLevel;           // @"BlackLevel"
extern NSString * const PrefKeyWhiteLevel;           // @"WhiteLevel"
extern NSString * const PrefKeyIntensity;            // @"Instensity" (sic — preserves existing key)
extern NSString * const PrefKeyColorShift;           // @"ColorShift"
extern NSString * const PrefKeyPaletteFile;          // @"PaletteFile"
extern NSString * const PrefKeyOnlyIntegralScaling;  // @"OnlyIntegralScaling"
extern NSString * const PrefKeyFixAspectFullscreen;  // @"FixAspectFullscreen"
extern NSString * const PrefKeyVsyncDisabled;        // @"VsyncDisabled"
extern NSString * const PrefKeyShowFPS;              // @"ShowFPS"

/* -------------------------------------------------------------------------
   LED / HUD indicators
   ------------------------------------------------------------------------- */
extern NSString * const PrefKeyLedStatus;            // @"LedStatus"
extern NSString * const PrefKeyLedSector;            // @"LedSector"
extern NSString * const PrefKeyLedStatusMedia;       // @"LedStatusMedia"
extern NSString * const PrefKeyLedSectorMedia;       // @"LedSectorMedia"
extern NSString * const PrefKeyLedHDSector;          // @"LedHDSector"
extern NSString * const PrefKeyLedFKeys;             // @"LedFKeys"
extern NSString * const PrefKeyLedCapsLock;          // @"LedCapsLock"

/* -------------------------------------------------------------------------
   80-column / auxiliary display hardware
   ------------------------------------------------------------------------- */
extern NSString * const PrefKeyXEP80Enabled;         // @"XEP80Enabled"
extern NSString * const PrefKeyXEP80Autoswitch;      // @"XEP80Autoswitch"
extern NSString * const PrefKeyXEP80Port;            // @"XEP80Port"
extern NSString * const PrefKeyXEP80OnColor;         // @"XEP80OnColor"
extern NSString * const PrefKeyXEP80OffColor;        // @"XEP800OffColor" (sic — preserves existing key)
extern NSString * const PrefKeyXEP80;                // @"XEP80"
extern NSString * const PrefKeyAF80Enabled;          // @"AF80Enabled"
extern NSString * const PrefKeyAF80RomFile;          // @"AF80RomFile"
extern NSString * const PrefKeyAF80CharsetFile;      // @"AF80CharsetFile"
extern NSString * const PrefKeyBit3Enabled;          // @"Bit3Enabled"
extern NSString * const PrefKeyBit3RomFile;          // @"Bit3RomFile"
extern NSString * const PrefKeyBit3CharsetFile;      // @"Bit3CharsetFile"

/* -------------------------------------------------------------------------
   Machine type
   ------------------------------------------------------------------------- */
extern NSString * const PrefKeyAtariType;            // @"AtariType"
extern NSString * const PrefKeyAtariTypeVer4;        // @"AtariTypeVer4"
extern NSString * const PrefKeyAtariTypeVer5;        // @"AtariTypeVer5"
extern NSString * const PrefKeyAtariSwitchType;      // @"AtariSwitchType"
extern NSString * const PrefKeyAtariSwitchTypeVer4;  // @"AtariSwitchTypeVer4"
extern NSString * const PrefKeyAtariSwitchTypeVer5;  // @"AtariSwitchTypeVer5"
extern NSString * const PrefKeyA1200XLJumper;        // @"A1200XLJumper"
extern NSString * const PrefKeyXEGSKeyboard;         // @"XEGSKeyboard"

/* -------------------------------------------------------------------------
   Memory expansion
   ------------------------------------------------------------------------- */
extern NSString * const PrefKeyAxlonBankMask;        // @"AxlonBankMask"
extern NSString * const PrefKeyMosaicMaxBank;         // @"MosaicMaxBank"

/* -------------------------------------------------------------------------
   Expansion hardware
   ------------------------------------------------------------------------- */
extern NSString * const PrefKeyMioEnabled;           // @"MioEnabled"
extern NSString * const PrefKeyMioRomFile;           // @"MioRomFile"
extern NSString * const PrefKeyMioScsiDiskFile;      // @"MioScsiDiskFile"
extern NSString * const PrefKeyBlackBoxEnabled;      // @"BlackBoxEnabled"
extern NSString * const PrefKeyBlackBoxRomFile;      // @"BlackBoxRomFile"
extern NSString * const PrefKeyBlackBoxScsiDiskFile; // @"BlackBoxScsiDiskFile"
extern NSString * const PrefKeyUltimate1MBRomFile;   // @"Ultimate1MBRomFile"
extern NSString * const PrefKeySide2RomFile;         // @"Side2RomFile"
extern NSString * const PrefKeySide2CFFile;          // @"Side2CFFile"
extern NSString * const PrefKeySide2SDXMode;         // @"Side2SDXMode"
extern NSString * const PrefKeySide2UltimateFlashType; // @"Side2UltimateFlashType"

/* -------------------------------------------------------------------------
   Emulation patches / compatibility
   ------------------------------------------------------------------------- */
extern NSString * const PrefKeyDisableBasic;         // @"DisableBasic"
extern NSString * const PrefKeyDisableAllBasic;      // @"DisableAllBasic"
extern NSString * const PrefKeyEnableSioPatch;       // @"EnableSioPatch"
extern NSString * const PrefKeyEnableHPatch;         // @"EnableHPatch"
extern NSString * const PrefKeyEnableDPatch;         // @"EnableDPatch"
extern NSString * const PrefKeyEnablePPatch;         // @"EnablePPatch"
extern NSString * const PrefKeyEnableRPatch;         // @"EnableRPatch"
extern NSString * const PrefKeyRPatchPort;           // @"RPatchPort"
extern NSString * const PrefKeyRPatchSerialEnabled;  // @"RPatchSerialEnabled"
extern NSString * const PrefKeyRPatchSerialPort;     // @"RPatchSerialPort"
extern NSString * const PrefKeyFujiNetEnabled;       // @"FujiNetEnabled"
extern NSString * const PrefKeyFujiNetPort;          // @"FujiNetPort"

/* -------------------------------------------------------------------------
   Printer
   ------------------------------------------------------------------------- */
extern NSString * const PrefKeyPrintCommand;         // @"PrintCommand"
extern NSString * const PrefKeyPrinterType;          // @"PrinterType"
extern NSString * const PrefKeyAtari825CharSet;      // @"Atari825CharSet"
extern NSString * const PrefKeyAtari825FormLength;   // @"Atari825FormLength"
extern NSString * const PrefKeyAtari825AutoLinefeed; // @"Atari825AutoLinefeed"
extern NSString * const PrefKeyAtari1020PrintWidth;  // @"Atari1020PrintWidth"
extern NSString * const PrefKeyAtari1020FormLength;  // @"Atari1020FormLength"
extern NSString * const PrefKeyAtari1020AutoLinefeed; // @"Atari825AutoLinefeed" (sic — preserves existing key)
extern NSString * const PrefKeyAtari1020AutoPageAdjust; // @"Atari1020AutoPageAdjust"
extern NSString * const PrefKeyAtari1020Pen1Red;     // @"Atari1020Pen1Red"
extern NSString * const PrefKeyAtari1020Pen1Green;   // @"Atari1020Pen1Green"
extern NSString * const PrefKeyAtari1020Pen1Blue;    // @"Atari1020Pen1Blue"
extern NSString * const PrefKeyAtari1020Pen1Alpha;   // @"Atari1020Pen1Alpha"
extern NSString * const PrefKeyAtari1020Pen2Red;     // @"Atari1020Pen2Red"
extern NSString * const PrefKeyAtari1020Pen2Green;   // @"Atari1020Pen2Green"
extern NSString * const PrefKeyAtari1020Pen2Blue;    // @"Atari1020Pen2Blue"
extern NSString * const PrefKeyAtari1020Pen2Alpha;   // @"Atari1020Pen2Alpha"
extern NSString * const PrefKeyAtari1020Pen3Red;     // @"Atari1020Pen3Red"
extern NSString * const PrefKeyAtari1020Pen3Green;   // @"Atari1020Pen3Green"
extern NSString * const PrefKeyAtari1020Pen3Blue;    // @"Atari1020Pen3Blue"
extern NSString * const PrefKeyAtari1020Pen3Alpha;   // @"Atari1020Pen3Alpha"
extern NSString * const PrefKeyAtari1020Pen4Red;     // @"Atari1020Pen4Red"
extern NSString * const PrefKeyAtari1020Pen4Green;   // @"Atari1020Pen4Green"
extern NSString * const PrefKeyAtari1020Pen4Blue;    // @"Atari1020Pen4Blue"
extern NSString * const PrefKeyAtari1020Pen4Alpha;   // @"Atari1020Pen4Alpha"
extern NSString * const PrefKeyAtasciiFormLength;    // @"AtasciiFormLength"
extern NSString * const PrefKeyAtasciiCharSize;      // @"AtasciiCharSize"
extern NSString * const PrefKeyAtasciiLineGap;       // @"AtasciiLineGap"
extern NSString * const PrefKeyAtasciiFont;          // @"AtasciiFont"
extern NSString * const PrefKeyEpsonCharSet;         // @"EpsonCharSet"
extern NSString * const PrefKeyEpsonPrintPitch;      // @"EpsonPrintPitch"
extern NSString * const PrefKeyEpsonPrintWeight;     // @"EpsonPrintWeight"
extern NSString * const PrefKeyEpsonFormLength;      // @"EpsonFormLength"
extern NSString * const PrefKeyEpsonAutoLinefeed;    // @"EpsonAutoLinefeed"
extern NSString * const PrefKeyEpsonPrintSlashedZeros; // @"EpsonPrintSlashedZeros"
extern NSString * const PrefKeyEpsonAutoSkip;        // @"EpsonAutoSkip"
extern NSString * const PrefKeyEpsonSplitSkip;       // @"EpsonSplitSkip"

/* -------------------------------------------------------------------------
   Audio
   ------------------------------------------------------------------------- */
extern NSString * const PrefKeyBootFromCassette;     // @"BootFromCassette"
extern NSString * const PrefKeySpeedLimit;           // @"SpeedLimit"
extern NSString * const PrefKeyEnableSound;          // @"EnableSound"
extern NSString * const PrefKeySoundVolume;          // @"SoundVolume"
extern NSString * const PrefKeyEnableStereo;         // @"EnableStereo"
extern NSString * const PrefKeyEnable16BitSound;     // @"Enable16BitSound"
extern NSString * const PrefKeyEnableConsoleSound;   // @"EnableConsoleSound"
extern NSString * const PrefKeyEnableSerioSound;     // @"EnableSerioSound"
extern NSString * const PrefKeyDiskDriveSound;       // @"DiskDriveSound"
extern NSString * const PrefKeyDontMuteAudio;        // @"DontMuteAudio"

/* -------------------------------------------------------------------------
   Input / Joystick
   ------------------------------------------------------------------------- */
extern NSString * const PrefKeyEnableMultijoy;       // @"EnableMultijoy"
extern NSString * const PrefKeyIgnoreHeaderWriteprotect; // @"IgnoreHeaderWriteprotect"
extern NSString * const PrefKeyJoystick1Mode;        // @"Joystick1Mode_v13"
extern NSString * const PrefKeyJoystick2Mode;        // @"Joystick2Mode_v13"
extern NSString * const PrefKeyJoystick3Mode;        // @"Joystick3Mode_v13"
extern NSString * const PrefKeyJoystick4Mode;        // @"Joystick4Mode_v13"
extern NSString * const PrefKeyUseAtariCursorKeys;   // @"UseAtariCursorKeys"

/* -------------------------------------------------------------------------
   Directories and ROM paths
   ------------------------------------------------------------------------- */
extern NSString * const PrefKeyImageDir;             // @"ImageDir"
extern NSString * const PrefKeyPrintDir;             // @"PrintDir"
extern NSString * const PrefKeyHardDiskDir1;         // @"HardDiskDir1"
extern NSString * const PrefKeyHardDiskDir2;         // @"HardDiskDir2"
extern NSString * const PrefKeyHardDiskDir3;         // @"HardDiskDir3"
extern NSString * const PrefKeyHardDiskDir4;         // @"HardDiskDir4"
extern NSString * const PrefKeyHardDrivesReadOnly;   // @"HardDrivesReadOnly"
extern NSString * const PrefKeyHPath;                // @"HPath"
extern NSString * const PrefKeyPCLinkDeviceEnable;   // @"PCLinkDeviceEnable"
extern NSString * const PrefKeyPCLinkDir1;           // @"PCLinkDir1"
extern NSString * const PrefKeyPCLinkDir2;           // @"PCLinkDir2"
extern NSString * const PrefKeyPCLinkDir3;           // @"PCLinkDir3"
extern NSString * const PrefKeyPCLinkDir4;           // @"PCLinkDir4"
extern NSString * const PrefKeyXEGSRomFile;          // @"XEGSRomFile"
extern NSString * const PrefKeyXEGSGameRomFile;      // @"XEGSGameRomFile"
extern NSString * const PrefKeyA1200XLRomFile;       // @"A1200XLRomFile"
extern NSString * const PrefKeyOsBRomFile;           // @"OsBRomFile"
extern NSString * const PrefKeyXlRomFile;            // @"XlRomFile"
extern NSString * const PrefKeyBasicRomFile;         // @"BasicRomFile"
extern NSString * const PrefKeyA5200RomFile;         // @"A5200RomFile"
extern NSString * const PrefKeyUseAltirraXEGSRom;    // @"UseAltiraXEGSRom"
extern NSString * const PrefKeyUseAltirra1200XLRom;  // @"UseAltira1200XLRom"
extern NSString * const PrefKeyUseAltirraOSBRom;     // @"UseAltiraOSBRom"
extern NSString * const PrefKeyUseAltirraXLRom;      // @"UseAltiraXLRom"
extern NSString * const PrefKeyUseAltirra5200Rom;    // @"UseAltira5200Rom"
extern NSString * const PrefKeyUseAltirraBasicRom;   // @"UseAltiraBasicRom"
extern NSString * const PrefKeyDiskImageDir;         // @"DiskImageDir"
extern NSString * const PrefKeyDiskSetDir;           // @"DiskSetDir"
extern NSString * const PrefKeyCartImageDir;         // @"CartImageDir"
extern NSString * const PrefKeyCassImageDir;         // @"CassImageDir"
extern NSString * const PrefKeyExeFileDir;           // @"ExeFileDir"
extern NSString * const PrefKeySavedStateDir;        // @"SavedStateDir"
extern NSString * const PrefKeyConfigDir;            // @"ConfigDir"

/* -------------------------------------------------------------------------
   Currently loaded media
   ------------------------------------------------------------------------- */
extern NSString * const PrefKeyD1File;               // @"D1File"
extern NSString * const PrefKeyD2File;               // @"D2File"
extern NSString * const PrefKeyD3File;               // @"D3File"
extern NSString * const PrefKeyD4File;               // @"D4File"
extern NSString * const PrefKeyD5File;               // @"D5File"
extern NSString * const PrefKeyD6File;               // @"D6File"
extern NSString * const PrefKeyD7File;               // @"D7File"
extern NSString * const PrefKeyD8File;               // @"D8File"
extern NSString * const PrefKeyCartFile;             // @"CartFile"
extern NSString * const PrefKeyCart2File;            // @"Cart2File"
extern NSString * const PrefKeyExeFile;              // @"ExeFile"
extern NSString * const PrefKeyCassFile;             // @"CassFile"
extern NSString * const PrefKeyD1FileEnabled;        // @"D1FileEnabled"
extern NSString * const PrefKeyD2FileEnabled;        // @"D2FileEnabled"
extern NSString * const PrefKeyD3FileEnabled;        // @"D3FileEnabled"
extern NSString * const PrefKeyD4FileEnabled;        // @"D4FileEnabled"
extern NSString * const PrefKeyD5FileEnabled;        // @"D5FileEnabled"
extern NSString * const PrefKeyD6FileEnabled;        // @"D6FileEnabled"
extern NSString * const PrefKeyD7FileEnabled;        // @"D7FileEnabled"
extern NSString * const PrefKeyD8FileEnabled;        // @"D8FileEnabled"
extern NSString * const PrefKeyCartFileEnabled;      // @"CartFileEnabled"
extern NSString * const PrefKeyCart2FileEnabled;     // @"Cart2FileEnabled"
extern NSString * const PrefKeyExeFileEnabled;       // @"ExeFileEnabled"
extern NSString * const PrefKeyCassFileEnabled;      // @"CassFileEnabled"

/* -------------------------------------------------------------------------
   UI state
   ------------------------------------------------------------------------- */
extern NSString * const PrefKeyMediaStatusDisplayed;   // @"MediaStatusDisplayed"
extern NSString * const PrefKeyFunctionKeysDisplayed;  // @"FunctionKeysDisplayed"
extern NSString * const PrefKeySaveCurrentMedia;       // @"SaveCurrentMedia"
extern NSString * const PrefKeyClearCurrentMedia;      // @"ClearCurrentMedia"
extern NSString * const PrefKeyKeyjoyEnable;           // @"KeyjoyEnable"  (NOTE: look up exact key)
extern NSString * const PrefKeyCurrPrinter;            // @"CurrPrinter"

NS_ASSUME_NONNULL_END
