# build_training_table.R
#
# Builds the one-row-per-tree training table used in the "Predicting crown
# scorch" case study: for every tree in jbcannon/CrownScorchTLS-data, run the
# same pipeline taught in README.md (remove_stem -> add_reflectance ->
# get_histogram) on the POST-burn scan, pivot its 100 fixed intensity bins
# (get_histogram() always bins on seq(-20, 0, by = 0.2), so every tree lines
# up on the same columns) into one wide row, and join on treeid/dbh/scorch
# (% SCORCH) from the field survey.
#
# This is a build script, not a student-facing exercise -- students work from
# its output, data/scorch_training_table.csv, not from this script. The
# raw_laz_dir it downloads into below is .gitignore'd (~1-2GB for the full
# ~253-tree dataset); only the resulting CSV is meant to be committed.
# Downloads are skipped for any tree already present in raw_laz_dir, so
# re-running this after a partial run or a code tweak is cheap.
#
# Run with your working directory set to the repo root, not scripts/:
# Rscript scripts/build_training_table.R  (takes a while on first run --
# it's downloading and processing ~250 point clouds).

library(CrownScorchTLS)
library(lidR)
library(jsonlite)
library(dplyr)
library(tidyr)
library(readr)

repo_raw    <- "https://raw.githubusercontent.com/jbcannon/CrownScorchTLS-data/main"
api_url     <- "https://api.github.com/repos/jbcannon/CrownScorchTLS-data/contents/data/manual-clip-trees"
raw_laz_dir <- "data/laz_all"  # downloaded once, kept locally, .gitignore'd
dir.create(raw_laz_dir, showWarnings = FALSE, recursive = TRUE)

# --- 1. list every post-burn tree scan in the data repo ---
listing <- fromJSON(api_url)
post_files <- listing$name[grepl("_post\\.laz$", listing$name)]
tree_ids <- sub("_post\\.laz$", "", post_files)
cat("Found", length(tree_ids), "trees.\n")

# --- 2. field-measured response (% SCORCH), joined by tree id (TILE-TAG_ID) ---
# A few field entries record scorch as a range ("1-5") instead of a single
# number, which would otherwise make the whole column read in as character.
# "1-5" is recoded to 2.5 specifically (not its arithmetic mean, which is 3);
# everything else parses as a plain number.
parse_scorch <- function(x) {
  x <- trimws(x)
  out <- suppressWarnings(as.numeric(x))
  out[x == "1-5"] <- 2.5
  out
}

survey <- read_csv(paste0(repo_raw, "/data/mortality_scorch_survey%20-%20data.csv"),
                    show_col_types = FALSE)
survey <- survey %>%
  mutate(treeid = paste(TILE, TAG_ID, sep = "-")) %>%
  select(treeid, dbh = DBH_CM, scorch = `% SCORCH`) %>%
  mutate(scorch = parse_scorch(scorch)) %>%
  filter(!is.na(scorch))

# A valid .laz/.las file starts with the 4-byte ASCII signature "LASF".
# download.file() can silently write a truncated/empty file on a transient
# network error without raising an R condition -- and feeding a bad file
# into readLAS() crashes the whole R process (segfault) instead of throwing
# a catchable error. So every file, cached or freshly downloaded, gets its
# signature checked before readLAS() ever sees it.
is_valid_laz <- function(path) {
  if (!file.exists(path) || file.size(path) < 100) return(FALSE)
  con <- file(path, "rb")
  on.exit(close(con))
  sig <- tryCatch(readBin(con, "raw", 4), error = function(e) raw(0))
  length(sig) == 4 && rawToChar(sig) == "LASF"
}

download_with_retry <- function(url, path, attempts = 3) {
  for (i in seq_len(attempts)) {
    unlink(path)
    tryCatch(download.file(url, path, mode = "wb", quiet = TRUE),
             error = function(e) NULL)
    if (is_valid_laz(path)) return(TRUE)
    Sys.sleep(1)
  }
  FALSE
}

# --- 3. process each tree: download (once, validated) -> remove_stem -> add_reflectance -> get_histogram ---
process_one <- function(tree_id) {
  local_path <- file.path(raw_laz_dir, paste0(tree_id, "_post.laz"))

  if (!is_valid_laz(local_path)) {
    url <- paste0(repo_raw, "/data/manual-clip-trees/", tree_id, "_post.laz")
    if (!download_with_retry(url, local_path)) {
      message("  skipped ", tree_id, ": download failed or invalid file after retries")
      return(NULL)
    }
  }

  tryCatch({
    las <- readLAS(local_path)
    if (is.null(las) || npoints(las) == 0) return(NULL)
    crown <- remove_stem(las)
    crown <- add_reflectance(crown)
    hist_df <- get_histogram(crown)
    hist_df %>%
      mutate(treeid = tree_id,
             # round first: seq(-20, 0, by = 0.2) bin mids carry floating-point
             # noise (e.g. -0.0999999999999996), which would otherwise leak
             # into these column names verbatim.
             intensity = paste0("intensity_", round(intensity, 1))) %>%
      pivot_wider(names_from = intensity, values_from = density)
  }, error = function(e) {
    message("  skipped ", tree_id, ": ", conditionMessage(e))
    NULL
  })
}

rows <- vector("list", length(tree_ids))
for (i in seq_along(tree_ids)) {
  cat(sprintf("[%d/%d] %s\n", i, length(tree_ids), tree_ids[i]))
  rows[[i]] <- process_one(tree_ids[i])
}

features <- bind_rows(rows)
cat("\nSuccessfully processed", nrow(features), "of", length(tree_ids), "trees.\n")

# --- 4. join features to the field response and write the final table ---
training_table <- features %>%
  inner_join(survey, by = "treeid") %>%
  relocate(treeid, dbh, scorch)

dir.create("data", showWarnings = FALSE)
out_path <- "data/scorch_training_table.csv"
write_csv(training_table, out_path)
cat("Wrote", nrow(training_table), "rows x", ncol(training_table), "cols to", out_path, "\n")
