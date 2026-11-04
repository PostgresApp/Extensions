#!/bin/zsh

set -e

EXTENSION_NAME=wal2json
EXTENSION_REPO_URL=https://github.com/eulerto/wal2json
EXTENSION_VERSION=2_7 # https://github.com/eulerto/wal2json/releases
PG_MAJOR_VERSION=19
PREFIX=/Applications/Postgres.app/Contents/Versions/$PG_MAJOR_VERSION
DESTDIR=$PWD/Build
INSTALL_ROOT=$PWD/Build/$PREFIX

# download and extract extension to address_standardizer-$EXTENSION_VERSION
echo
echo 
echo "Downloading Extension Sources"
echo
mkdir -p Build
curl -L $EXTENSION_REPO_URL/archive/refs/tags/wal2json_$EXTENSION_VERSION.tar.gz | tar x --cd Build

# build and install the extension
echo
echo 
echo "Building Extension..."
echo
make -C Build/$EXTENSION_NAME-wal2json_$EXTENSION_VERSION install PG_CONFIG=$PREFIX/bin/pg_config DESTDIR="$DESTDIR"

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
cat Build/$EXTENSION_NAME-wal2json_$EXTENSION_VERSION/LICENSE >Build/Resources/license.txt
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