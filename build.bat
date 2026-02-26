rem This file is licensed under the public domain.

@echo off

SETLOCAL EnableDelayedExpansion
if NOT DEFINED VSCMD_VER (
   echo error: this script must be run within the visual studio developer command prompt
   exit /b 1
)

where ninja >nul 2>nul
if %ERRORLEVEL% neq 0 (
   echo error: this script requires ninja to be installed, as the Visual Studio cmake generator doesn't support alternate compilers
   exit /b %ERRORLEVEL%
)

if "%1" == "" (set "TARGET=x86_64-windows-gnu") ELSE (set TARGET=%~1)
if "%2" == "" (set "MCPU=native") ELSE (set MCPU=%~2)
if "%VSCMD_ARG_HOST_ARCH%"=="x86" set HOST_TARGET=x86-windows-msvc
if "%VSCMD_ARG_HOST_ARCH%"=="x64" set HOST_TARGET=x86_64-windows-msvc
echo Boostrapping targeting %TARGET% (%MCPU%), using %HOST_TARGET% as the host compiler

set TARGET_ABI=
set TARGET_OS_CMAKE=
FOR /F "tokens=2,3 delims=-" %%i IN ("%TARGET%") DO (
  IF "%%i"=="macos" set "TARGET_OS_CMAKE=Darwin"
  IF "%%i"=="freebsd" set "TARGET_OS_CMAKE=FreeBSD"
  IF "%%i"=="netbsd" set "TARGET_OS_CMAKE=NetBSD"
  IF "%%i"=="openbsd" set "TARGET_OS_CMAKE=OpenBSD"
  IF "%%i"=="windows" set "TARGET_OS_CMAKE=Windows"
  IF "%%i"=="linux" set "TARGET_OS_CMAKE=Linux"
  set TARGET_ABI=%%j
)

set OUTDIR=out-win
if "%VSCMD_ARG_HOST_ARCH%"=="x86" set OUTDIR=out-win-x86

set ROOTDIR=%~dp0
set "ROOTDIR_CMAKE=%ROOTDIR:\=/%"
set ZIG_VERSION="0.16.0-dev.2287+eb3f16db5"
set JOBS_ARG=

pushd %ROOTDIR%

rem Build zlib for the host
@REM mkdir "%ROOTDIR%%OUTDIR%\build-zlib-host"
@REM cd "%ROOTDIR%%OUTDIR%\build-zlib-host"
@REM cmake "%ROOTDIR%/zlib" ^
@REM   -G "Ninja" ^
@REM   -DCMAKE_INSTALL_PREFIX="%ROOTDIR%/%OUTDIR%/host" ^
@REM   -DCMAKE_PREFIX_PATH="%ROOTDIR%/%OUTDIR%/host" ^
@REM   -DCMAKE_BUILD_TYPE=Release ^
@REM   -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded
@REM if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%
@REM 
@REM cmake --build . %JOBS_ARG% --target install
@REM if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

rem Build the libraries for Zig to link against, as well as native `llvm-tblgen` using msvc
mkdir "%ROOTDIR%%OUTDIR%\build-llvm-host"
cd "%ROOTDIR%%OUTDIR%\build-llvm-host"
cmake "%ROOTDIR%/llvm" ^
  -G "Ninja" ^
  -DCMAKE_INSTALL_PREFIX="%ROOTDIR%/%OUTDIR%/host" ^
  -DCMAKE_PREFIX_PATH="%ROOTDIR%/%OUTDIR%/host" ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
  -DLLVM_ENABLE_BINDINGS=OFF ^
  -DLLVM_ENABLE_LIBEDIT=OFF ^
  -DLLVM_ENABLE_LIBPFM=OFF ^
  -DLLVM_ENABLE_LIBXML2=OFF ^
  -DLLVM_ENABLE_OCAMLDOC=OFF ^
  -DLLVM_ENABLE_PLUGINS=OFF ^
  -DLLVM_ENABLE_PROJECTS="lld;clang" ^
  -DLLVM_ENABLE_Z3_SOLVER=OFF ^
  -DLLVM_ENABLE_ZSTD=OFF ^
  -DLLVM_INCLUDE_UTILS=OFF ^
  -DLLVM_INCLUDE_TESTS=OFF ^
  -DLLVM_INCLUDE_EXAMPLES=OFF ^
  -DLLVM_INCLUDE_BENCHMARKS=OFF ^
  -DLLVM_INCLUDE_DOCS=OFF ^
  -DLLVM_TOOL_LLVM_LTO2_BUILD=OFF ^
  -DLLVM_TOOL_LLVM_LTO_BUILD=OFF ^
  -DLLVM_TOOL_LTO_BUILD=OFF ^
  -DLLVM_TOOL_REMARKS_SHLIB_BUILD=OFF ^
  -DCLANG_BUILD_TOOLS=OFF ^
  -DCLANG_INCLUDE_DOCS=OFF ^
  -DCLANG_INCLUDE_TESTS=OFF ^
  -DCLANG_TOOL_CLANG_IMPORT_TEST_BUILD=OFF ^
  -DCLANG_TOOL_CLANG_LINKER_WRAPPER_BUILD=OFF ^
  -DCLANG_TOOL_C_INDEX_TEST_BUILD=OFF ^
  -DCLANG_TOOL_LIBCLANG_BUILD=OFF ^
  -DLLVM_BUILD_LLVM_C_DYLIB=NO
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%
cmake --build . %JOBS_ARG% --target install
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

@REM rem Build an x86_64-windows-msvc zig using msvc, linking against LLVM/Clang/LLD/zlib built by msvc
@REM mkdir "%ROOTDIR%%OUTDIR%\build-zig-host"
@REM cd "%ROOTDIR%%OUTDIR%\build-zig-host"
@REM cmake "%ROOTDIR%/zig" ^
@REM   -G "Ninja" ^
@REM   -DCMAKE_INSTALL_PREFIX="%ROOTDIR_CMAKE%%OUTDIR%/host" ^
@REM   -DCMAKE_PREFIX_PATH="%ROOTDIR_CMAKE%%OUTDIR%/host" ^
@REM   -DCMAKE_BUILD_TYPE=Release ^
@REM   -DZIG_STATIC=ON ^
@REM   -DZIG_STATIC_ZSTD=OFF ^
@REM   -DZIG_TARGET_TRIPLE="%HOST_TARGET%" ^
@REM   -DZIG_TARGET_MCPU=baseline
@REM 
@REM if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%
@REM cmake --build . %JOBS_ARG% --target install
@REM if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%
@REM 
@REM IF "%TARGET_ABI%"=="msvc" (
@REM    echo Building a target with the msvc ABI isn't supported yet
@REM    exit /b
@REM )
@REM 
@REM set ZIG=%ROOTDIR%%OUTDIR%\host\bin\zig.exe
@REM set "ZIG=%ZIG:\=/%"
@REM set "ZIG_LIB_DIR=%ROOTDIR%/zig/lib"
@REM 
@REM rem CMP0091=NEW is required in order for the CMAKE_MSVC_RUNTIME_LIBRARY value to be respected,
@REM rem which we need to be set to MultiThreaded when building msvc ABI targets
@REM 
@REM rem Cross compile zlib for the target
@REM mkdir "%ROOTDIR%%OUTDIR%\build-zlib-%TARGET%-%MCPU%"
@REM cd "%ROOTDIR%%OUTDIR%\build-zlib-%TARGET%-%MCPU%"
@REM cmake "%ROOTDIR%/zlib" ^
@REM   -G "Ninja" ^
@REM   -DCMAKE_INSTALL_PREFIX="%ROOTDIR_CMAKE%%OUTDIR%/%TARGET%-%MCPU%" ^
@REM   -DCMAKE_PREFIX_PATH="%ROOTDIR_CMAKE%%OUTDIR%/%TARGET%-%MCPU%" ^
@REM   -DCMAKE_BUILD_TYPE=Release ^
@REM   -DCMAKE_CROSSCOMPILING=True ^
@REM   -DCMAKE_SYSTEM_NAME="%TARGET_OS_CMAKE%" ^
@REM   -DCMAKE_C_COMPILER="%ZIG%;cc;-fno-sanitize=all;-fno-stack-protector;-s;-target;%TARGET%;-mcpu=%MCPU%" ^
@REM   -DCMAKE_CXX_COMPILER="%ZIG%;c++;-fno-sanitize=all;-fno-stack-protector;-s;-target;%TARGET%;-mcpu=%MCPU%" ^
@REM   -DCMAKE_ASM_COMPILER="%ZIG%;cc;-fno-sanitize=all;-fno-stack-protector;-s;-target;%TARGET%;-mcpu=%MCPU%" ^
@REM   -DCMAKE_RC_COMPILER="%ROOTDIR_CMAKE%%OUTDIR%/host/bin/llvm-rc.exe" ^
@REM   -DCMAKE_AR="%ROOTDIR_CMAKE%%OUTDIR%/host/bin/llvm-ar.exe" ^
@REM   -DCMAKE_RANLIB="%ROOTDIR_CMAKE%%OUTDIR%/host/bin/llvm-ranlib.exe" ^
@REM   -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
@REM   -DCMAKE_POLICY_DEFAULT_CMP0091=NEW
@REM cmake --build . %JOBS_ARG% --target install
@REM if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%
@REM 
@REM rem Cross compile zstd for the target
@REM mkdir "%ROOTDIR%%OUTDIR%\%TARGET%-%MCPU%\lib"
@REM copy "%ROOTDIR%\zstd\lib\zstd.h" "%ROOTDIR%%OUTDIR%\%TARGET%-%MCPU%\include\zstd.h"
@REM cd "%ROOTDIR%%OUTDIR%\%TARGET%-%MCPU%\lib"
@REM %ZIG% build-lib ^
@REM   --name zstd ^
@REM   -target %TARGET% ^
@REM   -mcpu=%MCPU% ^
@REM   -fno-sanitize-c ^
@REM   -fstrip ^
@REM   -OReleaseFast ^
@REM   -lc ^
@REM   "%ROOTDIR%\zstd\lib\decompress\zstd_ddict.c" ^
@REM   "%ROOTDIR%\zstd\lib\decompress\zstd_decompress.c" ^
@REM   "%ROOTDIR%\zstd\lib\decompress\huf_decompress.c" ^
@REM   "%ROOTDIR%\zstd\lib\decompress\huf_decompress_amd64.S" ^
@REM   "%ROOTDIR%\zstd\lib\decompress\zstd_decompress_block.c" ^
@REM   "%ROOTDIR%\zstd\lib\compress\zstdmt_compress.c" ^
@REM   "%ROOTDIR%\zstd\lib\compress\zstd_opt.c" ^
@REM   "%ROOTDIR%\zstd\lib\compress\hist.c" ^
@REM   "%ROOTDIR%\zstd\lib\compress\zstd_ldm.c" ^
@REM   "%ROOTDIR%\zstd\lib\compress\zstd_fast.c" ^
@REM   "%ROOTDIR%\zstd\lib\compress\zstd_compress_literals.c" ^
@REM   "%ROOTDIR%\zstd\lib\compress\zstd_double_fast.c" ^
@REM   "%ROOTDIR%\zstd\lib\compress\huf_compress.c" ^
@REM   "%ROOTDIR%\zstd\lib\compress\fse_compress.c" ^
@REM   "%ROOTDIR%\zstd\lib\compress\zstd_lazy.c" ^
@REM   "%ROOTDIR%\zstd\lib\compress\zstd_compress.c" ^
@REM   "%ROOTDIR%\zstd\lib\compress\zstd_compress_sequences.c" ^
@REM   "%ROOTDIR%\zstd\lib\compress\zstd_compress_superblock.c" ^
@REM   "%ROOTDIR%\zstd\lib\deprecated\zbuff_compress.c" ^
@REM   "%ROOTDIR%\zstd\lib\deprecated\zbuff_decompress.c" ^
@REM   "%ROOTDIR%\zstd\lib\deprecated\zbuff_common.c" ^
@REM   "%ROOTDIR%\zstd\lib\common\entropy_common.c" ^
@REM   "%ROOTDIR%\zstd\lib\common\pool.c" ^
@REM   "%ROOTDIR%\zstd\lib\common\threading.c" ^
@REM   "%ROOTDIR%\zstd\lib\common\zstd_common.c" ^
@REM   "%ROOTDIR%\zstd\lib\common\xxhash.c" ^
@REM   "%ROOTDIR%\zstd\lib\common\debug.c" ^
@REM   "%ROOTDIR%\zstd\lib\common\fse_decompress.c" ^
@REM   "%ROOTDIR%\zstd\lib\common\error_private.c" ^
@REM   "%ROOTDIR%\zstd\lib\dictBuilder\zdict.c" ^
@REM   "%ROOTDIR%\zstd\lib\dictBuilder\divsufsort.c" ^
@REM   "%ROOTDIR%\zstd\lib\dictBuilder\fastcover.c" ^
@REM   "%ROOTDIR%\zstd\lib\dictBuilder\cover.c"
@REM if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%
@REM 
@REM rem Ideally we could use ZLIB_USE_STATIC_LIBS here (which would detect zlib correctly),
@REM rem but this was added in 3.24 and the MSVC-bundled CMake is 3.20. Instead, for the msvc
@REM rem ABI the zlib path is specified explicitly.
@REM 
@REM IF "%TARGET_ABI%"=="msvc" (
@REM   set ZLIB_LIBRARY=-DZLIB_LIBRARY="%ROOTDIR_CMAKE%%OUTDIR%/%TARGET%-%MCPU%/lib/z.lib"
@REM ) else (
@REM   set ZLIB_LIBRARY=
@REM )
@REM rem Cross compile LLVM for the target
@REM mkdir "%ROOTDIR%%OUTDIR%\build-llvm-%TARGET%-%MCPU%"
@REM cd "%ROOTDIR%%OUTDIR%\build-llvm-%TARGET%-%MCPU%"
@REM cmake "%ROOTDIR%/llvm" ^
@REM   -G "Ninja" ^
@REM   -DCMAKE_INSTALL_PREFIX="%ROOTDIR_CMAKE%%OUTDIR%/%TARGET%-%MCPU%" ^
@REM   -DCMAKE_PREFIX_PATH="%ROOTDIR_CMAKE%%OUTDIR%/%TARGET%-%MCPU%" ^
@REM   -DCMAKE_BUILD_TYPE=Release ^
@REM   -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
@REM   -DCMAKE_CROSSCOMPILING=True ^
@REM   -DCMAKE_SYSTEM_NAME="%TARGET_OS_CMAKE%" ^
@REM   -DCMAKE_C_COMPILER="%ZIG%;cc;-fno-sanitize=all;-fno-stack-protector;-s;-target;%TARGET%;-mcpu=%MCPU%" ^
@REM   -DCMAKE_CXX_COMPILER="%ZIG%;c++;-fno-sanitize=all;-fno-stack-protector;-s;-target;%TARGET%;-mcpu=%MCPU%" ^
@REM   -DCMAKE_ASM_COMPILER="%ZIG%;cc;-fno-sanitize=all;-fno-stack-protector;-s;-target;%TARGET%;-mcpu=%MCPU%" ^
@REM   -DCMAKE_RC_COMPILER="%ROOTDIR_CMAKE%%OUTDIR%/host/bin/llvm-rc.exe" ^
@REM   -DCMAKE_AR="%ROOTDIR_CMAKE%%OUTDIR%/host/bin/llvm-ar.exe" ^
@REM   -DCMAKE_RANLIB="%ROOTDIR_CMAKE%%OUTDIR%/host/bin/llvm-ranlib.exe" ^
@REM   -DLLVM_ENABLE_BACKTRACES=OFF ^
@REM   -DLLVM_ENABLE_BINDINGS=OFF ^
@REM   -DLLVM_ENABLE_CRASH_OVERRIDES=OFF ^
@REM   -DLLVM_ENABLE_LIBEDIT=OFF ^
@REM   -DLLVM_ENABLE_LIBPFM=OFF ^
@REM   -DLLVM_ENABLE_LIBXML2=OFF ^
@REM   -DLLVM_ENABLE_OCAMLDOC=OFF ^
@REM   -DLLVM_ENABLE_PLUGINS=OFF ^
@REM   -DLLVM_ENABLE_PROJECTS="lld;clang" ^
@REM   -DLLVM_ENABLE_Z3_SOLVER=OFF ^
@REM   -DLLVM_ENABLE_ZLIB=FORCE_ON ^
@REM   -DLLVM_ENABLE_ZSTD=FORCE_ON ^
@REM   -DLLVM_USE_STATIC_ZSTD=ON ^
@REM   -DLLVM_TABLEGEN="%ROOTDIR_CMAKE%%OUTDIR%/host/bin/llvm-tblgen.exe" ^
@REM   -DLLVM_BUILD_TOOLS=OFF ^
@REM   -DLLVM_BUILD_STATIC=ON ^
@REM   -DLLVM_INCLUDE_UTILS=OFF ^
@REM   -DLLVM_INCLUDE_TESTS=OFF ^
@REM   -DLLVM_INCLUDE_EXAMPLES=OFF ^
@REM   -DLLVM_INCLUDE_BENCHMARKS=OFF ^
@REM   -DLLVM_INCLUDE_DOCS=OFF ^
@REM   -DLLVM_DEFAULT_TARGET_TRIPLE=%TARGET% ^
@REM   -DLLVM_TOOL_LLVM_LTO2_BUILD=OFF ^
@REM   -DLLVM_TOOL_LLVM_LTO_BUILD=OFF ^
@REM   -DLLVM_TOOL_LTO_BUILD=OFF ^
@REM   -DLLVM_TOOL_REMARKS_SHLIB_BUILD=OFF ^
@REM   -DCLANG_TABLEGEN="%ROOTDIR_CMAKE%%OUTDIR%/build-llvm-host/bin/clang-tblgen.exe" ^
@REM   -DCLANG_BUILD_TOOLS=OFF ^
@REM   -DCLANG_INCLUDE_DOCS=OFF ^
@REM   -DCLANG_INCLUDE_TESTS=OFF ^
@REM   -DCLANG_ENABLE_OBJC_REWRITER=ON ^
@REM   -DCLANG_TOOL_CLANG_IMPORT_TEST_BUILD=OFF ^
@REM   -DCLANG_TOOL_CLANG_LINKER_WRAPPER_BUILD=OFF ^
@REM   -DCLANG_TOOL_C_INDEX_TEST_BUILD=OFF ^
@REM   -DCLANG_TOOL_LIBCLANG_BUILD=OFF ^
@REM   %ZLIB_LIBRARY%
@REM if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%
@REM cmake --build . %JOBS_ARG% --target install
@REM if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%
@REM 
@REM rem Finally, we can cross compile Zig itself, with Zig.
@REM cd "%ROOTDIR%\zig"
@REM %ZIG% build ^
@REM   --prefix "%ROOTDIR%%OUTDIR%\zig-%TARGET%-%MCPU%" ^
@REM   --search-prefix "%ROOTDIR%%OUTDIR%\%TARGET%-%MCPU%" ^
@REM   -Dflat ^
@REM   -Dstatic-llvm ^
@REM   -Doptimize=ReleaseFast ^
@REM   -Dstrip ^
@REM   -Dtarget="%TARGET%" ^
@REM   -Dcpu="%MCPU%" ^
@REM   -Dversion-string="%ZIG_VERSION%"
@REM if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

popd
