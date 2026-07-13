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
@rem
@rem NOTE: do NOT use parenthesized ( ... ) command blocks here. cmd.exe mis-parses literal
@rem parentheses that appear in echo text inside such a block and aborts the whole script with
@rem ". was unexpected at this time." (return code 255), which would fail the conda install. We use
@rem goto-based flow so the log messages can contain arbitrary punctuation safely.

set "LOG=%PREFIX%\.messages.txt"

>>"%LOG%" echo SIRIUS: pre-generating the Project Leyden AOT cache for your environment. This is a one-time step, please wait...

@rem sirius.bat uses a relative "..\share\...\app" classpath, so it must run with CWD = %PREFIX%\bin.
@rem Also make the conda JDK discoverable (launcher falls back to %JAVA_HOME% / java.exe on PATH).
set "JAVA_HOME=%PREFIX%\Library"
set "PATH=%PREFIX%\Library\bin;%PREFIX%\bin;%PATH%"

if not exist "%PREFIX%\bin\sirius.bat" goto :nolauncher

pushd "%PREFIX%\bin"
call sirius.bat aot-train >nul 2>&1
set "RC=%ERRORLEVEL%"
popd

if "%RC%"=="0" goto :ok
>>"%LOG%" echo SIRIUS: AOT pre-training exited with code %RC%; the cache will be generated on first launch instead.
goto :done

:ok
>>"%LOG%" echo SIRIUS: AOT cache generated successfully.
goto :done

:nolauncher
>>"%LOG%" echo SIRIUS: launcher not found; skipping AOT pre-training. It will be generated on first launch.

:done
@rem Never fail the installation.
endlocal
exit /b 0
