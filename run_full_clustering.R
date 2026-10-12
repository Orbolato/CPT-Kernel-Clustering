#!/usr/bin/env Rscript

source("R/cli.R")
source("R/cpt_core.R")
source("R/clustering.R")

opt <- parse_cli()
data_dir <- cli_value(opt, "data-dir", "data")
k_values <- cli_csv_integers(opt, "k-values", 7:10)
restarts <- cli_integer(opt, "restarts", 5L)
seed <- cli_integer(opt, "seed", 2020L)
preprocessing <- cli_value(opt, "preprocessing", "recovered")
max_rows <- cli_integer(opt, "max-rows", 0L)
output_dir <- cli_value(opt, "output-dir", "results")

if (!(preprocessing %in% c("recovered", "minmax", "none"))) {
  stop("--preprocessing must be recovered, minmax, or none.")
}

data <- read_full_dataset(data_dir)
original_n <- nrow(data)
sampled <- FALSE
if (max_rows > 0L && max_rows < nrow(data)) {
  set.seed(seed)
  data <- data[sample.int(nrow(data), max_rows), , drop = FALSE]
  rownames(data) <- NULL
  sampled <- TRUE
  message("Smoke-test mode: using ", max_rows, " of ", original_n, " rows.")
}

prep <- prepare_clustering_matrix(data, preprocessing = preprocessing)
search <- search_kernel_kmeans(
  prep$x,
  k_values = k_values,
  restarts = restarts,
  seed = seed
)

best <- search$best
centers <- cluster_centers_original_units(data, best$cluster)
ensure_dir(output_dir)

summary_path <- file.path(output_dir, "full_k_search.csv")
centers_path <- file.path(output_dir, "full_cluster_centers.csv")
assignments_path <- file.path(output_dir, "full_cluster_assignments.csv")
result_path <- file.path(output_dir, "full_kernel_kmeans.rds")

utils::write.csv(search$summary, summary_path, row.names = FALSE)
utils::write.csv(centers, centers_path, row.names = FALSE)
assignment <- data.frame(
  source_file = if (".source_file" %in% names(data)) data$.source_file else NA_character_,
  source_row = if (".source_row" %in% names(data)) data$.source_row else seq_len(nrow(data)),
  cluster = best$cluster
)
utils::write.csv(assignment, assignments_path, row.names = FALSE)

compact <- list(
  study = "full",
  cluster = best$cluster,
  centers_original_units = centers,
  k_search = search$summary,
  selected_k = best$k,
  objective = best$objective,
  sigma = best$sigma,
  preprocessing = preprocessing,
  scaler = prep$scaler,
  seed = seed,
  restarts = restarts,
  input_columns = CPT_INPUTS,
  n_rows = nrow(data),
  original_n_rows = original_n,
  sampled = sampled,
  paper_expected_rows = 130966L
)
saveRDS(compact, result_path)

cat("Selected k:", best$k, "\n")
cat("Objective:", best$objective, "\n")
cat("RBF sigma:", best$sigma, "\n")
cat("Rows:", nrow(data), if (sampled) "(sampled)" else "", "\n")
cat("Wrote:", result_path, "\n")
