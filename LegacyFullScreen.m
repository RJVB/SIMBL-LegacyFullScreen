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

@interface altNSWindow_stateVars : NSObject
{
    @public NSApplicationPresentationOptions m_normalPresOpts;
    @public NSRect m_normalRect;
    @public NSUInteger m_normalMask;
    @public BOOL m_fullScreenActivated, m_toolBarVisible,
                 m_delegateSwizzled;
    @public NSToolbar *m_toolBar;
    @public NSString *m_Title;
    @public NSURL *m_reprURL;
    @public NSImage *m_windowIcon;
    @public id m_self;
    @public id<NSWindowDelegate> m_customDelegate;
}
@end

@implementation altNSWindow_stateVars
@end

@interface altNSApplicationDelegate : NSObject <NSApplicationDelegate>
{
    NSStatusItem *m_systrayItem;
    NSMenu *m_menu;
}
- (instancetype)init;
- (void)dealloc;
- (NSMenu *)systrayMenu;
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification;
- (void)applicationWillTerminate:(NSNotification *)aNotification;
- (void)menuItemChanged:(NSNotification *)aNotification;
@end

static altNSApplicationDelegate *fsDelegate = nil;

// From Firefox's nsChildView.h :
@interface NSView (Undocumented)

// Undocumented method of one or more of NSFrameView's subclasses.  Called
// when one or more of the titlebar buttons needs to be repositioned, to
// disappear, or to reappear (say if the window's style changes).  If
// 'redisplay' is true, the entire titlebar (the window's top 22 pixels) is
// marked as needing redisplay.  This method has been present in the same
// format since at least OS X 10.5.
- (void)_tileTitlebarAndRedisplay:(BOOL)redisplay;
@end

@interface altNSWindowDelegate : NSObject <NSWindowDelegate>
- (NSArray*)customWindowsToEnterFullScreenForWindow:(NSWindow *)window;
- (NSArray*)customWindowsToExitFullScreenForWindow:(NSWindow*)window;
- (void)window:(NSWindow *)window startCustomAnimationToEnterFullScreenWithDuration:(NSTimeInterval)duration;
- (void)window:(NSWindow *)window startCustomAnimationToExitFullScreenWithDuration:(NSTimeInterval)duration;
// (void)windowDidClose:(NSNotification*)aNotification;
@end

@implementation altNSWindowDelegate
// adapted from https://github.com/mpv-player/mpv/blob/235eb60671c899d55b1174043940763b250fa3b8/video/out/cocoa/window.m#L156C1-L171C1
- (NSArray *)customWindowsToEnterFullScreenForWindow:(NSWindow *)window
{
//    NSLog(@"%s %@, %@", __PRETTY_FUNCTION__, self, window);
    return [NSArray arrayWithObject:window];
}

- (NSArray*)customWindowsToExitFullScreenForWindow:(NSWindow*)window
{
//    NSLog(@"%s %@, %@", __PRETTY_FUNCTION__, self, window);
    return [NSArray arrayWithObject:window];
}

- (void)window:(NSWindow *)window startCustomAnimationToEnterFullScreenWithDuration:(NSTimeInterval)duration
{
//    NSLog(@"%s %@ %@ %g", __PRETTY_FUNCTION__, self, window, duration);
    altNSWindow_stateVars *store = objc_getAssociatedObject(window, (__bridge const void *)(window));
    if (store && !store->m_fullScreenActivated) {
        store->m_normalRect = [window frame];
        store->m_normalMask = [window styleMask];
        store->m_normalPresOpts = [NSApp presentationOptions];
        store->m_fullScreenActivated = YES;
//        NSLog(@"saved geo %gx%g+%g+%g",
//              store->m_normalRect.size.width, store->m_normalRect.size.height,
//              store->m_normalRect.origin.x, store->m_normalRect.origin.y);
    } else {
        NSLog(@"%s - no state store for window %@!", __PRETTY_FUNCTION__, window);
    }
    // this method is responsible for bringing the target window to fullscreen size.
    [window setFrame:[[window screen] visibleFrame] display:YES animate:NO];
    NSLog(@"Activated fast native fullscreen");
}

- (void)window:(NSWindow *)window startCustomAnimationToExitFullScreenWithDuration:(NSTimeInterval)duration
{
//    NSLog(@"%s %@ %@ %g", __PRETTY_FUNCTION__, self, window, duration);
    altNSWindow_stateVars *store = objc_getAssociatedObject(window, (__bridge const void *)(window));
    if (store && store->m_fullScreenActivated) {
        [window setStyleMask:store->m_normalMask];
        // this method is responsible for restoring the windows's original size.
        // we also restore a few other settings a bit earlier; that seems to speed up matters a bit.
        [window setFrame:store->m_normalRect display:YES animate:NO];
        [NSApp setPresentationOptions:store->m_normalPresOpts];
        store->m_fullScreenActivated = NO;
//        NSLog(@"restored geo %gx%g+%g+%g",
//              store->m_normalRect.size.width, store->m_normalRect.size.height,
//              store->m_normalRect.origin.x, store->m_normalRect.origin.y);
    } else {
        NSLog(@"%s - no state store for window %@!", __PRETTY_FUNCTION__, window);
    }
    NSLog(@"Exit from fast native fullscreen");
}

//- (void)windowDidClose:(NSNotification*)aNotification
//{
//    NSLog(@"%s %@ %@", __PRETTY_FUNCTION__, self, aNotification);
//}
@end

@implementation altNSWindow
- (void)sendFSNotification:(NSString*)notif ifTrue:(BOOL)enabled
{
    if (enabled) {
        [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:notif
                                                        object:self]];
    }
}

- (void)setStyleMask:(NSUInteger)styleMask
{
    // copied from https://github.com/mpv-player/mpv/blob/235eb60671c899d55b1174043940763b250fa3b8/video/out/cocoa/window.m#L74
    NSResponder *nR = [self firstResponder];
    ZKOrig(void,styleMask);
    [self makeFirstResponder:nR];
}

static BOOL add_NSWinDelegateSelector(NSObject *destInstance, SEL newSelector)
{   const Method newMethod = class_getInstanceMethod([altNSWindowDelegate class], newSelector);
    return class_addMethod([destInstance class], newSelector,
                method_getImplementation(newMethod), method_getTypeEncoding(newMethod));
}

static IMP replace_NSWinDelegateSelector(NSObject *destInstance, SEL newSelector)
{   const Method newMethod = class_getInstanceMethod([altNSWindowDelegate class], newSelector);
    return class_replaceMethod([destInstance class], newSelector,
                method_getImplementation(newMethod), method_getTypeEncoding(newMethod));
}

- (void)toggleFullScreen:(id)sender
{
    altNSWindow_stateVars *ego;
    NSUInteger smask = [self styleMask];
    BOOL wasActive = ([NSApp keyWindow] == self);
#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_9
    BOOL menuBarsOnAllScreens = [NSScreen screensHaveSeparateSpaces];
#else
    // let's be exhaustive and assume we can be built on 10.8 or earlier
    BOOL menuBarsOnAllScreens = NO;
#endif
    static BOOL sendNotification = YES;
    static BOOL isMozilla = NO;

//     NSString *winKey = [NSString stringWithFormat:@"%p", self];
//     if (!(ego = [aNSW_Instances valueForKey:winKey]))
    if (!(ego = objc_getAssociatedObject(self, (__bridge const void *)(self))))
    {
        // ego = calloc(1, sizeof(altNSWindow_stateVars));
        ego = [[altNSWindow_stateVars alloc] init];
        if (ego) {
            NSString *appID = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
            //  check if we're in an application known not to like fullscreen enter/exit notifications
//            NSArray *noNotificationFor = [NSArray arrayWithObjects:@"com.apple.dt.Xcode",nil];
//            if ([noNotificationFor containsObject:appID]) {
//                sendNotification = NO;
//            }

            if (smask & NSFullScreenWindowMask) {
                // end fullscreen if the window happens to be in that state (never tested yet!)
                [self sendFSNotification:NSWindowWillExitFullScreenNotification ifTrue:sendNotification];
                [self setStyleMask:(smask & ~NSFullScreenWindowMask)];
                [self sendFSNotification:NSWindowDidExitFullScreenNotification ifTrue:sendNotification];
            }
            ego->m_toolBar = [self toolbar];
            ego->m_toolBarVisible = (ego->m_toolBar && [ego->m_toolBar isVisible]);
            ego->m_self = self;
            ego->m_delegateSwizzled = NO;
            ego->m_customDelegate = nil;

            if ([appID isEqualToString:@"org.mozilla.firefox"]) {
                isMozilla = YES;
            }
//             [aNSW_Instances setValue:ego forKey:winKey];
            objc_setAssociatedObject(self, (__bridge const void *)(self), ego, OBJC_ASSOCIATION_RETAIN);
        } else {
            NSLog(@"Warning: failed to allocate state variables; calling the original toggleFullScreen method!");
            _orig(void);
            return;
        }
    }
    NSObject *wDelegate = [self delegate];
    // For applications where we don't replace the native FS mode:
    if (!wDelegate) {
        // add a delegate that defines an ultrashort noop FS animation
        if (!ego->m_customDelegate) {
            // let's hope that our cached copy remains valid even if it gets replaced!
            // (for now I have not yet encountered windows that did not yet have a delegate...)
            ego->m_customDelegate = [[altNSWindowDelegate alloc] init];
        }
        [self setDelegate:ego->m_customDelegate];
        NSLog(@"%@ now has delegate %@[%@]", self, wDelegate, [wDelegate className]);
    } else if (!ego->m_delegateSwizzled) {
        // here, we need to be discriminate, more than ZKSwizzle would allow to be.
        // The first two animation-related methods are added, an operation that will fail
        // if the target delegate already has an implementation. That should be OK.
        if (!add_NSWinDelegateSelector(wDelegate, @selector(customWindowsToEnterFullScreenForWindow:))) {
            NSLog(@"Failed to add delegate method customWindowsToEnterFullScreenForWindow:");
        }
        if (!add_NSWinDelegateSelector(wDelegate, @selector(customWindowsToExitFullScreenForWindow:))) {
            NSLog(@"Failed to add delegate method customWindowsToExitFullScreenForWindow:");
        }
        // Existing implementations of the actual animation methods need to be replaced if
        // we want to drop the entire animation. Or else added, hence the use of a different function
        if (replace_NSWinDelegateSelector(wDelegate, @selector(window:startCustomAnimationToEnterFullScreenWithDuration:))) {
            NSLog(@"Replacing an existing method window:startCustomAnimationToEnterFullScreenWithDuration:!");
        }
        if (replace_NSWinDelegateSelector(wDelegate, @selector(window:startCustomAnimationToExitFullScreenWithDuration:))) {
            NSLog(@"Replacing an existing method window:startCustomAnimationToExitFullScreenWithDuration!");
        }
        ego->m_delegateSwizzled = YES;
    }
//    // test the custom/swizzled delegate:
//    ZKOrig(void);
//    return;

    if (ego->m_fullScreenActivated) {
        [self sendFSNotification:NSWindowWillExitFullScreenNotification ifTrue:sendNotification];
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
        if (isMozilla) {
            // None of the below have the intended effect :-/
//            // ensure that the window buttons are visible on FS exit!
//            [[self standardWindowButton:NSWindowCloseButton] setHidden:NO];
//            [[self standardWindowButton:NSWindowMiniaturizeButton] setHidden:NO];
//            [[self standardWindowButton:NSWindowZoomButton] setHidden:NO];
//            NSView *frameView = [[self contentView] superview];
//            //NSLog(@"win of class %@, frameView=%@", NSStringFromClass([self class]), frameView);
//            if ([frameView respondsToSelector:@selector(_tileTitlebarAndRedisplay:)]) {
//                [frameView _tileTitlebarAndRedisplay:NO];
//            }
        }
        ego->m_fullScreenActivated = NO;
        [self sendFSNotification:NSWindowDidExitFullScreenNotification ifTrue:sendNotification];
        NSLog(@"Exit from emulated legacy fullscreen");
    } else {
        NSToolbar *toolBar = [self toolbar];
        NSButton *iconButton = [self standardWindowButton:NSWindowDocumentIconButton];
        NSURL *reprURL = [self representedURL];

        [self sendFSNotification:NSWindowWillEnterFullScreenNotification ifTrue:sendNotification];
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
            // adding NSApplicationPresentationAutoHideToolbar is sadly not a solution for
            // the "toolbar problem" which forces us to hide the toolbar.
            newPresOpts |= NSApplicationPresentationAutoHideMenuBar;
        }
        [NSApp setPresentationOptions:newPresOpts];
        // go fullscreen
        [self setFrame:[[self screen] visibleFrame] display:YES animate:NO];
        ego->m_fullScreenActivated = YES;
        [self sendFSNotification:NSWindowDidEnterFullScreenNotification ifTrue:sendNotification];
        NSLog(@"Activated emulated legacy fullscreen");
    }
    if (wasActive) {
        [self makeKeyWindow];
    }
}

@end

@implementation altNSApplicationDelegate
- (instancetype)init
{
    self = [super init];
    m_systrayItem = nil;
    m_menu = nil;
    return self;
}

- (NSMenu *)systrayMenu
{
    if (!m_systrayItem) {
        NSString *bundleIconName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIconFile"];
        if (!bundleIconName || [bundleIconName isEqualToString:@""]) {
            return nil;
        }
        NSImage *icon = [NSImage imageNamed:bundleIconName];
        if (!icon) {
            return nil;
        }
        const NSStatusBar *sBar = [NSStatusBar systemStatusBar];
        m_systrayItem = [[sBar statusItemWithLength:NSSquareStatusItemLength] S_RETAIN];
        CGFloat mHeight = [sBar thickness] - 4;
        NSSize iSize = {mHeight, mHeight};
        [icon setSize:iSize];
// A solution from Qt to make NSStatusItems hidable: give them a custom view based on NSImageView
// This would have to track mouseclicks and invoke popUpStatusItemMenu; see qcocoasystemtrayicon.mm
// from the Cocoa QPA or in my osx-integration repo.
//        [m_systrayItem setView:[[NSImageView alloc] init]];
//        [(NSImageView*)([m_systrayItem view]) setImage:icon];
        [m_systrayItem setImage:icon];
        [m_systrayItem setToolTip:[NSString
                                 stringWithFormat:@"Toggle legacy full-screen mode for application \"%@\"",
                                 getApplicationName()]];
    }
    if (!m_menu) {
        m_menu = [[[NSMenu alloc] init] S_RETAIN];
    }
    if (m_systrayItem && m_menu != [m_systrayItem menu]) {
        [m_systrayItem setHighlightMode:YES];
        [m_systrayItem setMenu:m_menu];
    }
    return m_menu;
}

- (void)menuItemChanged:(NSNotification *)aNotification
{
    NSMenuItem *item = [[m_systrayItem menu] itemAtIndex:
                        [[[aNotification userInfo] objectForKey:@"NSMenuItemIndex"] intValue]];
    if ([item isEnabled]) {
        // this will restore the systray widget with its menu
        [self systrayMenu];
    } else {
        // drastic measures to keep things easy (no need for a custom NSImageView-based view
        // that can be un/hidden and knows how to display a menu...
        // First, close the menu (what's in a name...):
        [m_menu cancelTrackingWithoutAnimation];
        // now remove and discard the status bar item, but preserve the menu.
        [m_systrayItem setMenu:nil];
        [[NSStatusBar systemStatusBar] removeStatusItem:m_systrayItem];
        [m_systrayItem S_RELEASE];
        m_systrayItem = nil;
    }
}

- (void) dealloc
{
    [m_menu S_RELEASE];
    [m_systrayItem S_RELEASE];
    [super S_DEALLOC];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSLog(@"%s %@", __PRETTY_FUNCTION__, aNotification);
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    NSLog(@"%s %@", __PRETTY_FUNCTION__, aNotification);
}
@end

@interface NSMenu (Extended)
- (NSMenuItem *)itemWithTitle:(NSString *)aString  recursiveSearch:(BOOL)isRecursive;
@end

@implementation NSMenu (Extended)
    - (NSMenuItem *)itemWithTitle:(NSString *)aString  recursiveSearch:(BOOL)isRecursive
    {
        NSMenuItem *ret;
        if (isRecursive) {
            ret = [self itemWithTitle:aString];
            if (!ret) {
                NSArray *items = [self itemArray];
                for (NSMenuItem *item in items) {
                    NSMenu *submenu = [item submenu];
                    if (submenu && (ret = [submenu itemWithTitle:aString recursiveSearch:true])) {
                        return ret;
                    }
                }
            }
        } else {
            ret = [self itemWithTitle:aString];
        }
        return ret;
    }
@end

@implementation LegacyFullScreen
+(void) load
{
    fsDelegate = [[altNSApplicationDelegate alloc] init];
    if (fsDelegate){
        [[NSNotificationCenter defaultCenter] addObserver:fsDelegate
                                                 selector:@selector(applicationDidFinishLaunching:)
                                                     name:NSApplicationDidFinishLaunchingNotification object:NSApp];
//        [[NSNotificationCenter defaultCenter] addObserver:fsDelegate
//                                                          selector:@selector(applicationWillTerminate:)
//          name:NSApplicationWillTerminateNotification object:NSApp];
    }

    NSBundle *mainBundle = [NSBundle mainBundle];
    // the ID of the application we're being injected into:
    NSString *appID = [mainBundle objectForInfoDictionaryKey:@"CFBundleIdentifier"];

    // ignore LSBackgroundOnly=1 and (a priori) also LSUIElement=1 applications as they don't have their
    // own menu and we thus cannot ensure that they'll be able to exit FS mode (even if they can get into it).
    if ([[mainBundle objectForInfoDictionaryKey:@"LSUIElement"] boolValue]
            || [[mainBundle objectForInfoDictionaryKey:@"NSUIElement"] boolValue]) {
        NSLog(@"Legacy FullScreen emulation NOT used for \"agent\" application \"%@\" (%@)", getApplicationName(), appID);
        return;
    } else if ([[mainBundle objectForInfoDictionaryKey:@"LSBackgroundOnly"] boolValue]
               || [[mainBundle objectForInfoDictionaryKey:@"NSBGOnly"] boolValue]) {
        NSLog(@"Legacy FullScreen emulation NOT used for background-only application \"%@\" (%@)", getApplicationName(), appID);
        return;
    }

    NSBundle *thisPluginBundle = [NSBundle bundleForClass:[self class]];
    NSDictionary *defaults = thisPluginBundle? [[[NSUserDefaults alloc] init] persistentDomainForName:[thisPluginBundle bundleIdentifier]] : nil;

    // Try to get the blackList of appIDs that we shouldn't serve
    // First, see if the user set any defaults. These should be readable even in sandboxed host apps.
    NSArray *blackList = nil,
            *userBlackList = [defaults objectForKey:@"SIMBLApplicationIdentifierBlacklist"];
//    NSLog(@"blacklist from user prefs: %@ (%@;%d)", blackList, [blackList className], [blackList isKindOfClass:[NSArray class]]);
    if (![userBlackList isKindOfClass:[NSArray class]]) {
        userBlackList = nil;
    }
    if (thisPluginBundle) {
        // next, try to get it from the plugin's Info.plist. This may fail in sandboxed host apps!
        NSDictionary *infoPList = [thisPluginBundle infoDictionary];
        // reuse the info key also used at the level of the SIMBL agent (for all plugins)
        // (evidently this doesn't interfere with that "global" key!)
        blackList = [infoPList objectForKey:@"SIMBLApplicationIdentifierBlacklist"];
        //NSLog(@"blacklist from Info.plist: %@ (%@;%d)", blackList, [blackList className], [blackList isKindOfClass:[NSArray class]]);
    }
    if (!blackList || ![blackList isKindOfClass:[NSArray class]]) {
        // fall back on a hardcoded list
        blackList = [NSArray arrayWithObjects:@"com.apple.Preview",@"com.apple.finder",nil];
        NSLog(@"Warning: using hardcoded default appID blacklist (%@)!", blackList);
    }

    // Now do the same for a whiteList of applications which don't require adding a menu item,
    // to exit from our FS mode, because they already provide their own, compatible mechanism.
    NSArray *whiteList = [NSArray arrayWithObjects:@"com.apple.firefox",nil],
            *userWhiteList = [defaults objectForKey:@"ApplicationIdentifierWhitelist"];
    if (![userWhiteList isKindOfClass:[NSArray class]]) {
        userWhiteList = nil;
    }

    if (![blackList containsObject:appID] && ![userBlackList containsObject:appID]) {
        // see if we need to provide a "Enter Full Screen" menu item so the user can exit FS mode again:
        NSMenu *mainMenu = [NSApp mainMenu];
        if (!mainMenu) {
            NSLog(@"Warning: %@ (%@) does not (currently) have a menu structure at all!", appID, getApplicationName());
        }
        NSMenuItem *here = [mainMenu itemWithTitle:@"Enter Full Screen" recursiveSearch:YES];
        BOOL appOK = [whiteList containsObject:appID] || [userWhiteList containsObject:appID];
        if (!appOK && !here && mainMenu) {
            NSMenu *targetMenu = [[mainMenu itemWithTitle:@"View"] submenu];
            if (targetMenu) {
                // add "Enter FullScreen Ctrl-Cmd-F" if it doesn't already exist
                here = [targetMenu itemWithTitle:@"Enter Full Screen"];
                if (!here) {
                    here = [targetMenu addItemWithTitle:@"Enter Full Screen" action:@selector(toggleFullScreen:) keyEquivalent:@"f"];
                    [here setKeyEquivalentModifierMask:NSCommandKeyMask|NSControlKeyMask];
                }
            } else {
                targetMenu = [NSApp windowsMenu];
                if (targetMenu) {
                    here = [targetMenu itemWithTitle:@"Enter Full Screen"];
                    if (!here) {
                        // add "Enter FullScreen Ctrl-Cmd-F" after the Zoom (or the Minimize) item
                        here = [targetMenu itemWithTitle:@"Zoom"];
                        if (!here) {
                            here = [targetMenu itemWithTitle:@"Minimize"];
                        }
                        if (here) {
                            here = [targetMenu insertItemWithTitle:@"Enter Full Screen" action:@selector(toggleFullScreen:) keyEquivalent:@""
                                    atIndex:[targetMenu indexOfItem:here]+1];
                        } else {
                            here = [targetMenu addItemWithTitle:@"Enter Full Screen" action:@selector(toggleFullScreen:) keyEquivalent:@""];
                        }
                    }
                } else {
                    // If we're here that means we couldn't find a suitable menu to add our item to.
                    // Best option that gives the least chance of interference from and with the host application
                    // is to add a status bar (aka systray) menu. There can be more than one of those, and a priori
                    // the host cannot know about ours.
                    // NB: we may need to rethink this for applications that do not have a menu at all...
                    targetMenu = [fsDelegate systrayMenu];
                    if (targetMenu) {
                        here = [targetMenu addItemWithTitle:@"Enter Full Screen" action:@selector(toggleFullScreen:) keyEquivalent:@""];
                        // The application may disable the FS menuitem if it doesn't support (native) full screen mode.
                        // We track this to hide our systraymenu ... but that doesn't always work. Disabling it here does
                        // have the expected effect, and as far as I can tell the item will be re-enabled (and the systray item show)
                        // if (native) fullscreen mode is supported. (See the ALWAYS_ADD_SYSTRAYMENU snippet below).
                        [here setEnabled:NO];
                        [[NSNotificationCenter defaultCenter] addObserver:fsDelegate
                                                                 selector:@selector(menuItemChanged:)
                                                                     name:NSMenuDidChangeItemNotification object:targetMenu];
                    } else {
                        // last attempt, a hail-mary: the Dock menu.
                        NSApplication *theApp = [NSApplication sharedApplication];
                        NSObject<NSApplicationDelegate> *delegate = theApp.delegate;
                        targetMenu = [delegate respondsToSelector:@selector(applicationDockMenu)] ? [delegate applicationDockMenu:theApp] : nil;
                        // this may work but the item might not survive...
                        if (targetMenu) {
                            NSLog(@"Warning: adding \"Enter Full Screen\" menu to the dockMenu! %@", targetMenu);
                            here = [targetMenu itemWithTitle:@"Hide"];
                            if (here) {
                                here = [targetMenu insertItemWithTitle:@"Enter Full Screen" action:@selector(toggleFullScreen:) keyEquivalent:@""
                                       atIndex:[targetMenu indexOfItem:here]+1];
                            } else {
                                here = [targetMenu addItemWithTitle:@"Enter Full Screen" action:@selector(toggleFullScreen:) keyEquivalent:@""];
                            }
                        }
                    }
                }
                if (here) {
                    [here setKeyEquivalent:@"f"];
                    [here setKeyEquivalentModifierMask:NSCommandKeyMask|NSControlKeyMask];
                }
            }
        }
        if (appOK || here) {
#ifdef ALWAYS_ADD_SYSTRAYMENU
            {   NSMenu *fsMenu = [fsDelegate systrayMenu];
                if (fsMenu) {
                    NSMenuItem *there = [fsMenu addItemWithTitle:@"Enter Full Screen" action:@selector(toggleFullScreen:) keyEquivalent:@"f"];
                    [there setKeyEquivalentModifierMask:NSCommandKeyMask|NSControlKeyMask];
                    [there setEnabled:NO];
                    [[NSNotificationCenter defaultCenter] addObserver:fsDelegate
                                                             selector:@selector(menuItemChanged:)
                                                                 name:NSMenuDidChangeItemNotification object:fsMenu];
                }
            }
#endif // ALWAYS_ADD_SYSTRAYMENU
            // Now we know we can swizzle!
            ZKSwizzle(altNSWindow, NSWindow);
            NSLog(@"Legacy fullscreen emulation for application ID \"%@\" (%@)", appID, [thisPluginBundle bundlePath]);
        } else {
            NSLog(@"Couldn't add the missing \"Enter Full Screen\" menu; NO legacy fullscreen emulation for application ID \"%@\" (%@)", appID, [thisPluginBundle bundlePath]);
        }
    } else {
        NSLog(@"Legacy FullScreen emulation NOT used for blacklisted application \"%@\" (%@)", getApplicationName(), appID);
    }
}
@end
