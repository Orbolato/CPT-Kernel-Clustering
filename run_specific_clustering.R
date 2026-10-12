#!/usr/bin/env Rscript

source("R/cli.R")
source("R/cpt_core.R")
source("R/clustering.R")
source("R/kernel_xmeans.R")

opt <- parse_cli()
data_path <- cli_value(opt, "data", file.path("data", "erosao.csv"))
seed <- cli_integer(opt, "seed", 2020L)
initial_k <- cli_integer(opt, "initial-k", 2L)
max_k <- cli_integer(opt, "max-k", 10L)
split_restarts <- cli_integer(opt, "split-restarts", 1L)
preprocessing <- cli_value(opt, "preprocessing", "recovered")
output_dir <- cli_value(opt, "output-dir", "results")

if (!(preprocessing %in% c("recovered", "minmax", "none"))) {
  stop("--preprocessing must be recovered, minmax, or none.")
}

data <- read_cpt_csv(data_path)
prep <- prepare_clustering_matrix(data, preprocessing = preprocessing)
fit <- kernel_xmeans(
  prep$x,
  initial_k = initial_k,
  max_k = max_k,
  seed = seed,
  split_restarts = split_restarts,
  verbose = TRUE
)
centers <- cluster_centers_original_units(data, fit$cluster)
ensure_dir(output_dir)

centers_path <- file.path(output_dir, "specific_cluster_centers.csv")
history_path <- file.path(output_dir, "specific_xmeans_history.csv")
assignments_path <- file.path(output_dir, "specific_cluster_assignments.csv")
result_path <- file.path(output_dir, "specific_kernel_xmeans.rds")

utils::write.csv(centers, centers_path, row.names = FALSE)
utils::write.csv(fit$history, history_path, row.names = FALSE)
utils::write.csv(data.frame(source_row = seq_len(nrow(data)), cluster = fit$cluster),
                 assignments_path, row.names = FALSE)

compact <- list(
  study = "specific",
  cluster = fit$cluster,
  centers_original_units = centers,
  selected_k = fit$k,
  sigma = fit$sigma,
  history = fit$history,
  preprocessing = preprocessing,
  scaler = prep$scaler,
  seed = seed,
  split_restarts = split_restarts,
  input_columns = CPT_INPUTS,
  n_rows = nrow(data),
  paper_expected_rows = 2847L
)
saveRDS(compact, result_path)

cat("Selected k:", fit$k, "\n")
cat("RBF sigma:", fit$sigma, "\n")
cat("Rows:", nrow(data), "\n")
cat("Wrote:", result_path, "\n")
