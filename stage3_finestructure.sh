#!/bin/bash
#SBATCH --job-name=CP_FS
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --output=%J_fs.out
#SBATCH --error=%J_fs.err

# =============================================================================
# Stage 3: ChromoCombine + fineSTRUCTURE Analysis
# =============================================================================
# Combines per-chromosome painting results and runs fineSTRUCTURE MCMC
# to produce population structure tree.
#
# Usage:
#   sbatch stage3_finestructure.sh
#
# Output:
#   chromocombine/: merged chunkcounts and chunklengths
#   finestructure/:  MCMC chain, maxstate tree, phylogenetic tree (XML format)
#
# Requirements: config.sh, ChromoCombine and fineSTRUCTURE binaries, Stage 2 outputs
# =============================================================================

set -euo pipefail

source config.sh

# Create output directories
mkdir -p "${CC_DIR}"
mkdir -p "${FS_DIR}"

echo "Running ChromoCombine to merge per-chromosome painting results"

# Run ChromoCombine to merge per-chromosome outputs into single files
# -o: output prefix
# -d: input is directory (per-chromosome files)
"$CC_BIN" \
    -o "${CC_DIR}/merged" \
    -d \
    "${STAGE2_DIR}"

COUNTS="${CC_DIR}/merged.chunkcounts.out"
LENGTHS="${CC_DIR}/merged.chunklengths.out"

echo "Running fineSTRUCTURE MCMC (this may take hours)"

# Run fineSTRUCTURE MCMC phase
# Flags:
#   -X -Y: standard flags
#   -m oMCMC: using optimized MCMC mode
#   -x -y: burn-in iterations (200,000)
#   -z: thinning interval (1,000)
#   -l: chunklengths file
"$FS_BIN" \
    -X -Y \
    -m oMCMC \
    -x 200000 \
    -y 200000 \
    -z 1000 \
    -l "$LENGTHS" \
    "$COUNTS" \
    "${FS_DIR}/merged.mcmc.xml"

echo "Extracting maximum state tree"

# Extract tree with maximum state (most likely population structure)
"$FS_BIN" \
    -X -Y \
    -e maxstate \
    "$COUNTS" \
    "${FS_DIR}/merged.mcmc.xml" \
    "${FS_DIR}/merged.maxstate.xml"

echo "Building phylogenetic tree"

# Build final tree in Newick format
"$FS_BIN" \
    -X -Y \
    -m Tree \
    "$COUNTS" \
    "${FS_DIR}/merged.maxstate.xml" \
    "${FS_DIR}/merged.tree.xml"

echo "fineSTRUCTURE analysis complete"
echo "Results in: ${FS_DIR}/"