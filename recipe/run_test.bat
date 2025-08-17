setlocal EnableDelayedExpansion

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

echo ### [SIRIUS] Simple Sirius help test
sirius.exe --help
if errorlevel 1 exit /b 1

REM Define variables
REM set "SUMMARY_DIR=%cd%\test-out"
REM ECHO "SUMMARY_DIR=%SUMMARY_DIR%"
REM set "SUMMARY_FILE=%SUMMARY_DIR%\formula_identifications.tsv"
REM ECHO "SUMMARY_FILE=%SUMMARY_FILE%"
REM set "EXPECTED_FORMULA=C15H10O6"
REM ECHO "EXPECTED_FORMULA=%EXPECTED_FORMULA%"
REM set "PROJECT=%SUMMARY_DIR%.sirius"
REM ECHO "PROJECT=%PROJECT%"

REM echo ### [SIRIUS] Run SIRIUS ILP solver Test
REM Adjust the path to Kaempferol.ms as needed:
REM sirius.exe -i "%RECIPE_DIR%\Kaempferol.ms" -o "%PROJECT%" sirius summaries
REM if errorlevel 1 exit /b 1

REM echo ### [SIRIUS] Check if SIRIUS project exists
REM if not exist "%PROJECT%" (
REM     echo Prject does not exist!
REM     exit /b 1
REM )

REM echo ### [SIRIUS] Check if SIRIUS summary directory exists and is not empty
REM if not exist "%SUMMARY_DIR%" (
REM     echo Directory with summaries does not exist or is empty!
REM     exit /b 1
REM )

REM Push into the directory and see if it has any files
REM pushd "%SUMMARY_DIR%" >nul 2>nul
REM dir /b 2>nul | findstr /r /c:"." >nul
REM if errorlevel 1 (
REM     popd
REM     echo Directory with summaries does not exist or is empty!
REM     exit /b 1
REM )
REM popd

REM echo ### [SIRIUS] Check if SIRIUS summary file exists
REM if not exist "%SUMMARY_FILE%" (
REM     echo Summary file does not exist!
REM     exit /b 1
REM )

REM echo ### [SIRIUS] Check if SIRIUS ILP solver has produced actual results
REM We parse the second line (skipping the header) and extract column #2 (molecularFormula).

REM set "formula="
REM for /f "skip=1 tokens=2 delims=	" %%A in ('type "%SUMMARY_FILE%"') do (
REM     set "formula=%%A"
REM     goto doneReading
REM )
REM :doneReading

REM if "%formula%" neq "%EXPECTED_FORMULA%" (
REM     echo The molecularFormula in the first data line is '%formula%', which does not match '%EXPECTED_FORMULA%'.
REM     exit /b 1
REM )
