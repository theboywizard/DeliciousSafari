#!/bin/bash
# DeliciousSafari build script
# Copyright Doug Richardson 2008
# Usage: build.sh <version>
#
# EXAMPLE:
# ./build.sh 1.5
#
# The result is a disk image that contains the DeliciousSafari installer
# and the DeliciousSafari Uninstaller. The disk image is formatted using
# a pre-built .DS_Store.
#
# The pre-built .DS_Store was created manually by creating
# a disk image, positioning the elements, setting the background image,
# adjusting the icon size, and then copying the resulting .DS_Store.
# For the pre-built .DS_Store to work, the names of the files must
# not change between builds.

#
# Get the short version number from the command line.
#
VERSION=$1

if [ -z $VERSION ]; then
    echo "Usage: build.sh <version>"
    exit 1;
fi

if [ ! -d DeliciousSafari.xcodeproj ]; then
    echo "Usage: build.sh <version>"
    exit 1
fi

#
# Make sure the Info.plist has the right short version number in it.
#
INFO_PLIST_VERSION=`defaults read \`pwd\`/Info CFBundleShortVersionString`

if [ "$INFO_PLIST_VERSION" != "$VERSION" ]; then
    echo "Info.plist has a version of $INFO_PLIST_VERSION. Expected version of $VERSION"
    exit 1;
fi

#
# Increment the bundle version
#

# Make sure Xcode isn't running before incrementing the version.
ps -Ao comm|grep Xcode.app/Contents/MacOS/Xcode > /dev/null
if [ "$?" == 0 ]; then
    echo Xcode is running. Quit Xcode before running build.sh as this script will modify the DeliciousSafari Xcode project.
    exit 1
fi

xcrun agvtool next-version -all 
if [ "$?" != 0 ]; then
    echo "Couldn't find agvtool. Perhaps you need to install the Command Line Tools in Xcode."
    exit 1
fi


DSTROOT=/tmp/DeliciousSafari.dst
SRCROOT=/tmp/DeliciousSafari.src

INSTALLER_PATH=/tmp/DeliciousSafari.installer
INSTALLER_PKG="DeliciousSafari.pkg"
INSTALLER="$INSTALLER_PATH/$INSTALLER_PKG"

IMGROOT=/tmp/DeliciousSafari.imgroot

DMG_PATH=/tmp/DeliciousSafari.distribution
DMG="$DMG_PATH/DeliciousSafari $VERSION.dmg"
DMG_TITLE="DeliciousSafari"
MOUNTED_DMG_PATH="/Volumes/$DMG_TITLE"

#
# Clean out anything that doesn't belong.
#
echo Going to clean out build directories
rm -rf build $DSTROOT $SRCROOT $IMGROOT $INSTALLER_PATH $DMG_PATH /tmp/FoundationDataObjects.dst FoundationDataObjects/build
echo Build directories cleaned out


#
# Build
#
echo ------------------
echo Installing Sources
echo ------------------
xcodebuild -project DeliciousSafari.xcodeproj installsrc SRCROOT=$SRCROOT || exit 1

echo ----------------
echo Building Project
echo ----------------
pushd $SRCROOT
xcodebuild -project DeliciousSafari.xcodeproj -target all -configuration Release install || exit 1
popd

#
# Make installer
#
echo ----------
echo Fixup Root
echo ----------

# Get rid of everything in /usr/local like ASHelper. Don't do everything automatically, otherwise
# you might slightly delete something you need.
DSTLOCAL="$DSTROOT/usr/local/bin"
rm "$DSTLOCAL/ASHelper" || exit 1
rm "$DSTLOCAL/DSUninstaller" || exit 1
rmdir "$DSTROOT/usr/local/bin/" || exit 1
rmdir "$DSTROOT/usr/local" || exit 1
rmdir "$DSTROOT/usr" || exit 1


echo ------------------
echo Building Installer
echo ------------------
mkdir -p "$INSTALLER_PATH" || exit 1
pushd installer

echo "Runing pkgbuild. Note you must be connected to Internet for this to work as it"
echo "has to contact a time server in order to generate a trusted timestamp. See"
echo "man pkgbuild for more info under SIGNED PACKAGES."
pkgbuild --identifier "com.delicioussafari.DSInstaller" \
    --scripts "$SRCROOT/installer/scripts" \
    --sign "Developer ID Installer: Douglas Richardson (4L84QT8KA9)" \
    --root "$DSTROOT" \
    "$INSTALLER" || exit 1
popd

#
# Make the Disk Image Root
#
echo ---------------------------
echo Building Disk Image Root...
echo ---------------------------
mkdir -p "$IMGROOT" || exit 1
ditto "$INSTALLER" "$IMGROOT/$INSTALLER_PKG" || exit 1
SetFile -a E "$IMGROOT/$INSTALLER_PKG" || exit 1
ditto "$DSTROOT/Applications/Uninstall DeliciousSafari.app" "$IMGROOT/Uninstall DeliciousSafari.app" || exit 1
cp installer/DMG-Background.png "$IMGROOT" || exit 1
SetFile -a V "$IMGROOT/DMG-Background.png" || exit 1
cp installer/DMG_DS_Store "$IMGROOT/.DS_Store" || exit 1

#
# Make Disk Image
#
echo
echo Building Disk Image...
mkdir -p "$DMG_PATH" || exit 1
hdiutil create -srcfolder "$IMGROOT" -fs HFS+ -volname "DeliciousSafari"  "$DMG" || exit 1


echo Successfully built DeliciousSafari
open "$DMG_PATH"
exit 0
