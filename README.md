LegacyNativeFullscreen
======================

SIMBL plugin that makes [NSWindow toggleFullScreen] behave like the pre-10.7 full screen mode.

The window simply drops its titlebar and is resized to the size of its current screen, with the menubar set to auto-hide and the Dock hidden.

There is no interaction with the "screens have separate spaces" setting, in particular the other screen(s) are NOT blacked out if that setting is OFF.
(One might call this a consistent full screen mode!)

There are no animations, so moving into and out of full screen mode is more or less instantaneous.

Note that windows cannot have a toolbar with this full screen mode, so if they have one it will be hidden and restored upon exit from full screen mode.

Since not all applications are happy with this new mode, the plugin also provides an attempt to speed up the native fullscreen transition.
The total duration cannot be changed (requires some serious hacking of the Dock process) but at least the window itself transitions instantaneously between the two sizes.

Modified from/based on github.com/Thamster/NoNativeFullscreen .

HowTo:
======
	clone this repo
	open LegacyFullScreen.xcodeproj and build
    OR
    change into the source directory and invoke `xcodebuild -project LegacyFullScreen.xcodeproj`

    Both will automatically install into your SIMBL plugins directory, i.e.:
		~/Library/Application\ Support/SIMBL/Plugins/LegacyFullScreen.bundle

For some applications it may be necessary to move or copy the bundle into /Library/Application Support/SIMBL/Plugins , for others it might be required to log out and back in.

Note that there is a CMake file and a `qtcreator` folder; those are for using alternative IDEs, not to build the plugin!

Black, white and "grey" listing applications:
=============================================
This plugin supports blacklisting applications that do not work well with the changes caused by the plugin; Preview.app and Terminal.app are examples which are already blacklisted, so is the Finder.
To add applications, use the `defaults` command and the org.RJVB.LegacyFullScreen domain. E.g. this will register the builtin defaults:
    > defaults write org.RJVB.LegacyFullScreen SIMBLApplicationIdentifierBlacklist -array "com.apple.Preview" "com.apple.finder"
You can also open LegacyFullScreen.bundle/Contents/Info.plist in your editor of choice and add their bundle identifier (e.g. `com.apple.Preview` for the Preview app) to the `SIMBLApplicationIdentifierBlacklist` key.
Or add it to the Info.plist file in the source tree, and rebuild.
*NB*: it is not necessary to list those defaults applications in your own preferences, but you do have to leave them in the Info.plist!

Any applications that you would like to use the "fast" native mode can be added to the `ApplicationIdentifierFastNativeList` array in the default domain.
This list has priority over the blacklist, so it remains possible to activate "fast" mode in applications that are on the built-in blacklist.

There is also a whitelist that can be set only via the `defaults` command. Again, the built-in default is
    > defaults write org.RJVB.LegacyFullScreen ApplicationIdentifierWhitelist -array "org.mozilla.firefox"
Normally, the plugin will refuse to change full screen behaviour to legacy mode if it fails to add an "Enter Full Screen" menu item if one doesn't already exist.
Many applications have this to toggle into and out of full screen mode, and it can be crucial for being able to exit from legacy full screen mode.
The whitelist is for applications that provide an "exit strategy" even if adding our menu item fails, but does not allow to override a blacklisting.

Please file an issue for if you encounter applications that should be on either list, so I can check and add them too.

About sandboxed applications:
=============================
Sandboxed applications (like Preview.app) will typically not have access to `~/Library/Application Support/SIMBL` nor to arbitraty files under `~/Library/Preferences`.
To load the plugin in these applications, it (or a copy) has to be installed in `/Library/Application Support/SIMBL/Plugins`.

The blocked access to the `org.RJVB.LegacyFullScreen.plist` file in the user Preferences means that blacklisting applications has to be done in the plugin's Info.plist as described above, or as follows.

The Mac user preferences system allows setting custom keys in the default domain of any application, and these modifications will persist (as faras I have tested).

It is thus possible to store the application-specific preference for the LegacyFullScreen plugin in the settings file of that application, e.g. :

    defaults write com.apple.Preview ApplicationLegacyFullScreenMode "FastNative"

This example is in fact the only way to activate "fast" native fullscreen mode in the Preview application.
The same key allows blacklisting by setting `ApplicationLegacyFullScreenMode` to "No".

NB: case is ignored in the values of this key. If the key is missing or has any other value, the regular legacy fullscreen mode is selected as long as the application isn't blacklisted.