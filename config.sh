#!/bin/bash
# =============================================================================
# config.sh - Configuration for ChromoPainter pipeline
# =============================================================================
# Edit the paths below to match your directory structure and binary locations.
#
# Usage: Source this file from other scripts:
#   source config.sh
# =============================================================================

# -----------------------------------------------------------------------------
# DIRECTORY STRUCTURE
# Adjust these to match where your data and results are located
# -----------------------------------------------------------------------------

# Base results directory
BASE="/path/to/your/chromopainter/results"

# Subdirectories (created automatically by pipeline scripts)
PHASE_DIR="${BASE}/chromopainter_phase"          # Phase input files (chr*.phase)
RECOMB_DIR="${BASE}/recombination_map_fixed"     # Recombination files (chr*.recombfile)
STAGE1_DIR="${BASE}/chromopainter_stage1"       # EM output (chr*.EMprobs.out)
STAGE2_DIR="${BASE}/chromopainter_stage2"       # Painting output (chr*.chunkcounts.out)
CC_DIR="${BASE}/chromocombine"                  # ChromoCombine output
FS_DIR="${BASE}/finestructure"                   # fineSTRUCTURE output

# -----------------------------------------------------------------------------
# BINARY PATHS
# Update these to point to your ChromoPainter installation
# -----------------------------------------------------------------------------

# ChromoPainter binaries (download from
# https://github.com/s Negben/Chromopainter/tree/master/chromopainter_v0.0.4)
CP_BIN="/path/to/your/chromopainter-0.0.4/chromopainter"
CC_BIN="/path/to/your/chromocombine-0.0.4/chromocombine"
FS_BIN="/path/to/your/finestructure-0.0.5/finestructure"

# -----------------------------------------------------------------------------
# PIPELINE PARAMETERS
# Adjust these based on your dataset size and analysis needs
# -----------------------------------------------------------------------------

# Number of EM iterations (default: 10)
EM_ITERS=10

# Number of painting samples per job (adjust based on memory)
# Default: 50 chunks defines a 'region' for ChromoPainter
PAINTING_CHUNK_SIZE=50