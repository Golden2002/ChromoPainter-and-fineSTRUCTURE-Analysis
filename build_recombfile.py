#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_recombfile.py - Build ChromoPainter recombination file from genetic map

This script interpolates genetic map positions (cM/Mb, Map(cM)) onto the
SNP positions found in a ChromoPainter phase file, outputting recombination
rates in Morgan/bp format required by ChromoPainter.

Usage:
    python3 build_recombfile.py --phase <phase_file> --map <genetic_map> --out <output>

Input:
    --phase: ChromoPainter phase file (with "P " header line containing positions)
    --map:   Genetic map file with columns: Chromosome Position(bp) Rate(cM/Mb) Map(cM)
    --out:   Output recombfile path

Output:
    ChromoPainter-format recombination file with columns:
        start.pos  recom.rate.perbp

Requirements: pandas, numpy, scipy
"""

import argparse
import pandas as pd
import numpy as np
from scipy.interpolate import interp1d

# =============================================================================
# Argument parsing
# =============================================================================

parser = argparse.ArgumentParser(
    description="Build ChromoPainter recombination file from genetic map"
)

parser.add_argument("--phase", required=True,
                    help="ChromoPainter phase file (contains SNP positions)")
parser.add_argument("--map", required=True,
                    help="Genetic map file (Chromosome Position(bp) Rate(cM/Mb) Map(cM))")
parser.add_argument("--out", required=True,
                    help="Output recombfile path")

args = parser.parse_args()

# =============================================================================
# Load phase file positions
# =============================================================================

positions = None

with open(args.phase) as f:
    for line in f:
        if line.startswith("P "):
            # Header line format: "P pos1 pos2 pos3 ..."
            positions = np.array(
                list(map(int, line.strip().split()[1:])),
                dtype=np.int64
            )
            break

if positions is None:
    raise RuntimeError("No position line found in phase file. "
                       "Expected a line starting with 'P ' followed by positions.")

print(f"[INFO] Loaded {len(positions)} SNP positions from phase file")

# =============================================================================
# Load genetic map
# =============================================================================

gm = pd.read_csv(
    args.map,
    sep=r"\s+",
    comment="#",
    engine="python"
)

# Validate expected columns
expected_cols = {
    "Chromosome",
    "Position(bp)",
    "Rate(cM/Mb)",
    "Map(cM)"
}

if not expected_cols.issubset(set(gm.columns)):
    raise RuntimeError(
        f"Genetic map columns incorrect.\n"
        f"Expected: {sorted(expected_cols)}\n"
        f"Found:    {sorted(gm.columns)}"
    )

# Keep only needed columns
gm = gm[[
    "Position(bp)",
    "Rate(cM/Mb)",
    "Map(cM)"
]].copy()

# Force numeric conversion
for col in gm.columns:
    gm[col] = pd.to_numeric(gm[col], errors="coerce")

# Remove invalid rows
gm = gm.dropna()

# Sort by position
gm = gm.sort_values("Position(bp)")

# Deduplicate
gm = gm.drop_duplicates(subset="Position(bp)")

# Convert to numpy arrays
bp = gm["Position(bp)"].to_numpy(dtype=np.float64)
rate = gm["Rate(cM/Mb)"].to_numpy(dtype=np.float64)
cm = gm["Map(cM)"].to_numpy(dtype=np.float64)

print(f"[INFO] Loaded {len(bp)} map positions from genetic map")

# =============================================================================
# Interpolation
# =============================================================================

interp_cm = interp1d(
    bp,
    cm,
    kind="linear",
    bounds_error=False,
    fill_value="extrapolate"
)

interp_rate = interp1d(
    bp,
    rate,
    kind="linear",
    bounds_error=False,
    fill_value="extrapolate"
)

cm_values = interp_cm(positions)
rate_values = interp_rate(positions)

# =============================================================================
# Unit conversion: cM/Mb -> Morgan/bp
# =============================================================================
# ChromoPainter requires Morgan/bp format:
#   1 cM/Mb = 0.01 Morgan / 1,000,000 bp = 1e-8 Morgan/bp

rate_values = rate_values * 1e-8

# Fix negative values (can occur at map edges due to extrapolation)
rate_values[rate_values < 0] = 0

# =============================================================================
# Write recombfile
# =============================================================================

with open(args.out, "w") as out:
    out.write("start.pos recom.rate.perbp\n")

    for pos, rate in zip(positions, rate_values):
        out.write(
            f"{int(pos)} {rate:.10e}\n"
        )

print(f"[INFO] Written: {args.out}")