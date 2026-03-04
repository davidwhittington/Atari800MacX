/* capslock_vision.c — visionOS stub for capslock.c
 *
 * The macOS capslock.c uses IOKit to control the physical Caps Lock LED.
 * IOKit is not available on visionOS. This stub provides the same
 * symbol (MacCapsLockSet) as a no-op.
 */

void MacCapsLockSet(int on)
{
    (void)on;
    /* No physical Caps Lock LED on visionOS */
}
