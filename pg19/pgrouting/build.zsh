#!/bin/zsh

set -e

EXTENSION_NAME=pgrouting
EXTENSION_REPO_URL=https://github.com/pgRouting/pgrouting/
EXTENSION_VERSION=4.0.2 # https://github.com/pgRouting/pgrouting/releases
PG_MAJOR_VERSION=19
PREFIX=/Applications/Postgres.app/Contents/Versions/$PG_MAJOR_VERSION
DESTDIR=$PWD/Build
INSTALL_ROOT=$PWD/Build/$PREFIX

# NOTE: Building pgrouting requires a non-deployed Postgres.app binary build at $PREFIX and the corsponding temporay source tree to access boost

# download and extract extension to postgis_tiger_geocoder-$EXTENSION_VERSION
echo
echo 
echo "Downloading Extension Sources"
echo
mkdir -p Build
curl -L $EXTENSION_REPO_URL/releases/download/v$EXTENSION_VERSION/$EXTENSION_NAME-$EXTENSION_VERSION.tar.gz | tar x --cd Build
mkdir -p Build/$EXTENSION_NAME-$EXTENSION_VERSION/build

# build and install the extension
echo
echo 
echo "Building Extension..."
echo
(cd Build/$EXTENSION_NAME-$EXTENSION_VERSION/build && cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_HTML=OFF -DBUILD_DOXY=OFF -DES=OFF -DSV=OFF -DZH_HANS=OFF -DPOSTGRESQL_PG_CONFIG=$PREFIX/bin/pg_config -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" -DCMAKE_PREFIX_PATH=$PREFIX)
#-DCMAKE_INSTALL_PREFIX="$(PREFIX)" -DCMAKE_MACOSX_RPATH=ON -DCMAKE_INSTALL_RPATH="$(PREFIX)/lib" -DCMAKE_INSTALL_NAME_DIR="$(PREFIX)/lib")
make -C Build/$EXTENSION_NAME-$EXTENSION_VERSION/build install DESTDIR="$DESTDIR"
# pgrouting didn't yet get the notice, the DLSUFFIX has changed in pg16
EXTENSION_MAJOR_VERSION=$(echo $EXTENSION_VERSION | sed -E 's/^([0-9]+\.[0-9]+)\..*$/\1/')
mv $DESTDIR/$PREFIX/lib/postgresql/libpgrouting-$EXTENSION_MAJOR_VERSION.so $DESTDIR/$PREFIX/lib/postgresql/libpgrouting-$EXTENSION_MAJOR_VERSION.dylib

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
cat Build/$EXTENSION_NAME-$EXTENSION_VERSION/LICENSE >Build/Resources/license.txt
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