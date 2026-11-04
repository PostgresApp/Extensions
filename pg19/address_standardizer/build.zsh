#!/bin/zsh

set -e

EXTENSION_NAME=address_standardizer
EXTENSION_REPO_URL=https://github.com/postgis/address_standardizer
EXTENSION_VERSION=3.7.0 # https://github.com/postgis/address_standardizer/releases
PCRE2_REPO_URL=https://github.com/PCRE2Project/pcre2
PCRE2_VERSION=10.49 # https://github.com/PCRE2Project/pcre2/releases
PG_MAJOR_VERSION=19
PREFIX=/Applications/Postgres.app/Contents/Versions/$PG_MAJOR_VERSION
DESTDIR=$PWD/Build
INSTALL_ROOT=$PWD/Build/$PREFIX

# download and extract PCRE2 dependency to pcre2-$PCRE2_VERSION
echo
echo 
echo "Downloading Depedency Sources"
echo
mkdir -p Build
curl -L $PCRE2_REPO_URL/releases/download/pcre2-$PCRE2_VERSION/pcre2-$PCRE2_VERSION.tar.gz | tar x --cd Build

# build and install the dependency
echo
echo 
echo "Building Dpendency..."
echo
(
	cd Build/pcre2-$PCRE2_VERSION
	./configure --prefix="$INSTALL_ROOT"
	make
	make install
)

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
make -C Build/$EXTENSION_NAME-$EXTENSION_VERSION install PG_CONFIG=$PREFIX/bin/pg_config DESTDIR="$DESTDIR" PG_CFLAGS="-I$INSTALL_ROOT/include"

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
cat Build/pcre2-$PCRE2_VERSION/LICENCE.md >>Build/Resources/license.txt
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