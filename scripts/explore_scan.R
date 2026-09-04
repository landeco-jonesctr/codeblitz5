# explore_scan.R
# Run this in RStudio (or `Rscript scripts/explore_scan.R` in a terminal)
# with your working directory set to the repo root, not scripts/ -- it reads
# and writes paths like "data/laz/..." and "media/..." relative to the root.
# Mirrors the "Look at a raw scan" code block in README.md, plus saves the
# histogram plot to media/ so it can be dropped into the README.

# one time setup
# lidR and CrownScorchTLS are off CRAN right now -- install from GitHub
# install.packages('devtools') # if you don't have it.
# devtools::install_github("jbcannon/CrownScorchTLS")
# devtools::install_github("r-lidar/lidR")

library(CrownScorchTLS)
library(lidR)

tree_id <- "M-04-15549"
las <- readLAS(file.path("data/laz", paste0(tree_id, "_post.laz")))

plot(las)                        # raw point cloud
plot(las, color = "Intensity")   # colored by reflectance intensity

crown <- remove_stem(las)        # strip out the trunk, keep just the crown
crown <- add_reflectance(crown)  # fill in any missing reflectance values

hist(crown$Intensity)            # just a plain base-R histogram of the crown's points

hist_df <- get_histogram(crown)  # same idea, packaged as an easy-to-use table
print(hist_df)

# --- save the histogram as a titled image for the README ---
dir.create("media", showWarnings = FALSE)
out_path <- file.path("media", paste0(tree_id, "_crown_intensity_hist.jpg"))
jpeg(out_path, width = 900, height = 650, res = 120)
hist(crown$Intensity,
     main = tree_id,
     xlab = "Intensity",
     col = "steelblue", border = "white")
dev.off()
cat("\nSaved plot to:", out_path, "\n")

# --- also dump the printed table to a text file, so it's easy to paste back ---
sink(file.path("media", paste0(tree_id, "_hist_df_printout.txt")))
print(hist_df)
sink()
cat("Saved print(hist_df) output to:", file.path("media", paste0(tree_id, "_hist_df_printout.txt")), "\n")
