#!/usr/bin/awk -f
# =============================================================================
# convert_map.awk - Convert genetic map to ChromoPainter recombination file
# =============================================================================
# Converts genetic map files (format: Chromosome Position Rate(cM/Mb) Map(cM))
# into ChromoPainter-style recombination files.
#
# Usage:
#   awk -f convert_map.awk genetic_map_GRCh38_chr*.txt
#
# Output files (created in current directory):
#   - chr1.recombfile ... chr22.recombfile   (per-chromosome files)
#   - all.recombfile                          (merged file, -9 chromosome delimiter)
#
# Note: Input genetic map files should be chromosome-separated and sorted by
#       position. Each file should be named to indicate which chromosome it
#       contains (e.g., genetic_map_GRCh38_chr1.txt)
#
# Requirements: gawk or standard awk
# =============================================================================

BEGIN {
    # Output file for merged results
    combined_file = "all.recombfile"

    # Write header to combined file
    print "start.pos recom.rate.perbp" > combined_file

    prev_chrom = ""       # Previous chromosome number
    last_pos   = ""       # Last SNP genomic position
    prev_morgan = ""      # Last SNP recombination rate (Morgan/bp)
}

# Skip header lines
/^Chromosome/ { next }

# =============================================================================
# Main processing: read each line of genetic map
# =============================================================================
{
    chrom = $1
    pos   = $2
    rate  = $3 + 0         # Force numeric conversion

    # Convert cM/Mb to Morgan per base pair
    # 1 cM/Mb = 0.01 Morgan/Mb = 1e-8 Morgan/bp
    morgan_per_bp = rate * 1.0e-8

    # ---- New chromosome detected ----
    if (chrom != prev_chrom) {
        # If not the first chromosome, finalize previous chromosome's file
        if (prev_chrom != "") {
            # Write terminal record (position with rate=0 signals end of chromosome)
            out_prev = "chr" prev_chrom ".recombfile"
            print last_pos, 0 >> out_prev
            close(out_prev)

            # Write chromosome delimiter to combined file (-9 marks chromosome boundary)
            print last_pos, -9 >> combined_file
        }

        # Initialize new chromosome's output file
        curr_outfile = "chr" chrom ".recombfile"
        print "start.pos recom.rate.perbp" > curr_outfile
        header_written[curr_outfile] = 1
    }

    # ---- Write previous SNP's data (SNP i's rate applies to segment i to i+1) ----
    if (last_pos != "") {
        # Append to per-chromosome file
        print last_pos, prev_morgan >> curr_outfile
        # Append to combined file
        print last_pos, prev_morgan >> combined_file
    }

    # ---- Update running values ----
    last_pos    = pos
    prev_morgan = morgan_per_bp
    prev_chrom  = chrom
}

# =============================================================================
# Finalize: write terminal record for last chromosome
# =============================================================================
END {
    if (prev_chrom != "") {
        # Write terminal record for final chromosome
        out_last = "chr" prev_chrom ".recombfile"
        print last_pos, 0 >> out_last
        close(out_last)

        # Write terminal record to combined file
        print last_pos, 0 >> combined_file
    }
}