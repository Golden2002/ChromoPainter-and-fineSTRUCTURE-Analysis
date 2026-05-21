#!/bin/bash
#SBATCH --job-name=CP_PAINT
#SBATCH --array=1-22
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --output=%J_paint_%a.out
#SBATCH --error=%J_paint_%a.err

# =============================================================================
# Stage 2: ChromoPainter Haplotype Painting
# =============================================================================
# Paints each haplotype onto all others using the Ne and mutation rate
# estimated from Stage 1 EM.
#
# Usage:
#   sbatch stage2_paint.sh
#
# Output:
#   chr{1-22}.chunkcounts.out - Haplotype painting counts per segment
#   chr{1-22}.chunklengths.out - Chunk length data
#
# Requirements: config.sh, Stage 1 outputs, global_ne.txt, ChromoPainter binary
# =============================================================================

set -euo pipefail

source config.sh

CHR=$SLURM_ARRAY_TASK_ID

OUT="${STAGE2_DIR}/chr${CHR}.chunkcounts.out"

# Skip if already complete
if [[ -s "$OUT" ]]; then
    echo "chr${CHR} already painted, skipping"
    exit 0
fi

# Read global Ne and mutation rate from file created by chromocombine step
NE=$(grep -oP '(?<=-n )\S+' "${STAGE1_DIR}/global_ne.txt")
MUT=$(grep -oP '(?<=-M )\S+' "${STAGE1_DIR}/global_ne.txt")

echo "chr${CHR} Painting with Ne=$NE, Mut=$MUT"

# Run ChromoPainter painting
# Flags:
#   -g: phase file
#   -r: recombination file
#   -k 50: number of expected chunks to define a 'region' (default=100)
#   -a 0 0: paint all individuals
#   -n: effective population size (from EM)
#   -M: mutation rate (from EM)
"$CP_BIN" \
    -g "$PHASE_DIR/chr${CHR}.phase" \
    -r "$RECOMB_DIR/chr${CHR}.recombfile" \
    -k 50 \
    -a 0 0 \
    -n "$NE" \
    -M "$MUT" \
    -o "$STAGE2_DIR/chr${CHR}" \
    > "$STAGE2_DIR/chr${CHR}.log" 2>&1

# Verify output was created
if [[ ! -s "$OUT" ]]; then
    echo "ERROR: $OUT empty, check log" >&2
    tail -20 "$STAGE2_DIR/chr${CHR}.log"
    exit 1
fi

echo "Finished chromosome ${CHR} painting"