#!/bin/sh

echo "### TEST ENV INFO"
echo "PREFIX=$PREFIX"
echo "CONDA_PREFIX=$CONDA_PREFIX"
echo "LD_RUN_PATH=$LD_RUN_PATH"
echo "JAVA_HOME = $JAVA_HOME"
echo "JDK_HOME = $JDK_HOME"
echo "ARCH = $ARCH"
echo "OSX_ARCH = $OSX_ARCH"
echo "### TEST ENV INFO END"


echo "### [JAVA] Try run java"
java -version


echo "### [JAVA] Try run $JAVA_HOME"
"$JAVA_HOME/bin/java" -version


echo "### [SIRIUS] Simple Sirius help test"
sirius --help

echo "### [SIRIUS] Sirius self-test"
sirius selftest

echo "### [SIRIUS] Tests SUCCESSFUL!"