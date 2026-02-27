/* BreakpointCondition.m - 
 BreakpointCondition class for the
 Macintosh OS X SDL port of Atari800
 Mark Grebe <atarimacosx@gmail.com>
 */

#import "BreakpointCondition.h"


@implementation BreakpointCondition

+(BreakpointCondition *) conditionWithIndex:(int) index
{
	BreakpointCondition *theBreakpoint;
	
	theBreakpoint = [[self alloc] initWithConditionIndex:index];
	return(theBreakpoint);
}

-(BreakpointCondition *) initWithConditionIndex:(int) index
{
	self = [super init];
	if (!self) return nil;
	memcpy(&cond, &MONITOR_breakpoint_table[index], sizeof(MONITOR_breakpoint_cond));
	return(self);
}

-(BreakpointCondition *) initWithBreakpointCondition:(MONITOR_breakpoint_cond *) condition
{
	self = [super init];
	if (!self) return nil;
	memcpy(&cond, condition, sizeof(MONITOR_breakpoint_cond));
	return(self);
}

- (MONITOR_breakpoint_cond *) getCondition
{
	return(&cond);
}

-(id) copyWithZone:(NSZone *)zone
{
	BreakpointCondition *copyCond = [[BreakpointCondition alloc] initWithBreakpointCondition:[self getCondition]];
	return copyCond;
}

@end
