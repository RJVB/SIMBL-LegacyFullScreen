LegacyNativeFullscreen
======================

SIMBL plugin that makes [NSWindow toggleFullScreen] behave like the pre-10.7 full screen mode.

The window simply drops its titlebar and is resized to the size of its current screen, with the menubar set to auto-hide and the Dock hidden.

There is no interaction with the "screens have separate spaces" setting, in particular the other screen(s) are NOT blacked out if that setting is OFF.
(One might call this a consistent full screen mode!)

There are no animations, so moving into and out of full screen mode is more or less instantaneous.

Note that windows cannot have a toolbar with this full screen mode, so if they have one it will be hidden and restored upon exit from full screen mode.

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

Blacklisting applications:
==========================
This plugin supports blacklisting applications that do not work well with the changes caused by the plugin; Preview.app is an example which is already blacklisted, so is the Finder.
To add applications, open LegacyFullScreen.bundle/Contents/Info.plist in your editor of choice and add their bundle identifier (e.g. `com.apple.Preview` for the Preview app) to the `SIMBLApplicationIdentifierBlacklist` key.
Or add it to the Info.plist file in the source tree, and rebuild.

Please file an issue for if you encounter such applications, so I can add them too.
