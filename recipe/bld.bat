setlocal EnableDelayedExpansion
SET packageName=%PKG_NAME%-%PKG_VERSION%-%PKG_BUILDNUM%
SET outdir=%PREFIX%/share/%packageName%

ECHO "### ENV INFO"
ECHO "PREFIX=%PREFIX%"
ECHO "BUILD_PREFIX=%BUILD_PREFIX%"
ECHO "CONDA_PREFIX=%CONDA_PREFIX%"
ECHO "LD_RUN_PATH=%LD_RUN_PATH%"
ECHO "ARCH = %ARCH%"
ECHO "OSX_ARCH = %OSX_ARCH%"
ECHO "build_platform = %build_platform%"
ECHO "target_platform = %target_platform%"
ECHO "JAVA_HOME=%JAVA_HOME%"
ECHO "packageName=%packageName%"
ECHO "outdir=%outdir%"
echo "siriusDistDir=%siriusDistDir%"
ECHO "siriusDistName=%siriusDistName%"
ECHO "### ENV INFO END"

ECHO "### Show Build dir"
dir .\
ECHO "### Show DIST dir"
dir .\dist\

ECHO "### Run gradle build"
call gradlew.bat :sirius_dist:sirius_gui_dist:installSiriusDist^
    -P "build.sirius.location.lib=..\share\%packageName%\app"^
    -P "build.sirius.starter.jdk.include=false"^
    -P "build.sirius.native.openjfx.exclude=false"^
    -P "build.sirius.starter.jdk.location=../Library/lib/jvm"^
    --stacktrace --warning-mode all
if errorlevel 1 exit 1

ECHO "### Create package dirs"
if not exist "%outdir%" mkdir "%outdir%"
if errorlevel 1 exit 1

if not exist "%PREFIX%\bin" mkdir "%PREFIX%\bin"
if errorlevel 1 exit 1

ECHO "### Copy jars"
xcopy /e /k /h /i /q .\sirius_dist\%siriusDistDir%\build\install\%siriusDistName%\* "%outdir%\"
if errorlevel 1 exit 1

ECHO "### Remove starters"
del /f "%outdir%\sirius.exe"
del /f "%outdir%\sirius-gui.exe"
del /f "%outdir%\sirius.bat"
if errorlevel 1 exit 1

ECHO "### Show jar dir"
dir "%outdir%\app"
if errorlevel 1 exit 1

ECHO "### Show bin dir source"
dir .\sirius_dist\%siriusDistDir%\build\install\%siriusDistName%\
if errorlevel 1 exit 1

ECHO "### Show bin dir target before"
dir "%PREFIX%\bin"
if errorlevel 1 exit 1

ECHO "### Copy starters"
xcopy /e /k /h /i /q .\sirius_dist\%siriusDistDir%\build\install\%siriusDistName%\sirius.exe "%PREFIX%\bin\"
xcopy /e /k /h /i /q .\sirius_dist\%siriusDistDir%\build\install\%siriusDistName%\sirius.bat "%PREFIX%\bin\"
xcopy /e /k /h /i /q .\sirius_dist\%siriusDistDir%\build\install\%siriusDistName%\sirius-gui.exe "%PREFIX%\bin\"
if errorlevel 1 exit 1

ECHO "### Show bin dir target after"
dir "%PREFIX%\bin"
if errorlevel 1 exit 1

ECHO "Copy Menu json..."
if not exist "%PREFIX%\Menu" mkdir "%PREFIX%\Menu"
copy "%RECIPE_DIR%\menu-windows.json" "%PREFIX%\Menu"
copy "%RECIPE_DIR%\sirius-icon.ico" "%PREFIX%\Menu"

ECHO "### Show menu dir after"
dir "%PREFIX%\Menu"
