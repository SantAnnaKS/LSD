#!/bin/bash
#**************************************************************
#
#	LSD 8.1 - July 2023
#	written by Marco Valente, Universita' dell'Aquila
#	and by Marcelo Pereira, University of Campinas
#
#	Copyright Marco Valente and Marcelo Pereira
#	LSD is distributed under the GNU General Public License
#
#	See Readme.txt for copyright information of
#	third parties' code used in LSD
#
#**************************************************************

#**************************************************************
# CREATE-INSTALLER-MAC.SH
# Create LSD installer for macOS.
#**************************************************************

LSD_VER_NUM="8.1"
LSD_VER_TAG="stable-4"

if [ "$1" = "-h" ]; then
	echo "Create LSD installer for macOS"
	echo "Usage: ./create-installer-mac.sh [LSD FOLDER]"
	exit 0
fi

LSD_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd -P )"

if [ -z "$1" ]; then
	if [ ! -d "$LSD_DIR"/LMM.app ]; then
		echo "No LSD FOLDER provided or found, aborting"
		exit 1
	fi
else
	if [ -d "$1"/LMM.app ]; then
		LSD_DIR="$1"
	else
		echo "Provided LSD FOLDER not found, aborting"
		exit 2
	fi
fi

README="Readme.txt"
LSD_VER="$LSD_VER_NUM-$LSD_VER_TAG"
LSD_FILE_TAG="${LSD_VER//./-}"
SRC_DIR="$LSD_DIR/src"
DMG_DIR="$LSD_DIR/installer"
INST_DIR="$DMG_DIR/LSD Installer.app/Contents/Resources"
FILENAME="$DMG_DIR/LSD-installer-mac"
APPNAME="LSD Installer"
EXC_LST="$( tr '\n' ' ' < $LSD_DIR/installer/exclude-installer-mac.txt )"

# create zipped distribution package
rm -f $DMG_DIR/LSD-archive-mac.zip
cd "$LSD_DIR"
# apparently the macOS zip version has a bug handling exclusion filelist, so the workaround
#zip -9 -q -r -X $DMG_DIR/LSD-archive-mac.zip . -x@"$LSD_DIR"/installer/exclude-installer-mac.txt
eval zip -9 -q -r -X $DMG_DIR/LSD-archive-mac.zip . -x $EXC_LST
cd - > /dev/null

# update the installer application
rm -f "$INST_DIR/Package/LSD-archive-mac.zip" "$INST_DIR/Scripts/src/"*
mv -f "$DMG_DIR/LSD-archive-mac.zip" "$INST_DIR/Package/"
cp -f "$SRC_DIR/"*.tcl "$INST_DIR/Scripts/src/"

# create .dmg archive
rm -f -R /tmp/LSD_INSTALLER "$FILENAME-$LSD_FILE_TAG.dmg"
mkdir "/tmp/LSD_INSTALLER"
mkdir "/tmp/LSD_INSTALLER/$APPNAME ($LSD_VER).app"
cp -f -R "$DMG_DIR/$APPNAME.app/"* "/tmp/LSD_INSTALLER/$APPNAME ($LSD_VER).app/"
cp -f "$LSD_DIR/$README" "/tmp/LSD_INSTALLER/"

hdiutil create /tmp/tmp.dmg -fs HFS+ -ov -quiet -volname "$APPNAME ($LSD_VER)" -srcfolder "/tmp/LSD_INSTALLER/"
hdiutil convert /tmp/tmp.dmg -format UDBZ -o "$FILENAME-$LSD_FILE_TAG.dmg" -quiet

# cleanup
rm -f -R "$INST_DIR"/Package/LSD-archive-mac.zip "$INST_DIR"/Scripts/src/* /tmp/LSD_INSTALLER /tmp/tmp.dmg

if [ -f "$FILENAME-$LSD_FILE_TAG.dmg" ]; then
	echo "Self-extracting LSD package created: $FILENAME-$LSD_FILE_TAG.dmg"
else
	echo "Error creating LSD installer"
fi
