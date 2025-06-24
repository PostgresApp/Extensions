#!/bin/zsh

set -e

EXTENSION_VERSION=1.6.3
PG_MAJOR_VERSION=18
PREFIX=/Applications/Postgres.app/Contents/Versions/$PG_MAJOR_VERSION

# download and extract extension to pgsql-http-$EXTENSION_VERSION
echo
echo 
echo "Downloading Extension Sources"
echo
mkdir -p Build
curl -L https://github.com/pramsey/pgsql-http/archive/refs/tags/v$EXTENSION_VERSION.tar.gz | tar x --cd Build

# build and install the extension
echo
echo 
echo "Building Extension..."
echo
make -C Build/pgsql-http-$EXTENSION_VERSION install PG_CONFIG=$PREFIX/bin/pg_config DESTDIR=$PWD/Build

# codesign libraries
codesign --sign "Developer ID Application" --timestamp Build$PREFIX/lib/postgresql/*.dylib

# Build Installer Package
echo
echo 
echo "Creating Installer Package..."
echo
mkdir -p Build/Resources
for file in Resources/*.html distribution.xml
do
	sed -e "s|@EXTENSION_VERSION@|${EXTENSION_VERSION}|g" -e "s|@PG_MAJOR_VERSION@|${PG_MAJOR_VERSION}|g" $file > Build/$file
done
pkgbuild --root Build$PREFIX --install-location /Library/Application\ Support/Postgres/Extensions/$PG_MAJOR_VERSION/http --identifier com.postgresapp.extension.$PG_MAJOR_VERSION.http --sign "Developer ID Installer" --scripts Scripts http-$PG_MAJOR_VERSION.pkg
productbuild --distribution Build/distribution.xml --resources Build/Resources --sign "Developer ID Installer" http-pg$PG_MAJOR_VERSION-$EXTENSION_VERSION.pkg
rm http-$PG_MAJOR_VERSION.pkg

# Notarize installer package
echo
echo 
echo "Notarizing package..."
echo
xcrun notarytool submit http-pg$PG_MAJOR_VERSION-$EXTENSION_VERSION.pkg --keychain-profile postgresapp --wait
xcrun stapler staple http-pg$PG_MAJOR_VERSION-$EXTENSION_VERSION.pkg

echo
echo
echo "Done."
echo