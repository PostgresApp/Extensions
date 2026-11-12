#!/bin/zsh

set -e

EXTENSION_NAME=pldebugger
EXTENSION_REPO_URL=https://github.com/EnterpriseDB/pldebugger
EXTENSION_VERSION=1.10 # https://github.com/EnterpriseDB/pldebugger/releases
PG_MAJOR_VERSION=19
PREFIX=/Applications/Postgres.app/Contents/Versions/$PG_MAJOR_VERSION
DESTDIR=$PWD/Build
INSTALL_ROOT=$PWD/Build/$PREFIX

# download and extract extension to address_standardizer-$EXTENSION_VERSION
echo
echo 
echo "Downloading Extension Sources..."
echo
mkdir -p Build
curl -L $EXTENSION_REPO_URL/archive/refs/tags/v$EXTENSION_VERSION.tar.gz | tar x --cd Build

# patch for pg19 compatibility https://github.com/EnterpriseDB/pldebugger/pull/36 & 37
echo
echo 
echo "Patching Extension..."
echo
patch -b -d Build/$EXTENSION_NAME-$EXTENSION_VERSION -p1 <Patches/pldebugger-pg19-lwlock.patch
patch -b -d Build/$EXTENSION_NAME-$EXTENSION_VERSION -p1 <Patches/pldebugger-pg19-shmeminithash.patch

# build and install the extension
echo
echo 
echo "Building Extension..."
echo
USE_PGXS=1 make -C Build/$EXTENSION_NAME-$EXTENSION_VERSION install PG_CONFIG=$PREFIX/bin/pg_config DESTDIR="$DESTDIR"

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

grep -q '^## Licence' Build/$EXTENSION_NAME-$EXTENSION_VERSION/README-$EXTENSION_NAME.md || { echo "Licence section not found"; exit 1; }
sed -n '/^## Licence/,/^## /p' Build/$EXTENSION_NAME-$EXTENSION_VERSION/README-$EXTENSION_NAME.md | sed '$d' >Build/Resources/license.txt
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