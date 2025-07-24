#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# Installation directory for all compiled software
INSTALL_DIR="$HOME/local_static_irssi"
# Directory to download and build source code
BUILD_DIR="$HOME/irssi_build_src_static"
# Log file for debugging
LOG_FILE="$PWD/irssi_static_build.log"
# Number of parallel jobs for make/ninja (detects macOS or Linux)
JOBS=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)

# Versions of software to download
GLIB_VERSION="2.80.0"
OPENSSL_VERSION="3.3.0"
NCURSES_VERSION="6.4"
PKG_CONFIG_VERSION="0.29.2"
PCRE2_VERSION="10.42"
IRSSI_VERSION="1.4.5"

# --- Script ---

# Log all output to a file and to the console
exec &> >(tee -a "${LOG_FILE}")

echo "--- Starting Irssi and Dependencies Static Build with Native CPU Optimizations ---"
echo "Installation will be in: $INSTALL_DIR"
echo "Builds will be done in: $BUILD_DIR"
echo "Output will be logged to: $LOG_FILE"
echo "Using $JOBS parallel jobs for building."
echo "Optimizations: -O3, Full LTO, march=native, mtune=native, omit-frame-pointer"
echo "NOTE: This build will be slow and the binary will be specific to your CPU."
echo "-----------------------------------------------------"

# Clean up previous attempts for a fresh start
echo "--- Cleaning up previous build directories (if they exist) ---"
rm -rf "$BUILD_DIR"
rm -rf "$INSTALL_DIR"
echo "-----------------------------------------------------"

# Create directories
mkdir -p "$INSTALL_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Set environment variables for the static build process
export PATH="$INSTALL_DIR/bin:$PATH"
export PKG_CONFIG_PATH="$INSTALL_DIR/lib/pkgconfig"
export CPPFLAGS="-I$INSTALL_DIR/include -I$INSTALL_DIR/include/ncurses"
export CC=clang
export CFLAGS="-O3 -fPIC -flto -march=native -mtune=native -fomit-frame-pointer"
# **MODIFIED SECTION** - Removed lib64 path which is not used on macOS
export LDFLAGS="-L$INSTALL_DIR/lib -flto"


# 1. Install Meson and Ninja using pip
echo "--- Installing Meson and Ninja ---"
pip3 install --user meson ninja

# Add user's Python bin to PATH robustly
echo "--- Configuring PATH for Meson and Ninja ---"
PYTHON_USER_BIN_DIR=$(python3 -m site --user-base)/bin
if [[ -d "$PYTHON_USER_BIN_DIR" ]]; then
    export PATH="$PYTHON_USER_BIN_DIR:$PATH"
    echo "Found and added Python user bin to PATH: $PYTHON_USER_BIN_DIR"
else
    echo "Warning: Python user bin directory not found. Trying ~/.local/bin as a fallback..."
    if [[ -d "$HOME/.local/bin" ]]; then
        export PATH="$HOME/.local/bin:$PATH"
    fi
fi
command -v meson

# 2. Build pkg-config
echo "--- Building pkg-config ---"
curl -L "https://pkg-config.freedesktop.org/releases/pkg-config-${PKG_CONFIG_VERSION}.tar.gz" | tar xz
cd "pkg-config-${PKG_CONFIG_VERSION}"
./configure --prefix="$INSTALL_DIR" --with-internal-glib --enable-static
make -j"$JOBS"
make install
cd ..

# 3. Build OpenSSL
echo "--- Building OpenSSL ---"
curl -L "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz" | tar xz
cd "openssl-${OPENSSL_VERSION}"
./config --prefix="$INSTALL_DIR" no-shared
make -j"$JOBS"
make install_sw
cd ..

# 4. Build ncurses
echo "--- Building ncurses ---"
curl -L "https://ftp.gnu.org/gnu/ncurses/ncurses-${NCURSES_VERSION}.tar.gz" | tar xz
cd "ncurses-${NCURSES_VERSION}"
./configure --prefix="$INSTALL_DIR" \
            --disable-shared \
            --enable-static \
            --with-termlib \
            --without-debug \
            --enable-pc-files \
            --with-pkg-config-libdir="$INSTALL_DIR/lib/pkgconfig"
make -j"$JOBS"
make install
cd ..

# 5. Build PCRE2 (dependency for GLib)
echo "--- Building PCRE2 ---"
curl -L "https://github.com/PhilipHazel/pcre2/releases/download/pcre2-${PCRE2_VERSION}/pcre2-${PCRE2_VERSION}.tar.bz2" | tar xjf -
cd "pcre2-${PCRE2_VERSION}"
./configure --prefix="$INSTALL_DIR" --disable-shared --enable-static
make -j"$JOBS"
make install
cd ..

# 6. Build GLib
echo "--- Building GLib ---"
curl -L "https://download.gnome.org/sources/glib/$(echo $GLIB_VERSION | cut -d. -f1,2)/glib-${GLIB_VERSION}.tar.xz" | tar xJ
cd "glib-${GLIB_VERSION}"
# **MODIFIED SECTION** - Corrected LTO flag syntax to -Db_lto=true
meson setup build --prefix="$INSTALL_DIR" --default-library=static \
    -Db_lto=true \
    -Dlibmount=disabled \
    -Dselinux=disabled \
    -Dlibelf=disabled \
    -Dxattr=false \
    -Dtests=false
ninja -C build
ninja -C build install
cd ..

# 7. Build Irssi
echo "--- Building Irssi ---"
curl -L "https://github.com/irssi/irssi/releases/download/${IRSSI_VERSION}/irssi-${IRSSI_VERSION}.tar.gz" | tar xz
cd "irssi-${IRSSI_VERSION}"
# **MODIFIED SECTION** - Corrected LTO flag syntax to -Db_lto=true
meson setup build --prefix="$INSTALL_DIR" \
    --default-library=static \
    -Db_lto=true \
    -Dwith-proxy=yes
ninja -C build
ninja -C build install

echo "--- Irssi static build with Native CPU Optimizations complete! ---"
echo "The final executable is located at: $INSTALL_DIR/bin/irssi"
echo ""
echo "You can verify that it is a static executable by running:"
echo "file $INSTALL_DIR/bin/irssi"
echo "And check its dependencies by running:"
echo "otool -L $INSTALL_DIR/bin/irssi"
echo ""
echo "You should only see system libraries (like /usr/lib/libSystem.B.dylib)."
echo ""
echo "You may want to add '$INSTALL_DIR/bin' to your shell's PATH permanently."
echo "For example, add 'export PATH=\"$INSTALL_DIR/bin:\$PATH\"' to your ~/.zshrc or ~/.bash_profile"
