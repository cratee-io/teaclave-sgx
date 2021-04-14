#!/bin/bash

set -e

workdir=$PWD
libDir=$workdir/library
teaclaveDir=$workdir/_teaclave

remote=https://hub.fastgit.org/lengyijun/incubator-teaclave-sgx-sdk.git
# take from the 1st input arg
rev=${1:-59e1b23354b2ca40c33d451a21dbedb6e28d47fd}

#rm -rf $teaclaveDir
#git clone $remote $teaclaveDir
#cd $teaclaveDir
#git checkout $rev
#cd -

rm -rf $libDir
mkdir $libDir

## official
crates=(
  alloc
  core
  rustc-std-workspace-alloc
  rustc-std-workspace-core
  rustc-std-workspace-std
  stdarch
  term
  test
)

sysrootDir=$(rustc --print sysroot)/lib/rustlib/src/rust/library
for v in ${crates[@]}; do
  echo "[CP] $sysrootDir/$v => $libDir/"
  rm -rf $libDir/$v
  cp -r $sysrootDir/$v $libDir/
done

### proc_macro is faked
cd $libDir
rm -rf proc_macro
cargo new --lib proc_macro
cd -

### remove unsupported std features for test
features=(
  panic-unwind
  panic_immediate_abort
  std_detect_file_io
  std_detect_dlsym_getauxval
)

for v in ${features[@]}; do
  sed -i "s/^$v = .*/$v = []/g" $libDir/test/Cargo.toml
done
## official DONE

## sgx_alloc
lib=sgx_alloc
outDir=$libDir/$lib
rm -rf $libDir/$lib
cp -r $teaclaveDir/$lib $outDir

cat >> $outDir/Cargo.toml <<EOF

[dependencies]
core  = { path = "../core" }
alloc = { path = "../alloc" }
compiler_builtins = { version = "0.1.0", features = ['rustc-dep-of-std'] }

EOF
## sgx_alloc DONE

## sgx_backtrace_sys
lib=sgx_backtrace_sys
outDir=$libDir/$lib
rm -rf $libDir/$lib
cp -r $teaclaveDir/$lib $outDir

sed -i '/\.dependencies/a\compiler_builtins = "0.1.39"' $outDir/Cargo.toml
sed -i '/\.dependencies/a\core = { path = "../core" }' $outDir/Cargo.toml
## sgx_backtrace_sys DONE

## sgx_build_helper
lib=sgx_build_helper
outDir=$libDir/$lib
rm -rf $libDir/$lib
cp -r $teaclaveDir/$lib $outDir
## sgx_build_helper DONE

## sgx_demangle
lib=sgx_demangle
outDir=$libDir/$lib
rm -rf $libDir/$lib
cp -r $teaclaveDir/$lib $outDir

cat >> $outDir/Cargo.toml <<EOF

[dependencies]
core  = { path = "../core" }
compiler_builtins = "0.1.39"
EOF
## sgx_demangle DONE

## sgx_libc
lib=sgx_libc
outDir=$libDir/$lib
rm -rf $libDir/$lib
cp -r $teaclaveDir/$lib $outDir

sed -i 's!^sgx_types = .*!sgx_types = { path = "../sgx_types", features = ["rsgx"] }!g' \
  $outDir/Cargo.toml
sed -i '/\.dependencies/a\alloc = { path = "../alloc" }' $outDir/Cargo.toml
sed -i '/\.dependencies/a\core = { path = "../core" }' $outDir/Cargo.toml
sed -i '/\.dependencies/a\compiler_builtins = "0.1.39"' $outDir/Cargo.toml
## sgx_libc DONE

## sgx_panic_abort
lib=panic_abort
outDir=$libDir/$lib
rm -rf $libDir/$lib
cp -r $teaclaveDir/sgx_$lib $outDir
## sgx_panic_abort DONE

## sgx_panic_unwind
lib=panic_unwind
outDir=$libDir/$lib
rm -rf $libDir/$lib
cp -r $teaclaveDir/sgx_$lib $outDir

sed -i '/\.dependencies/a\compiler_builtins = "0.1.39"' $outDir/Cargo.toml
sed -i '/\.dependencies/a\alloc = { path = "../alloc" }' $outDir/Cargo.toml
sed -i '/\.dependencies/a\core = { path = "../core" }' $outDir/Cargo.toml
## sgx_panic_unwind DONE

## sgx_tprotected_fs
lib=sgx_tprotected_fs
outDir=$libDir/$lib
rm -rf $libDir/$lib
cp -r $teaclaveDir/$lib $outDir

sed -i 's!^sgx_types = .*!sgx_types = { path = "../sgx_types", features = ["rsgx"] }!g' \
  $outDir/Cargo.toml
sed -i '/\.dependencies/a\compiler_builtins = "0.1.39"' $outDir/Cargo.toml
sed -i '/\.dependencies/a\core = { path = "../core" }' $outDir/Cargo.toml
## sgx_tprotected_fs DONE

## sgx_trts
lib=sgx_trts
outDir=$libDir/$lib
rm -rf $libDir/$lib
cp -r $teaclaveDir/$lib $outDir

sed -i 's!^sgx_types = .*!sgx_types = { path = "../sgx_types", features = ["rsgx"] }!g' \
  $outDir/Cargo.toml
sed -i '/\.dependencies/a\compiler_builtins = "0.1.39"' $outDir/Cargo.toml
sed -i '/\.dependencies/a\alloc = { path = "../alloc" }' $outDir/Cargo.toml
sed -i '/\.dependencies/a\core = { path = "../core" }' $outDir/Cargo.toml
## sgx_trts DONE

## sgx_tstd
lib=std
outDir=$libDir/$lib
rm -rf $libDir/$lib
cp -r $teaclaveDir/sgx_t$lib $outDir

sed -i 's/sgx_tstd/std/g' $outDir/Cargo.toml

sed -i '/\.dependencies/a\compiler_builtins = "0.1.39"' $outDir/Cargo.toml
sed -i '/\.dependencies/a\alloc = { path = "../alloc" }' $outDir/Cargo.toml
sed -i '/\.dependencies/a\core = { path = "../core" }' $outDir/Cargo.toml

sed -i 's!^sgx_types = .*!sgx_types = { path = "../sgx_types", features = ["rsgx"] }!g' \
  $outDir/Cargo.toml

### re-exporting
cat >> $outDir/src/lib.rs <<EOF

pub mod rsgx {
  pub use sgx_types as types;
}
EOF

### tackle the hashbrown part
sed -i '/^core = /d' $outDir/hashbrown/Cargo.toml
sed -i '/^compiler_builtins = /d' $outDir/hashbrown/Cargo.toml
sed -i '/^alloc = /d' $outDir/hashbrown/Cargo.toml

cat >> $outDir/hashbrown/Cargo.toml <<EOF

[dependencies]
core  = { path = "../../core", optional = true }
alloc = { version = "1.0.0", optional = true, package = "rustc-std-workspace-alloc" }
compiler_builtins = { version = "0.1.39", optional = true }
EOF
## sgx_tstd DONE

## sgx_types
lib=sgx_types
outDir=$libDir/$lib
rm -rf $libDir/$lib
cp -r $teaclaveDir/$lib $outDir

sed -i '/default = /a\rsgx = ["core", "compiler_builtins"]' $outDir/Cargo.toml
sed -i '/\[dependencies/a\compiler_builtins = { version = "0.1.39", optional = true }' \
  $outDir/Cargo.toml
sed -i '/\[dependencies/a\core = { path = "../core", optional = true }' $outDir/Cargo.toml
## sgx_types DONE

## sgx_unwind
lib=sgx_unwind
outDir=$libDir/$lib
rm -rf $libDir/$lib
cp -r $teaclaveDir/$lib $outDir

cat >> $outDir/.gitignore <<EOF
libunwind/autom4te.cache/*
libunwind/aclocal.m4
libunwind/config/*
libunwind/configure
libunwind/INSTALL
libunwind/Makefile.in
libunwind/src/Makefile.in
libunwind/include/config.h.in*
EOF

cat >> $outDir/Cargo.toml <<EOF

[dependencies]
core = { path = "../core" }
compiler_builtins = "0.1.39"
EOF
## sgx_unwind DONE

## sgx_urts
lib=sgx_urts
outDir=$workdir/usgx/$lib
rm -rf $outDir
cp -r $teaclaveDir/$lib $outDir

sed -i 's!^sgx_types.*!sgx_types = { path = "../../library/sgx_types" }!' $outDir/Cargo.toml
## sgx_urts DONE

## sgx_edl
lib=edl
outDir=$workdir/"$lib"s
rm -rf $outDir
cp -r $teaclaveDir/sgx_$lib $outDir

sed -i 's!sgx_edl!edls!g' $outDir/Cargo.toml
## sgx_edl DONE