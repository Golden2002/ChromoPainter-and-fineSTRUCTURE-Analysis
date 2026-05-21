#!/usr/bin/env Rscript

############################################################
# fineSTRUCTURE Nature/Science-style Visualization
# ComplexHeatmap + Colored Phylogenetic Tree
############################################################

# install.packages(c(
#   "circlize",
#   "dendextend",
#   "scales"
# ))
#
# BiocManager::install(c(
#   "ComplexHeatmap"
# ))

############################################################
# libraries
############################################################

library(XML)
library(ape)
library(data.table)

library(ComplexHeatmap)
library(circlize)

library(RColorBrewer)
library(scales)

library(grid)
library(dendextend)

############################################################
# CONFIGURATION - EDIT THESE PATHS
############################################################

# Working directory containing fineSTRUCTURE output files
setwd("/path/to/your/finestructure/results")

# Input file paths (edit these to match your data)
tree_file   <- "tyc.tree.xml"          # fineSTRUCTURE tree XML
matrix_file <- "tyc.chunkcounts.out"  # Coancestry matrix
sample_file <- "sample_list.txt"      # Sample-to-population mapping
info_file   <- "sample_info.txt"      # Sample metadata (with pop column)

############################################################
# read sample file
############################################################

samples <- fread(
  sample_file,
  header = FALSE
)

############################################################
# two-column format:
# Sample   Population
############################################################

colnames(samples) <- c(
  "Sample",
  "Population"
)

############################################################
# read metadata
############################################################

info <- fread(
  info_file,
  sep = "\t",
  header = TRUE,
  fill = TRUE
)

############################################################
# ensure population consistency
############################################################

samples$Population <- info$pop[
  match(
    samples$Sample,
    info$sample
  )
]

############################################################
# NA check
############################################################

if(any(is.na(samples$Population))) {
  cat("\nUnmatched samples:\n")
  print(
    samples[is.na(Population), ]
  )
  stop("Population matching failed.")
}

############################################################
# create IND IDs
############################################################

samples$IND <- paste0(
  "IND",
  seq_len(nrow(samples))
)

############################################################
# label
############################################################

samples$PlotTag <- paste0(
  samples$Population,
  "|",
  samples$Sample
)

samples$Label <- samples$PlotTag

############################################################
# mappings
############################################################

ind2label <- setNames(
  samples$PlotTag,
  samples$IND
)

ind2pop <- setNames(
  samples$Population,
  samples$IND
)

############################################################
# read tree
############################################################

tree_xml <- xmlParse(tree_file)

newick <- xmlValue(
  xmlRoot(tree_xml)[["Tree"]]
)

tree <- read.tree(
  text = newick
)

############################################################
# replace labels
############################################################

tree$tip.label <- ind2label[
  tree$tip.label
]

############################################################
# read coancestry matrix
############################################################

C <- fread(
  matrix_file,
  skip = 1,
  header = TRUE
)

############################################################
# first column = sample IDs
############################################################

sample_ids <- C[[1]]

############################################################
# remove first column
############################################################

C <- as.matrix(
  C[, -1]
)

mode(C) <- "numeric"

############################################################
# original IND order
############################################################

original_inds <- paste0(
  "IND",
  seq_len(nrow(C))
)

############################################################
# relabel matrix
############################################################

new_labels <- ind2label[
  original_inds
]

rownames(C) <- new_labels
colnames(C) <- new_labels

############################################################
# reorder by tree order
############################################################

ord <- tree$tip.label

C_ord <- C[
  ord,
  ord
]

############################################################
# annotation
############################################################

annotation_df <- data.frame(
  Population = gsub(
    "\\|.*",
    "",
    ord
  )
)

rownames(annotation_df) <- ord

############################################################
# population levels
############################################################

pop_levels <- unique(
  annotation_df$Population
)

############################################################
# color palette (combined RColorBrewer sets)
############################################################

base_colors <- c(
  brewer.pal(12, "Set3"),
  brewer.pal(12, "Paired"),
  brewer.pal(8, "Dark2")
)

# Extend palette if more populations than colors available
if (length(pop_levels) > length(base_colors)) {
  extra_colors <- hue_pal()(length(pop_levels) - length(base_colors))
  base_colors <- c(base_colors, extra_colors)
}

pop_colors <- setNames(
  base_colors[seq_along(pop_levels)],
  pop_levels
)

############################################################
# heatmap color
############################################################

# Use log transformation (log1p) to reduce skewness
# Alternative: sqrt(C_ord) - less aggressive
C_heat <- log1p(C_ord)

# Cap extreme values at 95th percentile for better visualization
tmp <- C_heat
diag(tmp) <- NA
heat_cap <- quantile(tmp, 0.95, na.rm = TRUE)

if(!is.finite(heat_cap) || heat_cap <= 0) {
  heat_cap <- max(C_heat, na.rm = TRUE)
}

# Apply cap to transformed values
C_heat <- pmin(C_heat, heat_cap)

# Color mapping: white to dark wine red
col_fun <- colorRamp2(
  c(
    0,
    heat_cap * 0.03,
    heat_cap * 0.15,
    heat_cap * 0.40,
    heat_cap * 0.65,
    heat_cap
  ),
  c(
    "#FFFFFF",  # white
    "#FFF7BC",  # pale yellow
    "#FEC44F",  # yellow-orange
    "#FC8D59",  # orange-red
    "#D7301F",  # red
    "#67000D"   # dark wine red
  )
)

############################################################
# convert ape tree -> dendrogram
############################################################

hc <- as.hclust(tree)

# Warning checks
if (any(is.na(hc$height))) {
  warning("as.hclust produced NA heights - check tree structure")
}
if (any(tree$edge.length <= 0, na.rm = TRUE)) {
  warning("Tree contains non-positive edge lengths - may affect rendering")
}

dend <- as.dendrogram(hc)

############################################################
# row annotation
############################################################

ha_row <- rowAnnotation(
  Population = annotation_df$Population,
  col = list(
    Population = pop_colors
  ),
  show_annotation_name = FALSE,
  width = unit(4, "mm")
)

############################################################
# column annotation
############################################################

ha_col <- HeatmapAnnotation(
  Population = annotation_df$Population,
  col = list(
    Population = pop_colors
  ),
  show_annotation_name = FALSE,
  height = unit(4, "mm"),
  show_legend = FALSE
)

############################################################
# build heatmap
############################################################

ht <- Heatmap(
  C_heat,
  name = "Coancestry",
  col = col_fun,

  # Clustering: use tree for both rows and columns
  cluster_rows = dend,
  cluster_columns = dend,
  row_dend_gp = gpar(col = "darkgrey"),
  column_dend_gp = gpar(col = "darkgrey"),

  # Annotations
  left_annotation = ha_row,
  top_annotation = ha_col,

  # Aesthetics
  show_row_names = FALSE,
  show_column_names = FALSE,
  row_dend_width = unit(5, "cm"),
  column_dend_height = unit(5, "cm"),
  border = FALSE,
  use_raster = TRUE,
  raster_quality = 10,

  heatmap_legend_param = list(
    title = "Shared ancestry",
    legend_height = unit(5, "cm"),
    title_gp = gpar(
      fontsize = 12,
      fontface = "bold"
    ),
    labels_gp = gpar(
      fontsize = 10
    )
  )
)

############################################################
# save heatmap
############################################################

pdf(
  "fineSTRUCTURE_ComplexHeatmap.pdf",
  width = 18,
  height = 18
)

draw(
  ht,
  heatmap_legend_side = "right",
  annotation_legend_side = "right"
)

dev.off()

############################################################
# standalone colored tree
############################################################

pdf(
  "fineSTRUCTURE_colored_tree.pdf",
  width = 10,
  height = 20
)

# Wide right margin for legend
par(
  mar = c(2, 2, 2, 14),
  xpd = TRUE
)

plot(
  dend,
  horiz = TRUE,
  leaflab = "none",
  edgePar = list(
    col = "darkgrey",
    lwd = 1.4
  ),
  main = "fineSTRUCTURE Tree"
)

# Colored tip points
tip_order <- labels(dend)
tip_pop <- gsub("\\|.*", "", tip_order)
tip_pop_plot <- rev(tip_pop)
n_tip <- length(tip_order)

points(
  rep(0, n_tip),
  seq_len(n_tip),
  pch = 21,
  bg = pop_colors[tip_pop_plot],
  col = "black",
  lwd = 0.2,
  cex = 1.6
)

# Colored population blocks
xmax <- par("usr")[2]
block_x1 <- xmax * 1.02
block_x2 <- xmax * 1.12

for(i in seq_along(tip_pop_plot)) {
  rect(
    xleft = block_x1,
    ybottom = i - 0.5,
    xright = block_x2,
    ytop = i + 0.5,
    col = pop_colors[tip_pop_plot[i]],
    border = NA
  )
}

# Population labels (centered per group)
rle_pops <- rle(tip_pop_plot)
cum_len <- cumsum(rle_pops$lengths)
starts <- c(1, cum_len[-length(cum_len)] + 1)
ends   <- cum_len

for (b in seq_along(rle_pops$values)) {
  pop <- rle_pops$values[b]
  ymid <- (starts[b] + ends[b]) / 2
  text(
    x = xmax * 1.16,
    y = ymid,
    labels = pop,
    pos = 4,
    cex = 0.7,
    font = 2,
    xpd = NA
  )
}

dev.off()

############################################################
# publication-grade tree with population blocks
############################################################

pdf(
  "fineSTRUCTURE_colored_tree_block.pdf",
  width = 12,
  height = 26
)

par(
  mar = c(2, 2, 2, 14),
  xpd = TRUE
)

plot(
  dend,
  horiz = TRUE,
  leaflab = "none",
  edgePar = list(
    col = "darkgrey",
    lwd = 1.4
  ),
  main = "fineSTRUCTURE Tree"
)

# Tip order and population
tip_order <- labels(dend)
tip_pop <- gsub("\\|.*", "", tip_order)
tip_pop_plot <- rev(tip_pop)
ypos <- seq_along(tip_order)

# Larger colored nodes
points(
  rep(0, length(ypos)),
  ypos,
  pch = 21,
  bg = pop_colors[tip_pop_plot],
  col = "black",
  lwd = 0.2,
  cex = 2.2
)

# Colored blocks
xmax <- par("usr")[2]
block_x1 <- xmax * 1.02
block_x2 <- xmax * 1.12

for(i in seq_along(ypos)) {
  rect(
    xleft = block_x1,
    ybottom = ypos[i] - 0.5,
    xright = block_x2,
    ytop = ypos[i] + 0.5,
    col = pop_colors[tip_pop_plot[i]],
    border = NA
  )
}

# Population labels
rle_pops <- rle(tip_pop_plot)
cum_len <- cumsum(rle_pops$lengths)
starts <- c(1, cum_len[-length(cum_len)] + 1)
ends   <- cum_len

for (b in seq_along(rle_pops$values)) {
  pop <- rle_pops$values[b]
  ymid <- (starts[b] + ends[b]) / 2
  text(
    x = xmax * 1.16,
    y = ymid,
    labels = pop,
    pos = 4,
    cex = 0.7,
    font = 2,
    xpd = NA
  )
}

dev.off()

############################################################
# export mapping table
############################################################

fwrite(
  samples,
  file = "fineSTRUCTURE_sample_mapping.txt",
  sep = "\t"
)

############################################################
# session summary
############################################################

cat(
  "\n========================================\n"
)

cat(
  "fineSTRUCTURE publication figures done.\n"
)

cat(
  "========================================\n\n"
)