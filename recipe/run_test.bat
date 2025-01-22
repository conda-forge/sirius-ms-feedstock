setlocal EnableDelayedExpansion
REM Force Python’s default I/O encoding to UTF-8
set PYTHONIOENCODING=UTF-8
REM Also can do:
set PYTHONUTF8=1

ECHO "### Start TESTING"
ECHO "### [JAVA] Infos about JDK locations"
ECHO "JAVA_HOME = %JAVA_HOME%"
ECHO "JDK_HOME = %JDK_HOME%"
ECHO "ARCH = %ARCH%"
ECHO "OSX_ARCH = %OSX_ARCH%"

ECHO "### [JAVA] Try run java"
java -version

ECHO "### [JAVA] Try run %JAVA_HOME%"
%JAVA_HOME%/bin/java.exe -version

echo ### [SIRIUS] Simple Sirius version test
sirius.exe --version
if errorlevel 1 exit /b 1

REM Define variables
set "SUMMARY_DIR=%cd%\test-out"
ECHO "SUMMARY_DIR=%SUMMARY_DIR%"
set "SUMMARY_FILE=%SUMMARY_DIR%\formula_identifications.tsv"
ECHO "SUMMARY_FILE=%SUMMARY_FILE%"
set "EXPECTED_FORMULA=C15H10O6"
ECHO "EXPECTED_FORMULA=%EXPECTED_FORMULA%"
set "PROJECT=%SUMMARY_DIR%.sirius"
ECHO "PROJECT=%PROJECT%"

echo ### [SIRIUS] Run SIRIUS ILP solver Test
REM Adjust the path to Kaempferol.ms as needed:
sirius.exe -i "%RECIPE_DIR%\Kaempferol.ms" -o "%PROJECT%" sirius summaries
if errorlevel 1 exit /b 1

echo ### [SIRIUS] Check if SIRIUS project exists
if not exist "%PROJECT%" (
    echo Prject does not exist!
    exit /b 1
)

echo ### [SIRIUS] Check if SIRIUS summary directory exists and is not empty
if not exist "%SUMMARY_DIR%" (
    echo Directory with summaries does not exist or is empty!
    exit /b 1
)

REM Push into the directory and see if it has any files
pushd "%SUMMARY_DIR%" >nul 2>nul
dir /b 2>nul | findstr /r /c:"." >nul
if errorlevel 1 (
    popd
    echo Directory with summaries does not exist or is empty!
    exit /b 1
)
popd

echo ### [SIRIUS] Check if SIRIUS summary file exists
if not exist "%SUMMARY_FILE%" (
    echo Summary file does not exist!
    exit /b 1
)

echo ### [SIRIUS] Check if SIRIUS ILP solver has produced actual results
REM We parse the second line (skipping the header) and extract column #2 (molecularFormula).

set "formula="
for /f "skip=1 tokens=2 delims=	" %%A in ('type "%SUMMARY_FILE%"') do (
    set "formula=%%A"
    goto doneReading
)
:doneReading

if "%formula%" neq "%EXPECTED_FORMULA%" (
    echo The molecularFormula in the first data line is '%formula%', which does not match '%EXPECTED_FORMULA%'.
    exit /b 1
)
