#import <Cocoa/Cocoa.h>

@interface  altNSWindow : NSWindow
- (void)setStyleMask:(NSUInteger)styleMask;
- (void)toggleFullScreen:(id)sender;
@end

@interface LegacyFullScreen : NSObject
{
}
+(void) load;
@end