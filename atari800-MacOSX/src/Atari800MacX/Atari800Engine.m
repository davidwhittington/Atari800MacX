/* Atari800Engine.m - Objective-C façade over the C emulation core.
   Part of Atari800MacX — Phase 2 modernization (emulation core isolation).

   IMPLEMENTATION NOTES:
   - The emulation loop runs on _emulationThread (NSThread), calling
     Atari800Core_RunFrame() at approximately 60 Hz.
   - Frame buffer double-buffering uses a simple lock to swap pointers
     after each completed frame, allowing the renderer to read without
     tearing.
   - All public API methods dispatch to the main thread where needed
     and are documented with their threading requirements.

   TODO (Phase 5 — Metal renderer):
   - Replace the uint8_t* pixel buffer exchange with a CVPixelBuffer or
     MTLBuffer approach for zero-copy GPU upload.
*/

#import "Atari800Engine.h"
#import "Atari800Core.h"

#include "mac_diskled.h"   /* led_status, led_sector */

/* -------------------------------------------------------------------------
   Notification names and userInfo keys
   ------------------------------------------------------------------------- */
NSNotificationName const Atari800EngineFrameReadyNotification   = @"Atari800EngineFrameReady";
NSNotificationName const Atari800EngineDiskLEDChangedNotification = @"Atari800EngineDiskLEDChanged";
NSString * const Atari800EngineLEDStatusKey = @"LEDStatus";
NSString * const Atari800EngineLEDSectorKey = @"LEDSector";

/* -------------------------------------------------------------------------
   Error domain
   ------------------------------------------------------------------------- */
NSErrorDomain const Atari800EngineErrorDomain = @"com.atarimac.atari800macx.engine";

/* -------------------------------------------------------------------------
   Private interface
   ------------------------------------------------------------------------- */
@interface Atari800Engine ()

@property (nonatomic, strong) NSThread *emulationThread;
@property (nonatomic, assign) BOOL shouldRunEmulation;

/* Double-buffered pixel data. _frontBuffer is read by the renderer;
   _backBuffer is written by the emulator. Swapped under _bufferLock. */
@property (nonatomic, assign) uint8_t *frontBuffer;
@property (nonatomic, assign) uint8_t *backBuffer;
@property (nonatomic, assign) NSInteger frameWidth;
@property (nonatomic, assign) NSInteger frameHeight;

/* Disk LED polling */
@property (nonatomic, assign) NSInteger lastLEDStatus;
@property (nonatomic, assign) NSInteger lastLEDSector;

@end

/* -------------------------------------------------------------------------
   Implementation
   ------------------------------------------------------------------------- */
@implementation Atari800Engine {
    os_unfair_lock _bufferLock;
}

#pragma mark - Singleton

+ (instancetype)sharedEngine {
    static Atari800Engine *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] _initInternal];
    });
    return instance;
}

- (instancetype)_initInternal {
    self = [super init];
    if (self) {
        _bufferLock       = OS_UNFAIR_LOCK_INIT;
        _isRunning        = NO;
        _shouldRunEmulation = NO;
        _frameWidth       = 336;
        _frameHeight      = 240;
        _emulationSpeed   = 1.0;
        _speedLimitEnabled = YES;
        _audioEnabled     = YES;
        _audioVolume      = 1.0;
        _stereoEnabled    = NO;
        _tvMode           = 0; /* NTSC */
        _artifactingMode  = 0;
        _diskLEDStatus    = 0;
        _diskLEDSector    = 0;
        _lastLEDStatus    = -1;
        _lastLEDSector    = -1;
    }
    return self;
}

#pragma mark - Lifecycle

- (BOOL)startWithError:(NSError **)error {
    if (_isRunning) {
        return YES;
    }

    if (!Atari800Core_Initialize()) {
        if (error) {
            *error = [NSError errorWithDomain:Atari800EngineErrorDomain
                                         code:Atari800EngineErrorInitializationFailed
                                     userInfo:@{
                NSLocalizedDescriptionKey: @"Failed to initialize Atari 800 emulation core.",
                NSLocalizedRecoverySuggestionErrorKey: @"Check that the required ROM files are configured in Preferences."
            }];
        }
        return NO;
    }

    /* Allocate double frame buffers (ARGB8888 = 4 bytes per pixel). */
    NSInteger bufferSize = _frameWidth * _frameHeight * 4;
    _frontBuffer = (uint8_t *)calloc(bufferSize, 1);
    _backBuffer  = (uint8_t *)calloc(bufferSize, 1);
    if (!_frontBuffer || !_backBuffer) {
        free(_frontBuffer); _frontBuffer = NULL;
        free(_backBuffer);  _backBuffer  = NULL;
        if (error) {
            *error = [NSError errorWithDomain:Atari800EngineErrorDomain
                                         code:Atari800EngineErrorInitializationFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"Out of memory allocating frame buffers."}];
        }
        return NO;
    }

    _isRunning        = YES;
    _shouldRunEmulation = YES;

    _emulationThread = [[NSThread alloc] initWithTarget:self
                                               selector:@selector(_runEmulationLoop)
                                                 object:nil];
    _emulationThread.name = @"Atari800EmulationThread";
    _emulationThread.qualityOfService = NSQualityOfServiceUserInteractive;
    [_emulationThread start];

    return YES;
}

- (void)stop {
    _shouldRunEmulation = NO;

    /* Give the emulation thread a moment to exit cleanly. */
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:0.5];
    while (_isRunning && [NSDate date].timeIntervalSince1970 < deadline.timeIntervalSince1970) {
        [NSThread sleepForTimeInterval:0.01];
    }

    Atari800Core_Shutdown();

    free(_frontBuffer); _frontBuffer = NULL;
    free(_backBuffer);  _backBuffer  = NULL;
    _isRunning = NO;
}

#pragma mark - Emulation loop (runs on _emulationThread)

- (void)_runEmulationLoop {
    @autoreleasepool {
        while (_shouldRunEmulation) {
            @autoreleasepool {
                Atari800Core_RunFrame();
                [self _swapFrameBuffers];
                [self _checkDiskLED];

                dispatch_async(dispatch_get_main_queue(), ^{
                    [NSNotificationCenter.defaultCenter
                        postNotificationName:Atari800EngineFrameReadyNotification
                                      object:self];
                });
            }
        }
        _isRunning = NO;
    }
}

/* Copy the emulator's pixel output into the back buffer, then swap front/back. */
- (void)_swapFrameBuffers {
    int coreWidth = 0, coreHeight = 0;
    const uint8_t *pixels = Atari800Core_GetFrameBuffer(&coreWidth, &coreHeight);
    if (!pixels) return;

    NSInteger needed = (NSInteger)coreWidth * coreHeight * 4;
    memcpy(_backBuffer, pixels, needed);

    os_unfair_lock_lock(&_bufferLock);
    uint8_t *tmp = _frontBuffer;
    _frontBuffer = _backBuffer;
    _backBuffer  = tmp;
    _frameWidth  = coreWidth;
    _frameHeight = coreHeight;
    os_unfair_lock_unlock(&_bufferLock);
}

/* Poll the disk LED globals from mac_diskled.h and post a notification if changed. */
- (void)_checkDiskLED {
    NSInteger currentStatus = (NSInteger)Atari800Core_GetDiskLEDStatus();
    NSInteger currentSector = (NSInteger)Atari800Core_GetDiskLEDSector();

    if (currentStatus != _lastLEDStatus || currentSector != _lastLEDSector) {
        _lastLEDStatus = currentStatus;
        _lastLEDSector = currentSector;

        NSDictionary *info = @{
            Atari800EngineLEDStatusKey: @(currentStatus),
            Atari800EngineLEDSectorKey: @(currentSector),
        };
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_diskLEDStatus = currentStatus;
            self->_diskLEDSector = currentSector;
            [NSNotificationCenter.defaultCenter
                postNotificationName:Atari800EngineDiskLEDChangedNotification
                              object:self
                            userInfo:info];
        });
    }
}

#pragma mark - Machine control

- (void)warmReset {
    Atari800Core_WarmReset();
}

- (void)coldReset {
    Atari800Core_ColdReset();
}

- (void)setMachineModel:(Atari800MachineModel)machineModel {
    _machineModel = machineModel;
    Atari800Core_SetMachineModel((Atari800Core_MachineModel)machineModel);
    [self coldReset];
}

#pragma mark - Disk drives

- (BOOL)mountDiskAtURL:(NSURL *)url drive:(NSInteger)drive error:(NSError **)error {
    if (drive < 1 || drive > 8) {
        if (error) {
            *error = [NSError errorWithDomain:Atari800EngineErrorDomain
                                         code:Atari800EngineErrorInvalidDriveNumber
                                     userInfo:@{NSLocalizedDescriptionKey: @"Drive number must be between 1 and 8."}];
        }
        return NO;
    }

    if (!url.fileURL) {
        if (error) {
            *error = [NSError errorWithDomain:Atari800EngineErrorDomain
                                         code:Atari800EngineErrorMediaNotFound
                                     userInfo:@{NSLocalizedDescriptionKey: @"URL is not a file URL."}];
        }
        return NO;
    }

    const char *path = url.fileSystemRepresentation;
    if (!Atari800Core_MountDisk((int)drive, path)) {
        if (error) {
            *error = [NSError errorWithDomain:Atari800EngineErrorDomain
                                         code:Atari800EngineErrorMediaBadFormat
                                     userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Could not mount disk image in drive D%ld:", (long)drive],
                NSURLErrorKey: url,
            }];
        }
        return NO;
    }
    return YES;
}

- (void)unmountDrive:(NSInteger)drive {
    if (drive >= 1 && drive <= 8) {
        Atari800Core_UnmountDisk((int)drive);
    }
}

- (BOOL)isDriveMounted:(NSInteger)drive {
    if (drive < 1 || drive > 8) return NO;
    return Atari800Core_IsDiskMounted((int)drive) != 0;
}

- (nullable NSURL *)mountedDiskURLForDrive:(NSInteger)drive {
    if (drive < 1 || drive > 8) return nil;
    const char *path = Atari800Core_GetDiskPath((int)drive);
    if (!path || strlen(path) == 0) return nil;
    return [NSURL fileURLWithFileSystemRepresentation:path isDirectory:NO relativeToURL:nil];
}

#pragma mark - Cartridge

- (BOOL)insertCartridgeAtURL:(NSURL *)url error:(NSError **)error {
    if (!Atari800Core_InsertCartridge(url.fileSystemRepresentation)) {
        if (error) {
            *error = [NSError errorWithDomain:Atari800EngineErrorDomain
                                         code:Atari800EngineErrorMediaBadFormat
                                     userInfo:@{NSLocalizedDescriptionKey: @"Could not insert cartridge.", NSURLErrorKey: url}];
        }
        return NO;
    }
    return YES;
}

- (BOOL)insertCartridge2AtURL:(NSURL *)url error:(NSError **)error {
    if (!Atari800Core_InsertCartridge2(url.fileSystemRepresentation)) {
        if (error) {
            *error = [NSError errorWithDomain:Atari800EngineErrorDomain
                                         code:Atari800EngineErrorMediaBadFormat
                                     userInfo:@{NSLocalizedDescriptionKey: @"Could not insert second cartridge.", NSURLErrorKey: url}];
        }
        return NO;
    }
    return YES;
}

- (void)removeCartridge  { Atari800Core_RemoveCartridge();  }
- (void)removeCartridge2 { Atari800Core_RemoveCartridge2(); }

#pragma mark - Cassette

- (BOOL)mountCassetteAtURL:(NSURL *)url error:(NSError **)error {
    if (!Atari800Core_MountCassette(url.fileSystemRepresentation)) {
        if (error) {
            *error = [NSError errorWithDomain:Atari800EngineErrorDomain
                                         code:Atari800EngineErrorMediaBadFormat
                                     userInfo:@{NSLocalizedDescriptionKey: @"Could not mount cassette image.", NSURLErrorKey: url}];
        }
        return NO;
    }
    return YES;
}

- (void)unmountCassette { Atari800Core_UnmountCassette(); }

#pragma mark - Executables

- (BOOL)loadExecutableAtURL:(NSURL *)url error:(NSError **)error {
    if (!Atari800Core_LoadExecutable(url.fileSystemRepresentation)) {
        if (error) {
            *error = [NSError errorWithDomain:Atari800EngineErrorDomain
                                         code:Atari800EngineErrorMediaBadFormat
                                     userInfo:@{NSLocalizedDescriptionKey: @"Could not load executable.", NSURLErrorKey: url}];
        }
        return NO;
    }
    return YES;
}

#pragma mark - Save states

- (BOOL)saveStateToURL:(NSURL *)url error:(NSError **)error {
    if (!Atari800Core_SaveState(url.fileSystemRepresentation)) {
        if (error) {
            *error = [NSError errorWithDomain:Atari800EngineErrorDomain
                                         code:Atari800EngineErrorSaveStateFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to save emulator state.", NSURLErrorKey: url}];
        }
        return NO;
    }
    return YES;
}

- (BOOL)loadStateFromURL:(NSURL *)url error:(NSError **)error {
    if (!Atari800Core_LoadState(url.fileSystemRepresentation)) {
        if (error) {
            *error = [NSError errorWithDomain:Atari800EngineErrorDomain
                                         code:Atari800EngineErrorLoadStateFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to load emulator state.", NSURLErrorKey: url}];
        }
        return NO;
    }
    return YES;
}

#pragma mark - Frame buffer

- (void)getFrameBuffer:(const uint8_t **)outPixels
                 width:(NSInteger *)outWidth
                height:(NSInteger *)outHeight {
    os_unfair_lock_lock(&_bufferLock);
    *outPixels = _frontBuffer;
    *outWidth  = _frameWidth;
    *outHeight = _frameHeight;
    os_unfair_lock_unlock(&_bufferLock);
}

#pragma mark - Input

- (void)sendKeyDown:(NSInteger)akey {
    Atari800Core_KeyDown((int)akey);
}

- (void)sendKeyUp {
    Atari800Core_KeyUp();
}

- (void)updateJoystickPort:(NSInteger)port
                 direction:(NSInteger)direction
                      fire:(BOOL)fire {
    Atari800Core_JoystickUpdate((int)port,
                                (Atari800Core_JoyDirection)direction,
                                fire ? 1 : 0);
}

#pragma mark - Speed and audio

- (void)setEmulationSpeed:(double)emulationSpeed {
    _emulationSpeed = emulationSpeed;
    Atari800Core_SetSpeed(emulationSpeed);
}

- (void)setSpeedLimitEnabled:(BOOL)speedLimitEnabled {
    _speedLimitEnabled = speedLimitEnabled;
    Atari800Core_SetSpeedLimitEnabled(speedLimitEnabled ? 1 : 0);
}

- (void)setAudioEnabled:(BOOL)audioEnabled {
    _audioEnabled = audioEnabled;
    Atari800Core_SetAudioEnabled(audioEnabled ? 1 : 0);
}

- (void)setAudioVolume:(double)audioVolume {
    _audioVolume = audioVolume;
    Atari800Core_SetAudioVolume(audioVolume);
}

- (void)setStereoEnabled:(BOOL)stereoEnabled {
    _stereoEnabled = stereoEnabled;
    Atari800Core_SetStereoEnabled(stereoEnabled ? 1 : 0);
}

#pragma mark - Display

- (void)setTvMode:(NSInteger)tvMode {
    _tvMode = tvMode;
    Atari800Core_SetTVMode((int)tvMode);
}

- (void)setArtifactingMode:(NSInteger)artifactingMode {
    _artifactingMode = artifactingMode;
    Atari800Core_SetArtifactingMode((int)artifactingMode);
}

@end
