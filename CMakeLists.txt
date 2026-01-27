set(CMAKE_OSX_ARCHITECTURES i386 x86_64)
set(CMAKE_VERBOSE_MAKEFILE ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
if (NOT CMAKE_OSX_SYSROOT)
    message(STATUS "Setting CMAKE_OSX_SYSROOT to /")
    set(CMAKE_OSX_SYSROOT "/")
endif()

project(LegacyFullScreen OBJC)

set(lfs_SRC LegacyFullScreen.m
            ZKSwizzle/ZKSwizzle.m)

set(RESRCS  English.lproj/InfoPlist.strings)
set_source_files_properties(${RESRCS} PROPERTIES
      MACOSX_PACKAGE_LOCATION Resources)


add_compile_options(-Os
            -g
            -march=westmere
            -msse4.1 -msse4.2 -msse3 -mssse3 -msse2 -msse -mmmx -mpclmul
            -ftree-vectorize)

set_source_files_properties(LegacyFullScreen.m PROPERTIES
    COMPILE_OPTIONS "-fobjc-arc-exceptions;-fobjc-arc;-fobjc-weak")

add_library(LegacyFullScreen MODULE ${lfs_SRC})
# set properties to BUNDLE
set_target_properties(LegacyFullScreen PROPERTIES
    BUNDLE ON
    MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/Info.plist
    RESOURCE "${RESRCS}")

target_link_libraries(LegacyFullScreen "-framework Cocoa")

# -*- coding: utf-8; mode: cmake; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=cmake:et:sw=4:ts=4:sts=4
