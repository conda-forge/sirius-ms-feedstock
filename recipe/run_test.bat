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

echo ### [SIRIUS] Executing Sirius self-test
sirius.exe selftest
if errorlevel 1 exit /b 1

echo ### [SIRIUS] Tests SUCCESSFUL!
