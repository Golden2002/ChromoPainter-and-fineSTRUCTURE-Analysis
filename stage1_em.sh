#!/bin/bash
#SBATCH --job-name=CP_EM
#SBATCH --array=1-22
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --output=%J_em_%a.out
#SBATCH --error=%J_em_%a.err

# =============================================================================
# Stage 1: ChromoPainter EM Estimation
# =============================================================================
# Estimates mutation rate and effective population size (Ne) for each chromosome
# using the ChromoPainter EM algorithm.
#
# Usage:
#   sbatch stage1_em.sh
#
# Output:
#   chr{1-22}.EMprobs.out - EM parameter estimates per chromosome
#   global_ne.txt - Combined Ne and mutation rate (created by chromocombine step)
#
# Requirements: config.sh, ChromoPainter binary, phase files, recombination files
# =============================================================================

set -euo pipefail

# Load configuration
source config.sh

# Get chromosome from SLURM array task ID
CHR=$SLURM_ARRAY_TASK_ID

# Output file path
OUT="${STAGE1_DIR}/chr${CHR}.EMprobs.out"

# Skip if already complete
if [[ -f "$OUT" ]]; then
    echo "chr${CHR} already finished"
    exit 0
fi

echo "Running EM for chromosome ${CHR}"

# Run ChromoPainter EM phase
# Flags:
#   -g: phase file
#   -r: recombination file
#   -a 0 0: use all individuals
#   -i: number of EM iterations
#   -in -iM: initialize with mutation rate and Ne
"$CP_BIN" \
    -g "$PHASE_DIR/chr${CHR}.phase" \
    -r "$RECOMB_DIR/chr${CHR}.recombfile" \
    -a 0 0 \
    -i "$EM_ITERS" \
    -in -iM \
    -o "$STAGE1_DIR/chr${CHR}"

echo "Finished chromosome ${CHR} EM estimation"