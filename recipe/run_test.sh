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


echo "### [SIRIUS] Simple Sirius version test"
sirius --version

SUMMARY_DIR="test-out"
SUMMARY_FILE="test-out/formula_identifications.tsv"
EXPECTED_FORMULA="C15H10O6"
PROJECT="$SUMMARY_DIR.sirius"

echo "### [SIRIUS] Run SIRIUS ILP solver Test"
sirius -i "$RECIPE_DIR"/Kaempferol.ms -o $PROJECT sirius summaries

echo "### [SIRIUS] Check if SIRIUS project exists"
if [ ! -f "$PROJECT" ]; then
  echo Framgentation tree test failed!
  exit 1
fi


echo "### [SIRIUS] Check if SIRIUS summary file exists"
if [ ! -d "$SUMMARY_DIR" ] || [ -z "$(ls -A $SUMMARY_DIR 2>/dev/null)" ]; then
  echo "Directory with summaries does not exists or is empty!"
  exit 1
fi

if [ ! -f "$SUMMARY_FILE" ]; then
  echo "Summary file does not exist!"
  exit 1
fi

echo "### [SIRIUS] Check if SIRIUS ILP solver has produced actual results"
# Extract line 2, then cut out column 2 by TAB
# NR==2 means “When you get to line #2, print it, then stop/exit.”
# The -F '\t' sets field delimiter to TAB.
line=$(awk -F '\t' 'NR==2 {print; exit}' "$SUMMARY_FILE")

# Extract the second column using cut (tab-delimited by default)
formula=$(echo "$line" | cut -f2)

if [ "$formula" != "$EXPECTED_FORMULA" ]; then
    echo "The molecularFormula in the first data line is '$formula', which does not match '$EXPECTED_FORMULA'."
    exit 1
fi
