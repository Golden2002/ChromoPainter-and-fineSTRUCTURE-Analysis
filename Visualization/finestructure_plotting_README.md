# fineSTRUCTURE Plotting Module

## Overview

This R script generates publication-quality visualizations for fineSTRUCTURE population genetics analysis results. It creates a combined heatmap with phylogenetic tree, a colored tree diagram, and exports sample mapping information.

## Input Files

| File | Description | Format |
|------|-------------|--------|
| `tyc.tree.xml` | fineSTRUCTURE tree output | XML (Newick embedded) |
| `tyc.chunkcounts.out` | Coancestry matrix | Tab-separated, first column = sample IDs |
| `fineSTRUCTURE_sample_1.txt` | Sample list | Two columns: Sample, Population |
| `filtered_modified_info2.txt` | Sample metadata | Tab-separated with sample and pop columns |

## Output Files

| File | Description |
|------|-------------|
| `fineSTRUCTURE_ComplexHeatmap.pdf` | Heatmap + dendrogram combined figure |
| `fineSTRUCTURE_colored_tree.pdf` | Simple colored tree |
| `fineSTRUCTURE_colored_tree_block.pdf` | Tree with population color blocks |
| `fineSTRUCTURE_sample_mapping.txt` | Sample-to-population mapping table |

## Dependencies

```r
# CRAN packages
install.packages(c(
  "ape",           # Phylogenetic tree manipulation
  "data.table",    # Fast data reading
  "circlize",      # Color schemes
  "dendextend",    # Dendrogram manipulation
  "scales",        # Color palette generation
  "RColorBrewer",  # Color palettes
  "grid",          # Graphics layout
  "XML"            # XML parsing
))

# Bioconductor
if (!requireNamespace("BiocManager", quietly = TRUE))
    install.packages("BiocManager")
BiocManager::install("ComplexHeatmap")
```

## Usage

```bash
Rscript plot_finestructure.R
```

Before running, edit the working directory and file paths at the top of the script:

```r
setwd("/path/to/your/finestructure/results")

tree_file   <- "tyc.tree.xml"
matrix_file <- "tyc.chunkcounts.out"
sample_file <- "fineSTRUCTURE_sample_1.txt"
info_file   <- "filtered_modified_info2.txt"
```

## Configuration

### Sample File Format

The sample file should have two columns (no header):

```
SampleID    Population
Sample001   PopA
Sample002   PopA
Sample003   PopB
```

### Metadata File Format

The info file should contain at minimum `sample` and `pop` columns:

```
sample      pop         region     subregion
Sample001   PopA        Asia       EastAsia
Sample002   PopA        Asia       EastAsia
Sample003   PopB        Asia       SouthAsia
```

## Output Description

### ComplexHeatmap Figure

The main output (`fineSTRUCTURE_ComplexHeatmap.pdf`) contains:

- **Heatmap**: Log-transformed coancestry matrix (log1p) with capped values at 95th percentile
- **Color scale**: White → Pale yellow → Yellow-orange → Orange-red → Red → Dark wine red
- **Row/column dendrograms**: Hierarchical clustering based on the fineSTRUCTURE tree
- **Population annotations**: Colored bars on both axes indicating population membership

### Colored Tree Figure

Two additional tree visualizations (`fineSTRUCTURE_colored_tree.pdf` and `fineSTRUCTURE_colored_tree_block.pdf`):

- Horizontal dendrogram with grey branches
- Colored leaf nodes (circles) matching population colors
- Colored population blocks on the right side
- Population labels positioned beside the blocks

## Color Palette

The script uses a combined palette from RColorBrewer:

- `Set3` (12 colors)
- `Paired` (12 colors)
- `Dark2` (8 colors)

If there are more populations than available colors, `scales::hue_pal()` generates additional colors automatically.

## Key Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| `heat_cap` | 95th percentile | Caps extreme values for better visualization |
| `transform` | `log1p` | Log transformation to reduce skewness |
| `raster_quality` | 10 | PDF rendering quality (higher = slower) |
| `row_dend_width` | 5 cm | Tree width in heatmap |
| `column_dend_height` | 5 cm | Tree height in heatmap |

## Function Pipeline

```
XML Tree File → read.tree() → ape dendrogram
                                     ↓
Chunkcounts → fread() → matrix → relabel → ordered by tree
                                     ↓
                            ComplexHeatmap + dend
                                     ↓
                               PDF output
```

## Notes

- The script automatically matches samples between the sample file and info file
- Missing population assignments will cause the script to stop with an error
- Labels are formatted as `Population|SampleID` in the output figures
- All samples get IND identifiers (IND1, IND2, ...) internally
