# ChromoPainter Pipeline Scripts

A sanitized, ready-to-use collection of scripts for running the ChromoPainter
haplotype-sharing analysis pipeline. Designed for population genetics research
using chromosome-level haplotype data.

---

## Table of Contents

1. [Overview](#overview)
2. [Pipeline Flowchart](#pipeline-flowchart)
3. [Prerequisites](#prerequisites)
4. [Installation](#installation)
5. [Configuration](#configuration)
6. [Usage](#usage)
7. [Input/Output Formats](#inputoutput-formats)
8. [Troubleshooting](#troubleshooting)
9. [Citation](#citation)

---

## Overview

**ChromoPainter** (Lawson et al., 2012) estimates haplotype sharing between
individuals to infer population structure without requiring prior population
labels. This pipeline automates the three-stage ChromoPainter workflow:

| Stage | Script | Purpose |
|-------|--------|---------|
| **0** | `01_vcf_to_phase.sh` | Convert VCF files to ChromoPainter phase format |
| **1** | `stage1_em.sh` + `after_stage1_before_stage2_chromocombine.sh` | Estimate mutation rate and Ne via EM |
| **2** | `stage2_paint.sh` | Paint each haplotype onto all others |
| **3** | `stage3_finestructure.sh` | Merge results and run fineSTRUCTURE |

The pipeline is designed for **SLURM HPC environments** but can be adapted
for other job schedulers or standalone execution.

---

## Pipeline Flowchart

```
VCF files
    │
    ▼
[Stage 0] 01_vcf_to_phase.sh
    │        (per chromosome, array job)
    ▼
Phase files (chr*.phase)
    │
    ▼
[Stage 1a] build_all_recomb.sh + build_recombfile.py
    │        (genetic map → recombfile)
    ▼
Recombination files (chr*.recombfile)
    │
    ├────────────────────────────────┐
    ▼                                ▼
[Stage 1b] stage1_em.sh         [Stage 2] stage2_paint.sh
    │        (EM per chr)              │        (painting per chr)
    ▼                                │
EM outputs (chr*.EMprobs.out)        │
    │                                │
    ▼                                │
[Chromocombine] after_stage1_before_stage2_chromocombine.sh
    │        (combine EM outputs, extract global Ne)
    ▼
global_ne.txt ────────────────────────────►
    │
    ▼
[Stage 3] stage3_finestructure.sh
    │        (chromocombine + fineSTRUCTURE MCMC)
    ▼
fineSTRUCTURE outputs (*.mcmc.xml, *.tree.xml)
```

---

## Prerequisites

### Software Requirements

| Software | Version | Purpose |
|----------|---------|---------|
| **ChromoPainter** | v0.0.4+ | Haplotype painting |
| **Chromocombine** | v0.0.4+ | Merging per-chromosome outputs |
| **fineSTRUCTURE** | v0.0.5+ | Population structure analysis |
| **Python** | 3.8+ | build_recombfile.py |
| **pandas** | latest | Data handling |
| **numpy** | latest | Numerical operations |
| **scipy** | latest | Interpolation for genetic maps |
| **bcftools** | 1.9+ | VCF manipulation (Stage 0) |
| **AWK** | any | convert_map.awk |

### Data Requirements

1. **Phase files** in ChromoPainter format:
   - Header line: `P pos1 pos2 pos3 ...`
   - Two lines per sample: haplotype alleles (0/1 or A/C/G/T)

2. **Genetic map files** (one per chromosome):
   - Format: `Chromosome Position(bp) Rate(cM/Mb) Map(cM)`
   - Tab or space-separated
   - Example source: [LGM Genetic Map](https:///science.sciencemag.org/content/343/6170/747)

3. **Reference genome** (FASTA) if using liftOver or coordinate conversion

---

## Installation

### 1. Clone or download this repository

```bash
git clone https://github.com/yourusername/chromopainter-pipeline.git
cd chromopainter-pipeline
```

### 2. Install Python dependencies

```bash
pip install numpy pandas scipy
```

### 3. Download ChromoPainter binaries

Download from the official repository and extract:

```bash
# Create installation directory
mkdir -p /path/to/tools
cd /path/to/tools

# Download (replace with actual download links)
wget https://github.com/yourrepo/chromopainter-0.0.4.tgz
tar -xzf chromopainter-0.0.4.tgz

# Same for chromocombine and finestructure
wget https://github.com/yourrepo/chromocombine-0.0.4.tgz
tar -xzf chromocombine-0.0.4.tgz

wget https://github.com/yourrepo/finestructure-0.0.5.tgz
tar -xzf finestructure-0.0.5.tgz
```

### 4. Make scripts executable

```bash
chmod +x build_all_recomb.sh stage1_em.sh stage2_paint.sh stage3_finestructure.sh
chmod +x after_stage1_before_stage2_chromocombine.sh 01_vcf_to_phase.sh
chmod +x convert_map.awk
```

---

## Configuration

### Edit `config.sh`

This is the **only file you need to modify** to adapt the pipeline to your system.

```bash
# ============================================================================
# DIRECTORY STRUCTURE - Set these to match your data locations
# ============================================================================

# Base results directory (all pipeline output goes here)
BASE="/path/to/your/results"

# Input: phase files from your samples
PHASE_DIR="${BASE}/chromopainter_phase"

# Input: recombination files (from genetic map)
RECOMB_DIR="${BASE}/recombination_map_fixed"

# Output directories
STAGE1_DIR="${BASE}/chromopainter_stage1"   # EM results
STAGE2_DIR="${BASE}/chromopainter_stage2"     # Painting results
CC_DIR="${BASE}/chromocombine"                # ChromoCombine results
FS_DIR="${BASE}/finestructure"                 # fineSTRUCTURE results

# ============================================================================
# BINARY PATHS - Point to your ChromoPainter installation
# ============================================================================

CP_BIN="/path/to/tools/chromopainter-0.0.4/chromopainter"
CC_BIN="/path/to/tools/chromocombine-0.0.4/chromocombine"
FS_BIN="/path/to/tools/finestructure-0.0.5/finestructure"

# ============================================================================
# PARAMETERS - Adjust based on your analysis needs
# ============================================================================

EM_ITERS=10              # EM iterations (default: 10)
PAINTING_CHUNK_SIZE=50   # Chunk size for painting
```

---

## Usage

### Step 0: (Optional) Convert VCF to Phase format

If your data is in VCF format, use Stage 0 to convert to ChromoPainter phase format:

```bash
# Edit paths in 01_vcf_to_phase.sh first
sbatch 01_vcf_to_phase.sh
```

### Step 1: Build Recombination Files

Generate recombination maps from genetic maps:

```bash
# Ensure build_recombfile.py and genetic maps are in place
./build_all_recomb.sh
```

### Step 2: Stage 1 - EM Estimation

Run EM to estimate Ne and mutation rate (per chromosome, parallel):

```bash
# Submit array job for chromosomes 1-22
sbatch stage1_em.sh
```

### Step 3: Combine EM Outputs

After Stage 1 completes, combine outputs and extract global parameters:

```bash
sbatch after_stage1_before_stage2_chromocombine.sh
```

This creates `global_ne.txt` containing the Ne and mutation rate needed for Stage 2.

### Step 4: Stage 2 - Haplotype Painting

Paint haplotypes using estimated parameters:

```bash
sbatch stage2_paint.sh
```

### Step 5: Stage 3 - ChromoCombine + fineSTRUCTURE

Merge per-chromosome results and run population structure analysis:

```bash
sbatch stage3_finestructure.sh
```

---

## Input/Output Formats

### Phase File Format

```
P 100001 100021 100056 ...
AACCAACCAAC...
GTCCGTCGTCG...
```

- Line 1: Header starting with `P`, followed by space-separated positions
- Subsequent lines: Two haplotype lines per sample (0/1 or A/C/G/T alleles)

### Genetic Map Format

```
Chromosome  Position(bp)  Rate(cM/Mb)  Map(cM)
1           100001        2.5          0.0
1           100021        2.5          0.001
...
```

### Recombination File Format (ChromoPainter)

```
start.pos recom.rate.perbp
100001 2.5000000000e-08
100021 2.5000000000e-08
...
```

### Output Files

| File | Description |
|------|-------------|
| `chr{N}.EMprobs.out` | EM estimated Ne and mutation rate for chromosome N |
| `global_ne.txt` | Combined Ne and mutation rate for all chromosomes |
| `chr{N}.chunkcounts.out` | Haplotype painting counts |
| `chr{N}.chunklengths.out` | Segment length data |
| `merged.chunkcounts.out` | ChromoCombine merged counts |
| `merged.mcmc.xml` | fineSTRUCTURE MCMC chain |
| `merged.maxstate.xml` | Maximum state tree |
| `merged.tree.xml` | Phylogenetic tree (Newick-style XML) |

---

## Troubleshooting

### Common Issues

**Error: "No position line found in phase file"**
- Verify your phase file has a header line starting with `P`
- Check that positions are space-separated integers

**Error: "Genetic map columns incorrect"**
- Ensure genetic map has exactly: `Chromosome Position(bp) Rate(cM/Mb) Map(cM)`
- Check for extra header lines or different column names

**Error: "Output file empty" (Stage 2)**
- Check that `global_ne.txt` was created by the chromocombine step
- Verify phase files and recombination files exist for all chromosomes

**Error: "Binary not found"**
- Update paths in `config.sh` to point to your ChromoPainter binaries
- Ensure binaries are executable (`chmod +x`)

### Monitoring Jobs

```bash
# Check job status
squeue -u $USER

# View output logs
cat slurm-*.out

# Check for errors
grep -i error slurm-*.err
```

### Adjusting Resources

If jobs fail due to memory or time limits, edit the `#SBATCH` directives
at the top of each script:

```bash
# Increase memory
#SBATCH --mem=32G

# Increase time limit
#SBATCH --time=72:00:00
```

---

## Citation

If you use this pipeline in your research, please cite the original ChromoPainter paper:

> Lawson DJ, Hellenthal G, Myers S, Falush D (2012)
> Inference of Population Recombination Rates Using Haplotype Data
> *American Journal of Human Genetics*, 91(4): 627-637
> DOI: 10.1016/j.ajhg.2012.08.014

And cite fineSTRUCTURE:

> Lawson DJ, Falush D (2012)
> Population Clustering Using a Model with Recombination
> *American Journal of Human Genetics*, 91(4): 638-646

---

## License

This collection of scripts is provided as-is for research purposes.
The underlying ChromoPainter and fineSTRUCTURE tools are copyrighted by
their respective authors.