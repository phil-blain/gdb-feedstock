#!/bin/bash

set -eu

# Download the right script to debug python processes
curl -SL https://raw.githubusercontent.com/python/cpython/$PY_VER/Tools/gdb/libpython.py \
    > "$SP_DIR/libpython.py"

# Install a gdbinit file that will be automatically loaded
mkdir -p "$PREFIX/etc"
echo '
python
import gdb
import sys
import os
def setup_python(event):
    import libpython
gdb.events.new_objfile.connect(setup_python)
end
' >> "$PREFIX/etc/gdbinit"

# macOS specificities
if [[ $target_platform == "osx-64" ]]; then
  # prevent a VERSION file being confused by clang++ with $CONDA_PREFIX/include/c++/v1/version
  mv intl/VERSION intl/VERSION.txt
  # install needed scripts to generate a codesigning certificate and sign the gdb executable
  cp $RECIPE_DIR/macos-codesign/macos-setup-codesign.sh $PREFIX/bin/
  cp $RECIPE_DIR/macos-codesign/macos-codesign-gdb.sh   $PREFIX/bin/
  # copy the entitlement file
  mkdir -p $PREFIX/etc/gdb
  cp $RECIPE_DIR/macos-codesign/gdb-entitlement.xml $PREFIX/etc/gdb/
  # add libiconv and expat flags
  libiconv_flag="--with-libiconv-prefix=$PREFIX"
  expat_flag="--with-libexpat-prefix=$PREFIX"
  # Setup the necessary GDB startup command for macOS Sierra and later
  echo "set startup-with-shell off" >> "$PREFIX/etc/gdbinit"
  # Copy the activate script to the installation prefix
  mkdir -p "${PREFIX}/etc/conda/activate.d"
  cp $RECIPE_DIR/activate.sh "${PREFIX}/etc/conda/activate.d/${PKG_NAME}_activate.sh"
fi

export CPPFLAGS="$CPPFLAGS -I$PREFIX/include"
# Setting /usr/lib/debug as debug dir makes it possible to debug the system's
# python on most Linux distributions
./configure \
    --prefix="$PREFIX" \
    --with-separate-debug-dir="$PREFIX/lib/debug:/usr/lib/debug" \
    --with-python \
    --with-system-gdbinit="$PREFIX/etc/gdbinit" \
    ${libiconv_flag:-} \
    ${expat_flag:-} \
    || (cat config.log && exit 1)
make -j${CPU_COUNT}
make install

