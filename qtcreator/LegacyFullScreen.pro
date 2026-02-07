DEFINES += LEGACYFULLSCREEN_LIBRARY

TEMPLATE = lib
CONFIG += plugin plugin_bundle
CONFIG -= widgets

# LegacyFullScreen files

SOURCES_NOARC = ../ZKSwizzle/ZKSwizzle.m
objc_noarc.name = objc_noarc
objc_noarc.input = SOURCES_NOARC
objc_noarc.dependency_type = TYPE_C
objc_noarc.variable_out = OBJECTS
objc_noarc.output = ${QMAKE_VAR_OBJECTS_DIR}${QMAKE_FILE_IN_BASE}$${first(QMAKE_EXT_OBJ)}
objc_noarc.commands = $${QMAKE_CC} $(CFLAGS) -fno-objc-arc $(INCPATH) -c ${QMAKE_FILE_IN} -o ${QMAKE_FILE_OUT}
QMAKE_EXTRA_COMPILERS += objc_noarc

QMAKE_CFLAGS += -fobjc-arc-exceptions -fobjc-arc -fobjc-weak
SOURCES = ../LegacyFullScreen.m

#objc_arc.name = objc_arc
#objc_arc.input = SOURCES_ARC
#objc_arc.dependency_type = TYPE_C
#objc_arc.variable_out = OBJECTS
#objc_arc.output = ${QMAKE_VAR_OBJECTS_DIR}${QMAKE_FILE_IN_BASE}$${first(QMAKE_EXT_OBJ)}
#objc_arc.commands = $${QMAKE_CC} $(CFLAGS) -fobjc-arc-exceptions -fobjc-arc -fobjc-weak $(INCPATH) -c ${QMAKE_FILE_IN} -o ${QMAKE_FILE_OUT}
#QMAKE_EXTRA_COMPILERS += objc_arc


HEADERS = ../LegacyFullScreen.h \
    ../ZKSwizzle/ZKSwizzle.h

TARGET = LegacyFullScreen

DISTFILES += \
    ../English.lproj/InfoPlist.strings \
    ../Info.plist \
    ../README.md


