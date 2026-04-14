#!/bin/zsh

set -e

EXTENSION_NAME=plv8
EXTENSION_VERSION=3.2.4 # https://github.com/plv8/plv8/tags
PG_MAJOR_VERSION=18
PREFIX=/Applications/Postgres.app/Contents/Versions/$PG_MAJOR_VERSION
DESTDIR=$PWD/Build

echo
echo 
echo "Downloading Extension Sources"
echo
mkdir -p Build
( 
	git clone https://github.com/plv8/$EXTENSION_NAME.git Build/$EXTENSION_NAME-$EXTENSION_VERSION
	cd Build/$EXTENSION_NAME-$EXTENSION_VERSION
	git checkout v$EXTENSION_VERSION
)

echo
echo 
echo "Building Extension..."
echo
(
	cd Build/$EXTENSION_NAME-$EXTENSION_VERSION
	
	make PG_CONFIG=$PREFIX/bin/pg_config
	
	make install DESTDIR="$DESTDIR"
)

echo
echo 
echo "Codesign Libraries..."
echo
codesign --sign "Developer ID Application" --timestamp Build$PREFIX/lib/postgresql/*.dylib

echo
echo 
echo "Creating Installer Package..."
echo
mkdir -p Build/Resources
for file in Resources/*.html distribution.xml
do
	sed -e "s|@EXTENSION_NAME@|${EXTENSION_NAME}|g" -e "s|@EXTENSION_VERSION@|${EXTENSION_VERSION}|g" -e "s|@PG_MAJOR_VERSION@|${PG_MAJOR_VERSION}|g" $file > Build/$file
done
pkgbuild --root Build$PREFIX --install-location /Library/Application\ Support/Postgres/Extensions/$PG_MAJOR_VERSION/$EXTENSION_NAME --identifier com.postgresapp.extension.$PG_MAJOR_VERSION.$EXTENSION_NAME --sign "Developer ID Installer" --scripts Scripts $EXTENSION_NAME-$PG_MAJOR_VERSION.pkg
productbuild --distribution Build/distribution.xml --resources Build/Resources --sign "Developer ID Installer" $EXTENSION_NAME-pg$PG_MAJOR_VERSION-$EXTENSION_VERSION.pkg
rm $EXTENSION_NAME-$PG_MAJOR_VERSION.pkg

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