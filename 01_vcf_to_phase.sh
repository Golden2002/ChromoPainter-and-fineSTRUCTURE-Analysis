#!/bin/bash
#SBATCH --job-name=VCF_to_ChromoPainter
#SBATCH --output=%J_vcf2phase.log
#SBATCH --error=%J_vcf2phase_err.log
#SBATCH --ntasks=1
#SBATCH --partition=batch
#SBATCH --mem=
#SBATCH --array=0-21

# =============================================================================
# VCF to ChromoPainter Phase Format Converter
# =============================================================================
# Converts VCF files to ChromoPainter phase format for haplotype-based analysis.
#
# Usage:
#   1. Customize the configuration variables below (INPUT_DIR, OUTPUT_DIR, etc.)
#   2. Ensure REF_FASTA and CHROM_LIST are correctly set
#   3. Submit to SLURM: sbatch this_script.sh
#
# Input: VCF files named as {sample}.vcf(.gz) in INPUT_DIR
# Output: ChromoPainter phase files in OUTPUT_DIR/chr{N}.phase
#
# Requirements: bcftools, bgzip/tabix, GNU parallel
# =============================================================================

# -----------------------------------------------------------------------------
# CONFIGURATION - MODIFY THESE FOR YOUR SYSTEM
# -----------------------------------------------------------------------------

# Input/Output directories - CHANGE THESE TO MATCH YOUR SETUP
INPUT_DIR="/path/to/your/vcf/files"
OUTPUT_DIR="/path/to/chromopainter/phase_output"

# Reference genome (for liftOver if needed; set to "" if not used)
REF_FASTA="/path/to/your/reference/genome.fa"

# Chromosomes to process (space-separated list)
CHROM_LIST="1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22"

# Phasing tool: "shapeit4" or "beagle5" (must be installed)
PHASING_TOOL="shapeit4"

# Number of threads for parallel processing
N_THREADS=4

# -----------------------------------------------------------------------------
# DERIVED PATHS - USUALLY NO NEED TO MODIFY
# -----------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/log"

# Create output directories
mkdir -p "${OUTPUT_DIR}"
mkdir -p "${LOG_DIR}"

# -----------------------------------------------------------------------------
# MAIN PROCESSING LOGIC
# -----------------------------------------------------------------------------

# Get current chromosome from array task ID
CHR_IDX=$((SLURM_ARRAY_TASK_ID))
CHR=$(echo $CHROM_LIST | cut -d' ' -f$((CHR_IDX+1)))

echo "[$(date)] Processing chromosome ${CHR}"

# Check if output already exists (skip if complete)
if [[ -f "${OUTPUT_DIR}/chr${CHR}.phase" ]]; then
    echo "chr${CHR}.phase already exists, skipping"
    exit 0
fi

# Find all VCF files for this chromosome
VCF_FILES=($(ls ${INPUT_DIR}/*.vcf.gz 2>/dev/null | head -100))  # limit to 100 samples

if [[ ${#VCF_FILES[@]} -eq 0 ]]; then
    echo "No VCF files found in ${INPUT_DIR}"
    exit 1
fi

echo "Found ${#VCF_FILES[@]} VCF files"

# -----------------------------------------------------------------------------
# Per-chromosome VCF extraction and format conversion
# -----------------------------------------------------------------------------
# This block shows the conversion logic; adapt to your specific VCF structure

for vcf_file in "${VCF_FILES[@]}"; do
    sample_name=$(basename "${vcf_file}" .vcf.gz)

    # Step 1: Extract chromosome and normalize
    bcftools view -r ${CHR} -O z -o "${OUTPUT_DIR}/${sample_name}.chr${CHR}.vcf.gz" "${vcf_file}"

    # Step 2: Phase if needed (example for shapeit4)
    if [[ "${PHASING_TOOL}" == "shapeit4" ]]; then
        shapeit4 --input "${OUTPUT_DIR}/${sample_name}.chr${CHR}.vcf.gz" \
                 --output "${OUTPUT_DIR}/${sample_name}.chr${CHR}.phased.vcf.gz" \
                 --thread ${N_THREADS}
    fi

    # Step 3: Convert to ChromoPainter phase format
    # The phase format has: header line "P pos1 pos2 pos3 ..."
    # followed by two haplotype lines per sample (AA AB BB pattern)
    # This is typically custom per analysis - insert your conversion code here

done

# -----------------------------------------------------------------------------
# Merge samples into single phase file for this chromosome
# -----------------------------------------------------------------------------
# Example merge logic (adapt to your sample naming scheme):
# cat "${OUTPUT_DIR}"/*.chr${CHR}.phase > "${OUTPUT_DIR}/chr${CHR}.phase"

echo "[$(date)] Finished chromosome ${CHR}"