#import <objc/runtime.h>
#import "LegacyFullScreen.h"
#import "ZKSwizzle/ZKSwizzle.h"

// from https://gist.github.com/HIRANO-Satoshi/2823399 :
#if __clang__
    #if __has_feature(objc_arc)
        #define S_RETAIN self
        #define S_AUTORELEASE self
        #define S_RELEASE self
        #define S_DEALLOC self
    #else
        #define S_RETAIN retain
        #define S_AUTORELEASE autorelease
        #define S_RELEASE release
        #define S_DEALLOC dealloc
    #endif
#else
    #define S_RETAIN retain
    #define S_AUTORELEASE autorelease
    #define S_RELEASE release
    #define S_DEALLOC dealloc
#endif

@interface altNSWindow_stateVars : NSObject
{
    @public NSApplicationPresentationOptions m_normalPresOpts;
    @public NSRect m_normalRect;
    @public NSUInteger m_normalMask;
    @public Boolean m_fullScreenActivated, m_toolBarVisible;
    @public NSToolbar *m_toolBar;
    @public NSString *m_Title;
    @public NSURL *m_reprURL;
    @public NSImage *m_windowIcon;
    id m_self;
}
- (void) dealloc;
- (void) finalize;
@end

@implementation altNSWindow_stateVars
- (void)dealloc
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [super S_DEALLOC];
}

- (void)finalize
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [super finalize];
}
@end

static NSString *getApplicationName()
{
    NSString *appName;
    
    /* Determine the application name */
    appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    if (!appName) {
        appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    }
    
    if (![appName length]) {
        appName = [[NSProcessInfo processInfo] processName];
    }
    
    return appName;
}

@implementation altNSWindow
- (void)toggleFullScreen:(id)sender
{
    altNSWindow_stateVars *ego;
    NSUInteger smask = [self styleMask];
    Boolean wasActive = ([NSApp keyWindow] == self);
#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_9
    Boolean menuBarsOnAllScreens = [NSScreen screensHaveSeparateSpaces];
#else
    // let's be exhaustive and assume we can be built on 10.8 or earlier
    Boolean menuBarsOnAllScreens = NO;
#endif

//     NSString *winKey = [NSString stringWithFormat:@"%p", self];
//     if (!(ego = [aNSW_Instances valueForKey:winKey]))
    if (!(ego = objc_getAssociatedObject(self, (__bridge const void *)(self))))
    {
        // ego = calloc(1, sizeof(altNSWindow_stateVars));
        ego = [[altNSWindow_stateVars alloc] init];
        if (ego) {
            if (smask & NSFullScreenWindowMask) {
                // end fullscreen if the window happens to be in that state (never tested yet!)
                [self setStyleMask:(smask & ~NSFullScreenWindowMask)];
            }
            ego->m_toolBar = [self toolbar];
            ego->m_toolBarVisible = (ego->m_toolBar && [ego->m_toolBar isVisible]);
            ego->m_self = self;
//             [aNSW_Instances setValue:ego forKey:winKey];
            objc_setAssociatedObject(self, (__bridge const void *)(self), ego, OBJC_ASSOCIATION_RETAIN);
        } else {
            NSLog(@"Warning: failed to allocate state variables; calling the original toggleFullScreen method!");
            _orig(void);
            return;
        }
    }

    if (ego->m_fullScreenActivated) {
        [self setStyleMask:ego->m_normalMask];
        [self setFrame:ego->m_normalRect display:YES animate:NO];
        [NSApp setPresentationOptions:ego->m_normalPresOpts];
        if (ego->m_toolBar) {
            // restore the saved toolbar to the window
            [self setToolbar:ego->m_toolBar];
            [ego->m_toolBar S_RELEASE];
            if (ego->m_toolBarVisible) {
                // we hid it before removing it and going FS; toggle it back to visible
                // this can raise exceptions that do not appear to cause any dysfunction
                // but it is the reason why com.apple.Preview is blacklisted.
                [self toggleToolbarShown:sender];
            }
//             NSLog(@"%@ should have restored toolbar (%@)", self, ego->m_toolBar);
        }
        [self setTitle:ego->m_Title];
        if (ego->m_reprURL) {
            [self setRepresentedURL:ego->m_reprURL];
            [ego->m_reprURL S_RELEASE];
//            NSLog(@"Restored reprURL:%@", [self representedURL]);
        }
        // we may now have an iconButton:
        NSButton *iconButton = [self standardWindowButton:NSWindowDocumentIconButton];
        if (ego->m_windowIcon) {
            [iconButton setImage:ego->m_windowIcon];
            [ego->m_windowIcon S_RELEASE];
//            NSLog(@"Restored iconButton:%@ with icon: %@->%@", iconButton, ego->m_windowIcon, [iconButton image]);
        }
        ego->m_fullScreenActivated = NO;
        NSLog(@"Return from emulated legacy fullscreen");
    } else {
        NSToolbar *toolBar = [self toolbar];
        NSButton *iconButton = [self standardWindowButton:NSWindowDocumentIconButton];
        NSURL *reprURL = [self representedURL];

        ego->m_normalMask = smask;
        ego->m_normalRect = [self frame];
        ego->m_windowIcon = [[iconButton image] S_RETAIN];
        ego->m_normalPresOpts = [NSApp presentationOptions];
//        NSLog(@"iconButton:%@ with icon: %@", iconButton, ego->m_windowIcon);
        ego->m_Title = [self title];
        if (reprURL != nil) {
            ego->m_reprURL = [reprURL S_RETAIN];
//            NSLog(@"reprURL:%@", ego->m_reprURL);
        }
        if (toolBar) {
            ego->m_toolBarVisible = [toolBar isVisible];
            ego->m_toolBar = [toolBar S_RETAIN];
            if (ego->m_toolBarVisible) {
                // hide the toolbar
                [self toggleToolbarShown:sender];
            }
            // remove it
            [self setToolbar:nil];
//             NSLog(@"%@ has a toolbar (%@); removed it for FullScreen mode", self, toolBar);
        }
        // setting the style after `setPresentationOptions` can lead to instability?!
        [self setStyleMask:NSFullScreenWindowMask];
        // always set the Dock to hide. We do that because there's no known (to me) way to
        // determine whether the Dock is on our screen (we can just infer if Dock AND Menubar are on our screen
        // by comparing [NSScreen frame] and [NSScreen visibleFrame]). As a result, the Dock may be
        // deactivated when we are active fullscreen on another screen. That's a lesser issue than when it
        // remains visible in front of us, or than the tiny strip that remains there to "catch" it.
        NSApplicationPresentationOptions newPresOpts = ego->m_normalPresOpts | NSApplicationPresentationHideDock;
        if (menuBarsOnAllScreens || [self screen] == [[NSScreen screens] firstObject]) {
            newPresOpts |= NSApplicationPresentationAutoHideMenuBar;
        }
        [NSApp setPresentationOptions:newPresOpts];
        // go fullscreen
        [self setFrame:[[self screen] visibleFrame] display:YES animate:NO];
        ego->m_fullScreenActivated = YES;
        NSLog(@"Activated emulated legacy fullscreen");
    }
    if (wasActive) {
        [self makeKeyWindow];
    }
}

#ifdef OVERRIDE_SETCOLLECTIONBEHAVIOR
- (void)setCollectionBehavior:(NSWindowCollectionBehavior)behaviour
{
    if (behaviour & NSWindowCollectionBehaviorFullScreenPrimary) {
        behaviour &= ~NSWindowCollectionBehaviorFullScreenPrimary;
    }
    // we can call [self altSetCollectionBehaviour:behaviour] here without risk
    // for infinite recursion because will in fact call the original [NSWindow setCollectionBehavior]
    // thanks to the call to method_exchangeImplementations()
    NSLog(@"calling the actual [NSWindow setCollectionBehavior] method!");
    _orig(void, behaviour);
}
#endif

- (void)finalize
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    _super(void);
}
@end

@implementation LegacyFullScreen
+(void) load
{
    NSArray *blackList;
    NSBundle *thisPluginBundle = [NSBundle bundleForClass:[self class]];
    if (thisPluginBundle) {
        NSDictionary *infoPList = [thisPluginBundle infoDictionary];
        // reuse the info key also used at the level of the SIMBL agent (for all plugins)
        // (evidently this doesn't interfere with that "global" key!)
        blackList = [infoPList objectForKey:@"SIMBLApplicationIdentifierBlacklist"];
    }
    if (!blackList || ![[blackList className] isEqualToString:@"__NSArrayM"]) {
        blackList = [NSArray arrayWithObjects:@"com.apple.Preview",nil];
        NSLog(@"Warning: using hardcoded default appID blacklist (%@)!", blackList);
    }
    NSString *appID = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
    if (![blackList containsObject:appID]) {
        ZKSwizzle(altNSWindow, NSWindow);

        // see if we need to provide a "Enter Full Screen" menu item so the user can exit FS mode again:
        NSMenu *targetMenu = [[[NSApp mainMenu] itemWithTitle:@"View"] submenu];
        if (!targetMenu) {
            targetMenu = [NSApp windowsMenu];
            if (![targetMenu itemWithTitle:@"Enter Full Screen"]) {
                // add "Enter FullScreen Ctrl-Cmd-F" after the Zoom (or the Minimize) item
                NSMenuItem *here = [targetMenu itemWithTitle:@"Zoom"];
                if (!here) {
                    here = [targetMenu itemWithTitle:@"Minimize"];
                }
                if (here) {
                    [[targetMenu insertItemWithTitle:@"Enter Full Screen" action:@selector(toggleFullScreen:) keyEquivalent:@"f"
                                             atIndex:[targetMenu indexOfItem:here]+1]
                     setKeyEquivalentModifierMask:NSCommandKeyMask|NSControlKeyMask];
                } else {
                    [[targetMenu addItemWithTitle:@"Enter Full Screen" action:@selector(toggleFullScreen:) keyEquivalent:@"f"]
                     setKeyEquivalentModifierMask:NSCommandKeyMask|NSControlKeyMask];
                }
            }

        } else {
            // add "Enter FullScreen Ctrl-Cmd-F" if it doesn't already exist
            NSMenuItem *eFS = [targetMenu itemWithTitle:@"Enter Full Screen"];
            if (!eFS) {
                [[targetMenu addItemWithTitle:@"Enter Full Screen" action:@selector(toggleFullScreen:) keyEquivalent:@"f"]
                 setKeyEquivalentModifierMask:NSCommandKeyMask|NSControlKeyMask];
            }
        }

        NSLog(@"Native FullScreen replaced with legacy emulation for application ID \"%@\"", appID);
    } else {
        NSLog(@"Legacy FullScreen emulation NOT used for blacklisted application \"%@\" (%@)", getApplicationName(), appID);
    }
}
@end
