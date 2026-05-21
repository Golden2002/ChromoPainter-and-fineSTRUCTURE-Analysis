#!/bin/bash
#SBATCH --job-name=chromocombine
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --output=%J_chromocombine.out
#SBATCH --error=%J_chromocombine.err

# =============================================================================
# After Stage1: Combine EM outputs and extract global Ne and mutation rate
# =============================================================================
# This script combines per-chromosome EM outputs from Stage 1 and extracts
# the global Ne and mutation rate needed for Stage 2 painting.
#
# Usage:
#   sbatch after_stage1_before_stage2_chromocombine.sh
#
# Output:
#   global_ne.txt - Contains Ne (-n) and mutation rate (-M) for painting step
#
# Requirements: config.sh, ChromoCombine binary, Stage 1 EM outputs
# =============================================================================

set -euo pipefail

source config.sh

# Create output directory
mkdir -p "${CC_DIR}"

echo "Running ChromoCombine to merge per-chromosome EM outputs"

# Run ChromoCombine to merge EM outputs across chromosomes
# The -d flag indicates input is per-chromosome directory
"$CC_BIN" \
    -o "${CC_DIR}/combined" \
    -d \
    "${STAGE1_DIR}"

echo "Extracting global Ne and mutation rate from combined output"

# Extract Ne and mutation rate from combined EM output
# These values are needed for the painting step (Stage 2)
COMBINED_EM="${CC_DIR}/combined.EMprobs.out"

if [[ -f "$COMBINED_EM" ]]; then
    # Extract Ne (effective population size) and mutation rate from final line
    NE=$(tail -1 "$COMBINED_EM" | awk '{print $(NF-1)}')
    MUT=$(tail -1 "$COMBINED_EM" | awk '{print $NF}')

    # Write to global_ne.txt for use in Stage 2
    echo "-n $NE -M $MUT" > "${STAGE1_DIR}/global_ne.txt"

    echo "global_ne.txt written: Ne=$NE, Mut=$MUT"
else
    echo "ERROR: Combined EM output not found: $COMBINED_EM"
    exit 1
fi

echo "Stage 1 complete. Ready to run Stage 2 painting."