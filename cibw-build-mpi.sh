#!/bin/bash
set -euo pipefail

mpiname="${MPINAME:-mpich}"
variant="${VARIANT:-}"

SOURCE=${SOURCE:-package/source}
WORKDIR=${WORKDIR:-package/workdir}
DESTDIR=${DESTDIR:-package/install}
PREFIX=${PREFIX:-"/opt/$mpiname"}

options=(
    CC=cc
    CXX=c++
    --prefix="$PREFIX"
    --with-device=ch4:"${variant:-ofi}"
    --with-pm=hydra:gforker
    --with-libfabric=embedded
    --with-ucx=embedded
    --with-hwloc=embedded
    --with-yaksa=embedded
    --disable-cxx
    --disable-static
)

if test "$(uname)" = Darwin; then
    export MPICH_MPICC_LDFLAGS="-Wl,-rpath,$PREFIX/lib"
    export MPICH_MPICXX_LDFLAGS="-Wl,-rpath,$PREFIX/lib"
    export MPICH_MPIFORT_LDFLAGS="-Wl,-rpath,$PREFIX/lib"
    export MACOSX_DEPLOYMENT_TARGET="11.0"
    if test "$(uname -m)" = x86_64; then
        export MACOSX_DEPLOYMENT_TARGET="10.9"
        export ac_cv_func_aligned_alloc="no" # macOS>=10.15
    fi
    if test "$variant" = ucx; then
        echo "ERROR: UCX is not supported on macOS"; exit 1;
    fi
fi

case $(uname) in
    Linux)  njobs=$(nproc);;
    Darwin) njobs=$(sysctl -n hw.physicalcpu);;
esac

mkdir -p "$WORKDIR" && cd "$WORKDIR"
echo running configure
"$SOURCE"/configure "${options[@]}" || cat config.log
echo disable manpages and documentation
sed -i.orig 's/^\(install-data-local:\).*/\1/' Makefile
echo running make with "${njobs:-1}" jobs
make -j "${njobs:-1}" install DESTDIR="$DESTDIR"

cd "${DESTDIR}${PREFIX}"
rm -f  include/*cxx.h
rm -f  include/*.mod
rm -f  include/*f.h
rm -f  bin/mpif77
rm -f  bin/mpif90
rm -f  bin/mpifort
rm -f  bin/parkill
rm -f  lib/libmpl.*
rm -f  lib/libopa.*
rm -f  lib/lib*mpi.a
rm -f  lib/lib*mpi.la
rm -f  lib/lib*mpich*.*
rm -f  lib/lib*mpicxx.*
rm -f  lib/lib*mpifort.*
rm -fr lib/pkgconfig
rm -fr share

cd "${DESTDIR}${PREFIX}"
rm -f  bin/io_demo
rm -f  bin/ucx_read_profile
rm -f  lib/libuc[mpst]*.la
rm -fr lib/cmake
rm -fr lib/ucx

cd "${DESTDIR}${PREFIX}/bin"
for script in mpicc mpicxx; do
    # shellcheck disable=SC2016
    topdir='$(CDPATH= cd -- "$(dirname -- "$0")/.." \&\& pwd -P)'
    sed -i.orig s:^prefix=.*:prefix="$topdir": $script
    sed -i.orig s:"$PREFIX":\"\$\{prefix\}\":g $script
    sed -i.orig s:-Wl,-commons,use_dylibs::g $script
    sed -i.orig s:/usr/bin/bash:/bin/bash:g $script
    rm $script.orig
done

if test "$(uname)" = Linux; then
    libmpi="libmpi.so.12"
    cd "${DESTDIR}${PREFIX}/bin"
    for exe in mpichversion mpivars; do
        patchelf --set-rpath "\$ORIGIN/../lib" $exe
    done
    cd "${DESTDIR}${PREFIX}/lib"
    if test -f "$libmpi".*.*; then
        rm "$libmpi" "${libmpi%.*}"
        mv "$libmpi".*.* "$libmpi"
        ln -s "$libmpi" "${libmpi%.*}"
    fi
    if test -f libucp.so; then
        patchelf --set-rpath "\$ORIGIN" "$libmpi"
        for lib in libuc[mpst]*.so.?; do
            patchelf --set-rpath "\$ORIGIN" "$lib"
        done
        for exe in mpichversion mpivars; do
            for lib in libuc[mpst].so.?; do
                patchelf --remove-needed "$lib" "../bin/$exe"
            done
        done
    fi
fi

if test "$(uname)" = Darwin; then
    libdir="$PREFIX/lib"
    libmpi="libmpi.12.dylib"
    libpmpi="libpmpi.12.dylib"
    cd "${DESTDIR}${PREFIX}/bin"
    for exe in mpichversion mpivars; do
        install_name_tool -change "$libdir/$libmpi" "@rpath/$libmpi" "$exe"
        install_name_tool -change "$libdir/$libpmpi" "@rpath/$libpmpi" "$exe"
        install_name_tool -add_rpath "@executable_path/../lib/" "$exe"
    done
    cd "${DESTDIR}${PREFIX}/lib"
    for lib in "$libmpi" "$libpmpi"; do
        install_name_tool -id "@rpath/$lib" "$lib"
        install_name_tool -add_rpath "@loader_path/" "$lib"
    done
    install_name_tool -change "$libdir/$libpmpi" "@rpath/$libpmpi" "$libmpi"
    if test -f libucp.dylib; then  # TODO: UCX is not supported on macOS
        for lib in libuc[mpst]*.?.dylib; do
            install_name_tool -id "@rpath/$lib" "$lib"
            install_name_tool -add_rpath "@loader_path/" "$lib"
            for dep in libuc[mst].?.dylib; do
                install_name_tool -change "$libdir/$dep" "@rpath/$dep" "$lib"
            done
        done
        for exe in mpichversion mpivars; do
            for dep in libuc[mpst].?.dylib; do
                install_name_tool -change "$libdir/$dep" "/" "../bin/$exe"
            done
        done
    fi
fi