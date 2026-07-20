#!/bin/sh
#
# SIRIUS conda package - post-link script (Linux / macOS)
#
# Best-effort Project Leyden AOT training on the *user's* machine at install time.
# We run the shipped `aot-train` tool through the SIRIUS launcher. The launcher already
# adds both `-Dspring.aot.enabled=true` and the `-XX:AOTCacheOutput=...` flag pointing at a
# per-build cache under `$HOME/.sirius-<major.minor>/aot/` (the launcher derives the exact file name
# from the build id + resolved JDK), so this records a warm AOT cache tailored to this exact
# environment and the user's first real launch is fast. Spring Boot AOT and the Leyden class cache
# are trained together.
#
# This MUST NEVER fail the installation: if anything goes wrong the launcher still generates the
# cache lazily on first launch.

# The Linux/macOS launcher embeds "$CONDA_PREFIX/share/.../app" in its classpath and falls back to
# `java` on PATH when no runtime is bundled (the conda build sets build.sirius.starter.jdk.include=false).
# Provide both so the launcher resolves the jars and the conda JDK.
CONDA_PREFIX="$PREFIX"
export CONDA_PREFIX
PATH="$PREFIX/bin:$PATH"
export PATH

LAUNCHER="$PREFIX/bin/sirius"
LOG="$PREFIX/.messages.txt"

{
    echo "SIRIUS: pre-generating the Project Leyden AOT cache for your environment (one-time, please wait)..."
    if [ ! -x "$LAUNCHER" ]; then
        echo "SIRIUS: launcher not found at '$LAUNCHER'; skipping AOT pre-training (it will be generated on first launch)."
    else
        # Bound the run so a stalled GUI/service init can never hang the install.
        if command -v timeout >/dev/null 2>&1; then
            timeout 300 "$LAUNCHER" aot-train >/dev/null 2>&1
            rc=$?
        else
            "$LAUNCHER" aot-train >/dev/null 2>&1
            rc=$?
        fi
        if [ "$rc" -eq 0 ]; then
            echo "SIRIUS: AOT cache generated successfully."
        else
            echo "SIRIUS: AOT pre-training exited with code $rc; the cache will be generated on first launch instead."
        fi
    fi
} >> "$LOG" 2>&1

# Never fail the installation.
exit 0
