#!/bin/zsh

set -e

EXTENSION_NAME=address_standardizer
EXTENSION_REPO_URL=https://github.com/postgis/address_standardizer
EXTENSION_VERSION=3.7.0 # https://github.com/postgis/address_standardizer/releases
PG_MAJOR_VERSION=19
PREFIX=/Applications/Postgres.app/Contents/Versions/$PG_MAJOR_VERSION
DESTDIR=$PWD/Build
INSTALL_ROOT=$PWD/Build/$PREFIX

# Note on PCRE dependency
# -----------------------
# PCRE is provided by macOS: (via https://github.com/apple-oss-distributions/distribution-macOS, https://github.com/apple-oss-distributions/pcre)
#   Mac OS X 10.7: PCRE 8.02
#   macOS 10.13: PCRE 8.40
#   macOS 10.15: PCRE 8.42
#   macOS 11: PCRE 8.44
#   macOS 13: PCRE 8.44 PCRE2 10.42
#   macOS 26: still the same
# This version of address_standardizer requires PCRE2, so we require macOS 13 at installation time of the pkg
# The PCRE header is not bundled in the macOS SDK. We vendor it from src/pcr2.h.generic of version 10.42

# download and extract extension to address_standardizer-$EXTENSION_VERSION
echo
echo 
echo "Downloading Extension Sources"
echo
mkdir -p Build
curl -L $EXTENSION_REPO_URL/archive/refs/tags/v$EXTENSION_VERSION.tar.gz | tar x --cd Build

# build and install the extension
echo
echo 
echo "Building Extension..."
echo
make -C Build/$EXTENSION_NAME-$EXTENSION_VERSION install PG_CONFIG=$PREFIX/bin/pg_config DESTDIR="$DESTDIR" PG_CFLAGS="-I$PWD/vendor"

# codesign libraries
codesign --sign "Developer ID Application" --timestamp "$INSTALL_ROOT"/lib/postgresql/*.dylib

# Build Installer Package
echo
echo 
echo "Creating Installer Package..."
echo
mkdir -p Build/Resources
for file in Resources/*.html distribution.xml
do
	sed -e "s|@EXTENSION_VERSION@|${EXTENSION_VERSION}|g" -e "s|@PG_MAJOR_VERSION@|${PG_MAJOR_VERSION}|g" -e "s|@EXTENSION_NAME@|${EXTENSION_NAME}|g" $file > Build/$file
done
cat Build/$EXTENSION_NAME-$EXTENSION_VERSION/COPYING >Build/Resources/license.txt
pkgbuild --root "$INSTALL_ROOT" --install-location /Library/Application\ Support/Postgres/Extensions/$PG_MAJOR_VERSION/$EXTENSION_NAME --identifier com.postgresapp.extension.$PG_MAJOR_VERSION.$EXTENSION_NAME --sign "Developer ID Installer" --scripts Scripts $EXTENSION_NAME-$PG_MAJOR_VERSION.pkg
productbuild --distribution Build/distribution.xml --resources Build/Resources --sign "Developer ID Installer" $EXTENSION_NAME-pg$PG_MAJOR_VERSION-$EXTENSION_VERSION.pkg
rm $EXTENSION_NAME-$PG_MAJOR_VERSION.pkg

# Notarize installer package
echo
echo 
echo "Notarizing package..."
echo
xcrun notarytool submit $EXTENSION_NAME-pg$PG_MAJOR_VERSION-$EXTENSION_VERSION.pkg --keychain-profile postgresapp --wait
xcrun stapler staple $EXTENSION_NAME-pg$PG_MAJOR_VERSION-$EXTENSION_VERSION.pkg

echo
echo
echo "Done."
echo