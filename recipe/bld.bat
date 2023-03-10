setlocal EnableDelayedExpansion
SET packageName=%PKG_NAME%-%PKG_VERSION%-%PKG_BUILDNUM%
SET outdir=%PREFIX%/share/%packageName%

ECHO "### ENV INFO"
ECHO "PREFIX=%PREFIX%"
ECHO "CONDA_PREFIX=%CONDA_PREFIX%"
ECHO "LD_RUN_PATH=%LD_RUN_PATH%"
ECHO "ARCH = %ARCH%"
ECHO "OSX_ARCH = %OSX_ARCH%"
ECHO "build_platform = %build_platform%"
ECHO "target_platform = %target_platform%"
ECHO "JAVA_HOME=%JAVA_HOME%"
ECHO "packageName=%packageName%"
ECHO "outdir=%outdir%"
ECHO "siriusDistName=%sirius_gui_multi_os-sirius%"
ECHO "### ENV INFO END"

ECHO "### Show Build dir"
dir .\

ECHO "### Run gradle build"
call gradlew.bat :sirius_dist:sirius_gui_multi_os:installSiriusDist^
    -P "build.sirius.location.lib=..\share\%packageName%\lib"^
    -P "build.sirius.starter.jdk.include=false"^
    -P "build.sirius.native.openjfx.exclude=false"^
    -P "build.sirius.starter.jdk.location=../Library/lib/jvm"
if errorlevel 1 exit 1

ECHO "### Create package dirs"
if not exist "%outdir%" mkdir "%outdir%"
if errorlevel 1 exit 1

if not exist "%PREFIX%\bin" mkdir "%PREFIX%\bin"
if errorlevel 1 exit 1

ECHO "### Copy jars"
xcopy /e /k /h /i /q .\sirius_dist\sirius_gui_multi_os\build\install\%siriusDistName%\* "%outdir%\"
if errorlevel 1 exit 1

ECHO "### Remove bin"
rmdir /s /q "%outdir%\bin"
if errorlevel 1 exit 1

ECHO "### Show jar dir"
dir "%outdir%\lib"
if errorlevel 1 exit 1

ECHO "### Show bin dir source"
dir .\sirius_dist\sirius_gui_multi_os\build\install\%siriusDistName%\bin\
if errorlevel 1 exit 1

ECHO "### Copy starters"
xcopy /e /k /h /i /q .\sirius_dist\sirius_gui_multi_os\build\install\%siriusDistName%\bin\* "%PREFIX%\bin\"
if errorlevel 1 exit 1

ECHO "### Show bin dir target"
dir "%PREFIX%\bin"
if errorlevel 1 exit 1
