/* KeyMapper.h - KeyMapper 
 header  For the Macintosh OS X SDL port of Atari800
 Mark Grebe <atarimacosx@gmail.com>
 
 */

#import <Cocoa/Cocoa.h>

// CoreServices provides UCKeyTranslate, UCKeyboardLayout, kUCKeyActionDown,
// LMGetKbdType, noErr and related Unicode key utility types (via CarbonCore).
#include <CoreServices/CoreServices.h>

// Text Input Sources API (TISCopyCurrentKeyboardLayoutInputSource etc.) lives in
// HIToolbox.framework, which is a sub-framework of Carbon.framework.  Carbon is
// weakly linked (see WEAK_FRAMEWORKS in Atari800MacX.xcconfig) so the app still
// launches on macOS 15+ where Carbon.framework is absent; KeyMapper handles the
// NULL case by leaving keymap entries at SDLK_UNKNOWN.
#include <Carbon/Carbon.h>

@interface KeyMapper : NSObject {
	unsigned int keymap[128];
}

+ (KeyMapper *)sharedInstance;
- (void) releaseCmdKeys:(NSString *)character;
-(unsigned int)getQuartzKey:(unsigned int) character;

@end
