/* Atari800Engine.h - Objective-C façade over the C emulation core.
   Part of Atari800MacX — Phase 2 modernization (emulation core isolation).

   This class is the ONLY point of contact between the macOS GUI layer and
   the Atari 800 C emulation core. All controller and view code should
   call methods on this class rather than directly invoking C emulator
   functions or accessing emulator globals.

   THREADING MODEL:
     - All public methods are called from the MAIN THREAD unless marked
       with "// emulation thread".
     - The emulation loop (-runEmulationLoop) runs on a dedicated background
       thread managed internally. Do not call it from GUI code.
     - Frame buffer access (-currentFramePixelBuffer) is thread-safe via
       internal double-buffering.

   SWIFT VISIBILITY:
     Import in the bridging header to use from Swift:
       #import "Atari800Engine.h"
     The NS_SWIFT_NAME annotations provide clean Swift names automatically.
*/

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/* Notification posted on the main thread when a new frame is ready. */
extern NSNotificationName const Atari800EngineFrameReadyNotification;

/* Notification posted on the main thread when a disk LED state changes. */
extern NSNotificationName const Atari800EngineDiskLEDChangedNotification;

/* Notification userInfo keys for Atari800EngineDiskLEDChangedNotification */
extern NSString * const Atari800EngineLEDStatusKey;   // NSNumber (int)
extern NSString * const Atari800EngineLEDSectorKey;   // NSNumber (int)

/* -------------------------------------------------------------------------
   Error domain
   ------------------------------------------------------------------------- */
extern NSErrorDomain const Atari800EngineErrorDomain;

typedef NS_ERROR_ENUM(Atari800EngineErrorDomain, Atari800EngineError) {
    Atari800EngineErrorInitializationFailed = 1,
    Atari800EngineErrorMediaNotFound        = 2,
    Atari800EngineErrorMediaBadFormat       = 3,
    Atari800EngineErrorSaveStateFailed      = 4,
    Atari800EngineErrorLoadStateFailed      = 5,
    Atari800EngineErrorInvalidDriveNumber   = 6,
};

/* -------------------------------------------------------------------------
   Machine model
   ------------------------------------------------------------------------- */
typedef NS_ENUM(NSInteger, Atari800MachineModel) {
    Atari800MachineModel800   = 0,
    Atari800MachineModelXLXE  = 1,
    Atari800MachineModel5200  = 2,
} NS_SWIFT_NAME(MachineModel);

/* -------------------------------------------------------------------------
   Atari800Engine
   ------------------------------------------------------------------------- */

NS_SWIFT_NAME(EmulatorEngine)
@interface Atari800Engine : NSObject

/* Singleton accessor. */
+ (instancetype)sharedEngine NS_SWIFT_NAME(shared());

/* Designated initializer is unavailable — use +sharedEngine. */
- (instancetype)init NS_UNAVAILABLE;

/* -------------------------------------------------------------------------
   Lifecycle
   ------------------------------------------------------------------------- */

/* Start the emulator. Must be called once before any emulation methods.
   Returns YES on success; populates error on failure. */
- (BOOL)startWithError:(NSError **)error NS_SWIFT_NAME(start());

/* Stop the emulator and release all emulation resources.
   Safe to call even if -start was never called or failed. */
- (void)stop;

/* Returns YES if the emulator has been successfully started. */
@property (readonly) BOOL isRunning;

/* -------------------------------------------------------------------------
   Machine control
   ------------------------------------------------------------------------- */

/* Trigger a warm reset (Atari Reset button equivalent). */
- (void)warmReset;

/* Trigger a cold reset (power-cycle equivalent). */
- (void)coldReset;

/* The current machine model. Setting this queues a cold reset. */
@property (nonatomic) Atari800MachineModel machineModel;

/* -------------------------------------------------------------------------
   Disk drives (D1:–D8:)
   ------------------------------------------------------------------------- */

/* Mount a disk image. drive must be 1–8. Returns NO and sets error on failure. */
- (BOOL)mountDiskAtURL:(NSURL *)url
                 drive:(NSInteger)drive
                 error:(NSError *_Nullable *_Nullable)error
    NS_SWIFT_NAME(mountDisk(at:drive:));

/* Unmount the disk in a given drive slot. drive must be 1–8. */
- (void)unmountDrive:(NSInteger)drive;

/* Returns YES if the given drive slot has a disk mounted. drive must be 1–8. */
- (BOOL)isDriveMounted:(NSInteger)drive;

/* Returns the URL of the image in a given drive slot, or nil if empty. */
- (nullable NSURL *)mountedDiskURLForDrive:(NSInteger)drive;

/* -------------------------------------------------------------------------
   Cartridge
   ------------------------------------------------------------------------- */

/* Insert a cartridge image. Returns NO and sets error on failure. */
- (BOOL)insertCartridgeAtURL:(NSURL *)url
                       error:(NSError *_Nullable *_Nullable)error
    NS_SWIFT_NAME(insertCartridge(at:));

/* Insert a pass-through (second) cartridge. Returns NO and sets error on failure. */
- (BOOL)insertCartridge2AtURL:(NSURL *)url
                        error:(NSError *_Nullable *_Nullable)error
    NS_SWIFT_NAME(insertCartridge2(at:));

/* Remove the currently inserted cartridge. */
- (void)removeCartridge;

/* Remove the second cartridge. */
- (void)removeCartridge2;

/* -------------------------------------------------------------------------
   Cassette
   ------------------------------------------------------------------------- */

/* Mount a cassette image. Returns NO and sets error on failure. */
- (BOOL)mountCassetteAtURL:(NSURL *)url
                     error:(NSError *_Nullable *_Nullable)error
    NS_SWIFT_NAME(mountCassette(at:));

/* Unmount the cassette. */
- (void)unmountCassette;

/* -------------------------------------------------------------------------
   Executables
   ------------------------------------------------------------------------- */

/* Load and run an Atari executable. Returns NO and sets error on failure. */
- (BOOL)loadExecutableAtURL:(NSURL *)url
                      error:(NSError *_Nullable *_Nullable)error
    NS_SWIFT_NAME(loadExecutable(at:));

/* -------------------------------------------------------------------------
   Save states
   ------------------------------------------------------------------------- */

/* Save the current machine state to a file. Returns NO and sets error on failure. */
- (BOOL)saveStateToURL:(NSURL *)url
                 error:(NSError *_Nullable *_Nullable)error
    NS_SWIFT_NAME(saveState(to:));

/* Load a previously saved machine state. Returns NO and sets error on failure. */
- (BOOL)loadStateFromURL:(NSURL *)url
                   error:(NSError *_Nullable *_Nullable)error
    NS_SWIFT_NAME(loadState(from:));

/* -------------------------------------------------------------------------
   Frame buffer — for the Metal renderer
   ------------------------------------------------------------------------- */

/* Fill *outPixels with a pointer to the most-recently-completed ARGB8888 frame.
   *outWidth and *outHeight are set to the frame dimensions.
   The pointer is valid until the next frame completes.
   Call from the render/display thread immediately after observing
   Atari800EngineFrameReadyNotification. */
- (void)getFrameBuffer:(const uint8_t *_Nullable *_Nonnull)outPixels
                 width:(NSInteger *)outWidth
                height:(NSInteger *)outHeight;

/* -------------------------------------------------------------------------
   Input
   ------------------------------------------------------------------------- */

/* Post a key-down event. akey is an AKEY_* value from akey.h. */
- (void)sendKeyDown:(NSInteger)akey;

/* Release the currently held key. */
- (void)sendKeyUp;

/* Update joystick state for a given port (0–3). */
- (void)updateJoystickPort:(NSInteger)port
                 direction:(NSInteger)direction
                      fire:(BOOL)fire;

/* -------------------------------------------------------------------------
   Speed and audio
   ------------------------------------------------------------------------- */

/* Emulation speed multiplier (1.0 = normal). */
@property (nonatomic) double emulationSpeed;

/* Whether the speed limiter is active. When YES, emulation runs at ~60 fps. */
@property (nonatomic) BOOL speedLimitEnabled;

/* Master audio enable. */
@property (nonatomic) BOOL audioEnabled;

/* Audio volume [0.0, 1.0]. */
@property (nonatomic) double audioVolume;

/* POKEY stereo mode. */
@property (nonatomic) BOOL stereoEnabled;

/* -------------------------------------------------------------------------
   Display settings
   ------------------------------------------------------------------------- */

/* TV system: 0 = NTSC, 1 = PAL. */
@property (nonatomic) NSInteger tvMode;

/* NTSC artifacting mode (0 = none). */
@property (nonatomic) NSInteger artifactingMode;

/* -------------------------------------------------------------------------
   Disk LED status (for the status bar / HUD)
   Automatically posted via Atari800EngineDiskLEDChangedNotification.
   ------------------------------------------------------------------------- */

/* Current LED status: 0 = off, 1–9 = reading drive N, 10–18 = writing drive N. */
@property (readonly) NSInteger diskLEDStatus;

/* Current sector number being accessed (>0 when active). */
@property (readonly) NSInteger diskLEDSector;

@end

NS_ASSUME_NONNULL_END
