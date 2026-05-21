#!/bin/bash
# =============================================================================
# Build All Recombination Files
# =============================================================================
# Generates ChromoPainter recombination files for chromosomes 1-22 by
# interpolating genetic map positions onto phase file SNP positions.
#
# Usage:
#   chmod +x build_all_recomb.sh
#   ./build_all_recomb.sh
#
# Requirements: Python 3 with pandas, numpy, scipy
#               Genetic map files: genetic_map_GRCh38_chr{N}.txt
#               Phase files: chr{N}.phase (ChromoPainter format)
#
# Output: *.recombfile (Morgan/bp format for ChromoPainter)
# =============================================================================

# CONFIGURATION - MODIFY THESE TO MATCH YOUR SETUP
PHASE_DIR="/path/to/your/chromopainter_phase"   # Directory containing chr*.phase files
MAP_DIR="/path/to/your/genetic_maps"             # Directory containing genetic_map_GRCh38_chr*.txt
OUT_DIR="/path/to/your/recombination_output"     # Output directory for *.recombfile

# Path to the build_recombfile.py script (in same directory)
BUILD_RECOMB_FILE="$(dirname "$0")/build_recombfile.py"

# =============================================================================
# MAIN PROCESSING
# =============================================================================

echo "Building recombination files..."
echo "Phase dir: ${PHASE_DIR}"
echo "Map dir:   ${MAP_DIR}"
echo "Output:    ${OUT_DIR}"

mkdir -p "${OUT_DIR}"

# Process chromosomes 1-22
for chr in {1..22}; do
    echo "Processing chromosome ${chr}..."

    python3 "${BUILD_RECOMB_FILE}" \
        --phase "${PHASE_DIR}/chr${chr}.phase" \
        --map   "${MAP_DIR}/genetic_map_GRCh38_chr${chr}.txt" \
        --out   "${OUT_DIR}/chr${chr}.recombfile"

    if [[ $? -eq 0 ]]; then
        echo "  chr${chr} done"
    else
        echo "  chr${chr} FAILED"
        exit 1
    fi
done

echo "All recombination files built successfully!"