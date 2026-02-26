/* PreferenceKeys.m - NSString constant definitions for all NSUserDefaults keys.
   Part of Atari800MacX — Phase 2 modernization.

   Values must match the string literals in Preferences.h exactly so that
   existing NSUserDefaults data is read correctly with both the old #defines
   and these new typed constants.
*/

#import "PreferenceKeys.h"

/* -------------------------------------------------------------------------
   Display / Video
   ------------------------------------------------------------------------- */
NSString * const PrefKeyScaleFactor          = @"ScaleFactor";
NSString * const PrefKeyScaleFactorFloat     = @"ScaleFactorFloat";
NSString * const PrefKeyScaleMode            = @"ScaleMode";
NSString * const PrefKeyWidthMode            = @"WidthMode";
NSString * const PrefKeyTvMode               = @"TvMode";
NSString * const PrefKeyEmulationSpeed       = @"EmulationSpeed";
NSString * const PrefKeyRefreshRatio         = @"RefreshRatio";
NSString * const PrefKeySpriteCollisions     = @"SpriteCollisions";
NSString * const PrefKeyArtifactingMode      = @"ArtifactingMode";
NSString * const PrefKeyArtifactNew          = @"ArtifactNew";
NSString * const PrefKeyUseBuiltinPalette    = @"UseBuiltinPalette";
NSString * const PrefKeyAdjustPalette        = @"AdjustPalette";
NSString * const PrefKeyBlackLevel           = @"BlackLevel";
NSString * const PrefKeyWhiteLevel           = @"WhiteLevel";
NSString * const PrefKeyIntensity            = @"Instensity";     /* sic — matches existing stored key */
NSString * const PrefKeyColorShift           = @"ColorShift";
NSString * const PrefKeyPaletteFile          = @"PaletteFile";
NSString * const PrefKeyOnlyIntegralScaling  = @"OnlyIntegralScaling";
NSString * const PrefKeyFixAspectFullscreen  = @"FixAspectFullscreen";
NSString * const PrefKeyVsyncDisabled        = @"VsyncDisabled";
NSString * const PrefKeyShowFPS              = @"ShowFPS";

/* -------------------------------------------------------------------------
   LED / HUD indicators
   ------------------------------------------------------------------------- */
NSString * const PrefKeyLedStatus            = @"LedStatus";
NSString * const PrefKeyLedSector            = @"LedSector";
NSString * const PrefKeyLedStatusMedia       = @"LedStatusMedia";
NSString * const PrefKeyLedSectorMedia       = @"LedSectorMedia";
NSString * const PrefKeyLedHDSector          = @"LedHDSector";
NSString * const PrefKeyLedFKeys             = @"LedFKeys";
NSString * const PrefKeyLedCapsLock          = @"LedCapsLock";

/* -------------------------------------------------------------------------
   80-column / auxiliary display hardware
   ------------------------------------------------------------------------- */
NSString * const PrefKeyXEP80Enabled         = @"XEP80Enabled";
NSString * const PrefKeyXEP80Autoswitch      = @"XEP80Autoswitch";
NSString * const PrefKeyXEP80Port            = @"XEP80Port";
NSString * const PrefKeyXEP80OnColor         = @"XEP80OnColor";
NSString * const PrefKeyXEP80OffColor        = @"XEP800OffColor"; /* sic — matches existing stored key */
NSString * const PrefKeyXEP80               = @"XEP80";
NSString * const PrefKeyAF80Enabled          = @"AF80Enabled";
NSString * const PrefKeyAF80RomFile          = @"AF80RomFile";
NSString * const PrefKeyAF80CharsetFile      = @"AF80CharsetFile";
NSString * const PrefKeyBit3Enabled          = @"Bit3Enabled";
NSString * const PrefKeyBit3RomFile          = @"Bit3RomFile";
NSString * const PrefKeyBit3CharsetFile      = @"Bit3CharsetFile";

/* -------------------------------------------------------------------------
   Machine type
   ------------------------------------------------------------------------- */
NSString * const PrefKeyAtariType            = @"AtariType";
NSString * const PrefKeyAtariTypeVer4        = @"AtariTypeVer4";
NSString * const PrefKeyAtariTypeVer5        = @"AtariTypeVer5";
NSString * const PrefKeyAtariSwitchType      = @"AtariSwitchType";
NSString * const PrefKeyAtariSwitchTypeVer4  = @"AtariSwitchTypeVer4";
NSString * const PrefKeyAtariSwitchTypeVer5  = @"AtariSwitchTypeVer5";
NSString * const PrefKeyA1200XLJumper        = @"A1200XLJumper";
NSString * const PrefKeyXEGSKeyboard         = @"XEGSKeyboard";

/* -------------------------------------------------------------------------
   Memory expansion
   ------------------------------------------------------------------------- */
NSString * const PrefKeyAxlonBankMask        = @"AxlonBankMask";
NSString * const PrefKeyMosaicMaxBank        = @"MosaicMaxBank";

/* -------------------------------------------------------------------------
   Expansion hardware
   ------------------------------------------------------------------------- */
NSString * const PrefKeyMioEnabled           = @"MioEnabled";
NSString * const PrefKeyMioRomFile           = @"MioRomFile";
NSString * const PrefKeyMioScsiDiskFile      = @"MioScsiDiskFile";
NSString * const PrefKeyBlackBoxEnabled      = @"BlackBoxEnabled";
NSString * const PrefKeyBlackBoxRomFile      = @"BlackBoxRomFile";
NSString * const PrefKeyBlackBoxScsiDiskFile = @"BlackBoxScsiDiskFile";
NSString * const PrefKeyUltimate1MBRomFile   = @"Ultimate1MBRomFile";
NSString * const PrefKeySide2RomFile         = @"Side2RomFile";
NSString * const PrefKeySide2CFFile          = @"Side2CFFile";
NSString * const PrefKeySide2SDXMode         = @"Side2SDXMode";
NSString * const PrefKeySide2UltimateFlashType = @"Side2UltimateFlashType";

/* -------------------------------------------------------------------------
   Emulation patches / compatibility
   ------------------------------------------------------------------------- */
NSString * const PrefKeyDisableBasic         = @"DisableBasic";
NSString * const PrefKeyDisableAllBasic      = @"DisableAllBasic";
NSString * const PrefKeyEnableSioPatch       = @"EnableSioPatch";
NSString * const PrefKeyEnableHPatch         = @"EnableHPatch";
NSString * const PrefKeyEnableDPatch         = @"EnableDPatch";
NSString * const PrefKeyEnablePPatch         = @"EnablePPatch";
NSString * const PrefKeyEnableRPatch         = @"EnableRPatch";
NSString * const PrefKeyRPatchPort           = @"RPatchPort";
NSString * const PrefKeyRPatchSerialEnabled  = @"RPatchSerialEnabled";
NSString * const PrefKeyRPatchSerialPort     = @"RPatchSerialPort";
NSString * const PrefKeyFujiNetEnabled       = @"FujiNetEnabled";
NSString * const PrefKeyFujiNetPort          = @"FujiNetPort";

/* -------------------------------------------------------------------------
   Printer
   ------------------------------------------------------------------------- */
NSString * const PrefKeyPrintCommand         = @"PrintCommand";
NSString * const PrefKeyPrinterType          = @"PrinterType";
NSString * const PrefKeyAtari825CharSet      = @"Atari825CharSet";
NSString * const PrefKeyAtari825FormLength   = @"Atari825FormLength";
NSString * const PrefKeyAtari825AutoLinefeed = @"Atari825AutoLinefeed";
NSString * const PrefKeyAtari1020PrintWidth  = @"Atari1020PrintWidth";
NSString * const PrefKeyAtari1020FormLength  = @"Atari1020FormLength";
NSString * const PrefKeyAtari1020AutoLinefeed = @"Atari825AutoLinefeed"; /* sic — matches existing stored key */
NSString * const PrefKeyAtari1020AutoPageAdjust = @"Atari1020AutoPageAdjust";
NSString * const PrefKeyAtari1020Pen1Red     = @"Atari1020Pen1Red";
NSString * const PrefKeyAtari1020Pen1Green   = @"Atari1020Pen1Green";
NSString * const PrefKeyAtari1020Pen1Blue    = @"Atari1020Pen1Blue";
NSString * const PrefKeyAtari1020Pen1Alpha   = @"Atari1020Pen1Alpha";
NSString * const PrefKeyAtari1020Pen2Red     = @"Atari1020Pen2Red";
NSString * const PrefKeyAtari1020Pen2Green   = @"Atari1020Pen2Green";
NSString * const PrefKeyAtari1020Pen2Blue    = @"Atari1020Pen2Blue";
NSString * const PrefKeyAtari1020Pen2Alpha   = @"Atari1020Pen2Alpha";
NSString * const PrefKeyAtari1020Pen3Red     = @"Atari1020Pen3Red";
NSString * const PrefKeyAtari1020Pen3Green   = @"Atari1020Pen3Green";
NSString * const PrefKeyAtari1020Pen3Blue    = @"Atari1020Pen3Blue";
NSString * const PrefKeyAtari1020Pen3Alpha   = @"Atari1020Pen3Alpha";
NSString * const PrefKeyAtari1020Pen4Red     = @"Atari1020Pen4Red";
NSString * const PrefKeyAtari1020Pen4Green   = @"Atari1020Pen4Green";
NSString * const PrefKeyAtari1020Pen4Blue    = @"Atari1020Pen4Blue";
NSString * const PrefKeyAtari1020Pen4Alpha   = @"Atari1020Pen4Alpha";
NSString * const PrefKeyAtasciiFormLength    = @"AtasciiFormLength";
NSString * const PrefKeyAtasciiCharSize      = @"AtasciiCharSize";
NSString * const PrefKeyAtasciiLineGap       = @"AtasciiLineGap";
NSString * const PrefKeyAtasciiFont          = @"AtasciiFont";
NSString * const PrefKeyEpsonCharSet         = @"EpsonCharSet";
NSString * const PrefKeyEpsonPrintPitch      = @"EpsonPrintPitch";
NSString * const PrefKeyEpsonPrintWeight     = @"EpsonPrintWeight";
NSString * const PrefKeyEpsonFormLength      = @"EpsonFormLength";
NSString * const PrefKeyEpsonAutoLinefeed    = @"EpsonAutoLinefeed";
NSString * const PrefKeyEpsonPrintSlashedZeros = @"EpsonPrintSlashedZeros";
NSString * const PrefKeyEpsonAutoSkip        = @"EpsonAutoSkip";
NSString * const PrefKeyEpsonSplitSkip       = @"EpsonSplitSkip";

/* -------------------------------------------------------------------------
   Audio
   ------------------------------------------------------------------------- */
NSString * const PrefKeyBootFromCassette     = @"BootFromCassette";
NSString * const PrefKeySpeedLimit           = @"SpeedLimit";
NSString * const PrefKeyEnableSound          = @"EnableSound";
NSString * const PrefKeySoundVolume          = @"SoundVolume";
NSString * const PrefKeyEnableStereo         = @"EnableStereo";
NSString * const PrefKeyEnable16BitSound     = @"Enable16BitSound";
NSString * const PrefKeyEnableConsoleSound   = @"EnableConsoleSound";
NSString * const PrefKeyEnableSerioSound     = @"EnableSerioSound";
NSString * const PrefKeyDiskDriveSound       = @"DiskDriveSound";
NSString * const PrefKeyDontMuteAudio        = @"DontMuteAudio";

/* -------------------------------------------------------------------------
   Input / Joystick
   ------------------------------------------------------------------------- */
NSString * const PrefKeyEnableMultijoy       = @"EnableMultijoy";
NSString * const PrefKeyIgnoreHeaderWriteprotect = @"IgnoreHeaderWriteprotect";
NSString * const PrefKeyJoystick1Mode        = @"Joystick1Mode_v13";
NSString * const PrefKeyJoystick2Mode        = @"Joystick2Mode_v13";
NSString * const PrefKeyJoystick3Mode        = @"Joystick3Mode_v13";
NSString * const PrefKeyJoystick4Mode        = @"Joystick4Mode_v13";
NSString * const PrefKeyUseAtariCursorKeys   = @"UseAtariCursorKeys";

/* -------------------------------------------------------------------------
   Directories and ROM paths
   ------------------------------------------------------------------------- */
NSString * const PrefKeyImageDir             = @"ImageDir";
NSString * const PrefKeyPrintDir             = @"PrintDir";
NSString * const PrefKeyHardDiskDir1         = @"HardDiskDir1";
NSString * const PrefKeyHardDiskDir2         = @"HardDiskDir2";
NSString * const PrefKeyHardDiskDir3         = @"HardDiskDir3";
NSString * const PrefKeyHardDiskDir4         = @"HardDiskDir4";
NSString * const PrefKeyHardDrivesReadOnly   = @"HardDrivesReadOnly";
NSString * const PrefKeyHPath                = @"HPath";
NSString * const PrefKeyPCLinkDeviceEnable   = @"PCLinkDeviceEnable";
NSString * const PrefKeyPCLinkDir1           = @"PCLinkDir1";
NSString * const PrefKeyPCLinkDir2           = @"PCLinkDir2";
NSString * const PrefKeyPCLinkDir3           = @"PCLinkDir3";
NSString * const PrefKeyPCLinkDir4           = @"PCLinkDir4";
NSString * const PrefKeyXEGSRomFile          = @"XEGSRomFile";
NSString * const PrefKeyXEGSGameRomFile      = @"XEGSGameRomFile";
NSString * const PrefKeyA1200XLRomFile       = @"A1200XLRomFile";
NSString * const PrefKeyOsBRomFile           = @"OsBRomFile";
NSString * const PrefKeyXlRomFile            = @"XlRomFile";
NSString * const PrefKeyBasicRomFile         = @"BasicRomFile";
NSString * const PrefKeyA5200RomFile         = @"A5200RomFile";
NSString * const PrefKeyUseAltirraXEGSRom    = @"UseAltiraXEGSRom";    /* sic */
NSString * const PrefKeyUseAltirra1200XLRom  = @"UseAltira1200XLRom";  /* sic */
NSString * const PrefKeyUseAltirraOSBRom     = @"UseAltiraOSBRom";     /* sic */
NSString * const PrefKeyUseAltirraXLRom      = @"UseAltiraXLRom";      /* sic */
NSString * const PrefKeyUseAltirra5200Rom    = @"UseAltira5200Rom";     /* sic */
NSString * const PrefKeyUseAltirraBasicRom   = @"UseAltiraBasicRom";   /* sic */
NSString * const PrefKeyDiskImageDir         = @"DiskImageDir";
NSString * const PrefKeyDiskSetDir           = @"DiskSetDir";
NSString * const PrefKeyCartImageDir         = @"CartImageDir";
NSString * const PrefKeyCassImageDir         = @"CassImageDir";
NSString * const PrefKeyExeFileDir           = @"ExeFileDir";
NSString * const PrefKeySavedStateDir        = @"SavedStateDir";
NSString * const PrefKeyConfigDir            = @"ConfigDir";

/* -------------------------------------------------------------------------
   Currently loaded media
   ------------------------------------------------------------------------- */
NSString * const PrefKeyD1File               = @"D1File";
NSString * const PrefKeyD2File               = @"D2File";
NSString * const PrefKeyD3File               = @"D3File";
NSString * const PrefKeyD4File               = @"D4File";
NSString * const PrefKeyD5File               = @"D5File";
NSString * const PrefKeyD6File               = @"D6File";
NSString * const PrefKeyD7File               = @"D7File";
NSString * const PrefKeyD8File               = @"D8File";
NSString * const PrefKeyCartFile             = @"CartFile";
NSString * const PrefKeyCart2File            = @"Cart2File";
NSString * const PrefKeyExeFile              = @"ExeFile";
NSString * const PrefKeyCassFile             = @"CassFile";
NSString * const PrefKeyD1FileEnabled        = @"D1FileEnabled";
NSString * const PrefKeyD2FileEnabled        = @"D2FileEnabled";
NSString * const PrefKeyD3FileEnabled        = @"D3FileEnabled";
NSString * const PrefKeyD4FileEnabled        = @"D4FileEnabled";
NSString * const PrefKeyD5FileEnabled        = @"D5FileEnabled";
NSString * const PrefKeyD6FileEnabled        = @"D6FileEnabled";
NSString * const PrefKeyD7FileEnabled        = @"D7FileEnabled";
NSString * const PrefKeyD8FileEnabled        = @"D8FileEnabled";
NSString * const PrefKeyCartFileEnabled      = @"CartFileEnabled";
NSString * const PrefKeyCart2FileEnabled     = @"Cart2FileEnabled";
NSString * const PrefKeyExeFileEnabled       = @"ExeFileEnabled";
NSString * const PrefKeyCassFileEnabled      = @"CassFileEnabled";

/* -------------------------------------------------------------------------
   UI state
   ------------------------------------------------------------------------- */
NSString * const PrefKeyMediaStatusDisplayed   = @"MediaStatusDisplayed";
NSString * const PrefKeyFunctionKeysDisplayed  = @"FunctionKeysDisplayed";
NSString * const PrefKeySaveCurrentMedia       = @"SaveCurrentMedia";
NSString * const PrefKeyClearCurrentMedia      = @"ClearCurrentMedia";
NSString * const PrefKeyKeyjoyEnable           = @"KeyjoyEnable";
NSString * const PrefKeyCurrPrinter            = @"CurrPrinter";
