#!/usr/bin/env Rscript

source("R/cpt_core.R")
source("R/clustering.R")
source("R/kernel_xmeans.R")
source("R/ann_core.R")

fail <- function(message) stop(message, call. = FALSE)
expect_true <- function(value, message) if (!isTRUE(value)) fail(message)
expect_equal <- function(a, b, tol = 1e-10, message = "Values differ") {
  if (length(a) != length(b) || any(abs(a - b) > tol)) fail(message)
}

# Parse every maintained R file and entry point. This catches syntax regressions
# without requiring the expensive paper-sized analyses.
files_to_parse <- c(
  list.files("R", pattern = "\\.R$", full.names = TRUE),
  list.files(".", pattern = "^run_.*\\.R$", full.names = TRUE)
)
for (path in files_to_parse) parse(file = path)

# Recovered preprocessing maps the min and max of a feature to 0 and 1.
toy <- data.frame(
  Depth_m = c(0, 5, 10),
  qc_MPa = c(1, 3, 5),
  fs_kPa = c(10, 20, 30),
  u_kPa = c(100, 200, 300)
)
prep <- prepare_clustering_matrix(toy, preprocessing = "recovered")
expect_equal(prep$x[1, ], rep(0, 4), message = "Recovered transform should map minima to zero")
expect_equal(prep$x[3, ], rep(1, 4), message = "Recovered transform should map maxima to one")

# Percentage comparisons must sum to 100 within each cluster.
tab <- row_percent_table(c(1, 1, 2, 2), c("a", "b", "a", "a"))
expect_true(all(abs(rowSums(tab) - 100) < 1e-10), "Row percentages do not sum to 100")
expect_equal(mean_class_recall(c(1, 1, 2, 2), c(1, 2, 2, 2)), 0.75,
             message = "Mean class recall is incorrect")

# Validation folds are a derangement: every fold is used exactly once for
# validation and never against itself as the test fold. The test also exercises
# the final one-candidate case that is unsafe with sample(n, 1).
validation_map <- make_validation_fold_map(10L)
expect_true(identical(sort(validation_map), seq_len(10L)),
            "Validation folds must form a permutation of 1:10")
expect_true(all(validation_map != seq_len(10L)),
            "A test fold must never also be its validation fold")

# Deterministic historical balancing helper.
bal_data <- data.frame(
  x = c(1, 2, 3, 4, 10, 11, 12, 13),
  y = c(1, 1.5, 2, 2.5, 5, 5.5, 6, 6.5),
  cluster = c(1, 1, 1, 1, 2, 2, 2, 2)
)
balanced <- balance_historical_mean(
  bal_data, c("x", "y"), "cluster", minimum_per_class = 4, seed = 2020
)
expect_true(all(table(balanced$cluster) == 8), "Historical balance target is incorrect")

# Kernel clustering smoke tests on a small synthetic dataset.
set.seed(1)
x <- rbind(
  cbind(rnorm(30, -2, 0.15), rnorm(30, -2, 0.15)),
  cbind(rnorm(30,  2, 0.15), rnorm(30,  2, 0.15))
)
fit <- fit_kernel_kmeans(x, k = 2, restarts = 2, seed = 2020)
expect_true(length(fit$cluster) == nrow(x), "Kernel k-means returned the wrong number of labels")
expect_true(length(unique(fit$cluster)) == 2, "Kernel k-means did not return two clusters")
expect_true(is.finite(fit$objective), "Kernel k-means objective is not finite")

xfit <- kernel_xmeans(x, initial_k = 2, max_k = 4, seed = 2020, max_rounds = 3)
expect_true(length(xfit$cluster) == nrow(x), "Kernel X-means returned the wrong number of labels")
expect_true(xfit$k >= 2 && xfit$k <= 4, "Kernel X-means returned an invalid cluster count")

# Public repository must not contain the recovered datasets or third-party
# xmeans.R source with unclear redistribution terms.
for (path in c("data/completa.csv", "data/metro.csv", "data/cunha.csv", "data/erosao.csv", "xmeans.R")) {
  expect_true(!file.exists(path), paste("Restricted/unreviewed artifact should not be tracked:", path))
}

# Provenance archive checksum is fixed so accidental mutation is visible.
archive <- "legacy/2018/CPT_kernel_clustering_recovered_author_source.tar.xz"
expect_true(file.exists(archive), "Recovered author-source archive is missing")
hash_line <- system2("sha256sum", archive, stdout = TRUE)
archive_hash <- strsplit(hash_line, "[[:space:]]+")[[1]][1]
expect_true(
  identical(archive_hash, "b96d2c3e9f9169ee1b4c5daede0a2a25daaff55035e8b790de7f47c04fc6aea1"),
  "Recovered author-source archive checksum changed"
)

cat("All core and provenance tests passed.\n")
