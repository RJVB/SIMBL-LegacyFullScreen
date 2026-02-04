#import <Cocoa/Cocoa.h>

@interface  altNSWindow : NSWindow
- (void)toggleFullScreen:(id)sender;
#ifdef OVERRIDE_SETCOLLECTIONBEHAVIOR
- (void)setCollectionBehavior:(NSWindowCollectionBehavior)behaviour;
#endif
@end

@interface LegacyFullScreen : NSObject
{
}
+(void) load;
@end