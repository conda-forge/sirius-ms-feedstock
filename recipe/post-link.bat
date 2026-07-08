@echo off
setlocal enableextensions

@rem SIRIUS conda package - post-link script (Windows)
@rem
@rem Best-effort Project Leyden AOT training on the user's machine at install time. We run the
@rem shipped `aot-train` tool through sirius.bat (the launcher that carries the Leyden AOT-cache
@rem logic AND -Dspring.aot.enabled=true), so Spring Boot AOT and the Leyden class cache are trained
@rem together into a per-build cache under %USERPROFILE%\.sirius-<major.minor>\aot\ (the launcher
@rem derives the exact file name from the build id + resolved JDK) for this exact environment.
@rem
@rem This MUST NEVER fail the installation: if anything goes wrong the launcher still generates the
@rem cache lazily on first launch.

set "LOG=%PREFIX%\.messages.txt"

>>"%LOG%" echo SIRIUS: pre-generating the Project Leyden AOT cache for your environment (one-time, please wait)...

@rem sirius.bat uses a relative "..\share\...\app" classpath, so it must run with CWD = %PREFIX%\bin.
@rem Also make the conda JDK discoverable (launcher falls back to %JAVA_HOME% / java.exe on PATH).
set "JAVA_HOME=%PREFIX%\Library"
set "PATH=%PREFIX%\Library\bin;%PREFIX%\bin;%PATH%"

if not exist "%PREFIX%\bin\sirius.bat" (
    >>"%LOG%" echo SIRIUS: launcher not found; skipping AOT pre-training (it will be generated on first launch).
    goto :done
)

pushd "%PREFIX%\bin"
call sirius.bat aot-train >nul 2>&1
set "RC=%ERRORLEVEL%"
popd

if "%RC%"=="0" (
    >>"%LOG%" echo SIRIUS: AOT cache generated successfully.
) else (
    >>"%LOG%" echo SIRIUS: AOT pre-training exited with code %RC%; the cache will be generated on first launch instead.
)

:done
@rem Never fail the installation.
endlocal
exit /b 0
