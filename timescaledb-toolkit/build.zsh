#!/bin/zsh

set -e

EXTENSION_NAME=timescaledb-toolkit
EXTENSION_VERSION=1.22.0 # https://github.com/timescale/timescaledb/releases
CARGO_PGRX_VERSION=0.16.1 # https://github.com/timescale/timescaledb-toolkit/blob/$EXTENSION_VERSION/extension/Cargo.toml
PG_MAJOR_VERSION=18
PREFIX=/Applications/Postgres.app/Contents/Versions/$PG_MAJOR_VERSION
DESTDIR=$PWD/Build
INSTALL_ROOT=$PWD/Build/$PREFIX

# make sure the correct pg_config is picked up
export PATH=$PREFIX/bin:$PATH

echo 
echo 
echo Installing Rust
echo
curl -sSf https://sh.rustup.rs | sh -s -- -y

echo
echo 
echo Installing pgrx
echo
cargo install cargo-pgrx@$CARGO_PGRX_VERSION

echo
echo 
echo Downloading Extension Sources
echo
mkdir -p Build
curl -L https://github.com/timescale/timescaledb-toolkit/archive/refs/tags/$EXTENSION_VERSION.tar.gz | tar x --cd Build

# build and install the extension
echo
echo 
echo "Building Extension..."
echo
(
	cd Build/$EXTENSION_NAME-$EXTENSION_VERSION/extension
	
	# workaround for inttypes.h not found
	export BINDGEN_EXTRA_CLANG_ARGS="$(xcrun --show-sdk-path | xargs -I{} echo -isysroot {})"
	
	cargo pgrx package --pg-config "$PREFIX"/bin/pg_config --out-dir ../..
)
	
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