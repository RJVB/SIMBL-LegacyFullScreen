#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wexplicit-ownership-type"
#import <Cocoa/Cocoa.h>
#pragma GCC diagnostic pop

@interface  altNSWindow : NSWindow
//- (void)setStyleMask:(NSUInteger)styleMask;
- (void)toggleFullScreen:(id)sender;
@end

@interface LegacyFullScreen : NSObject
{
}
+(void) load;
@end