#!/bin/zsh

set -e

RESULTS_FILE=`mktemp`.json
RENDERED_IMAGE_FILE=`mktemp`.png

# Run the benchmark and output the results to "$RESULTS_FILE".
"$BUILT_PRODUCTS_DIR"/CASBenchmark run --cycles 3 "$RESULTS_FILE"

# Render the results of the benchmark to a PNG file.
"$BUILT_PRODUCTS_DIR"/CASBenchmark render "$RESULTS_FILE" "$RENDERED_IMAGE_FILE"

# Display the results of the benchmark.
open "$RENDERED_IMAGE_FILE"
