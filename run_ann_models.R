#!/usr/bin/env Rscript

source("R/cli.R")
source("R/cpt_core.R")
source("R/ann_core.R")

opt <- parse_cli()
study <- cli_value(opt, "study", "full")
data_dir <- cli_value(opt, "data-dir", "data")
data_path <- cli_value(opt, "data", file.path(data_dir, "erosao.csv"))
cluster_path <- cli_value(opt, "clusters",
  if (study == "full") file.path("results", "full_kernel_kmeans.rds")
  else file.path("results", "specific_kernel_xmeans.rds"))
seed <- cli_integer(opt, "seed", 2020L)
minimum_per_class <- cli_integer(opt, "minimum-per-class", 1000L)
max_iterations <- cli_integer(opt, "max-iterations", 4000L)
output_dir <- cli_value(opt, "output-dir", "results")

if (!(study %in% c("full", "specific"))) stop("--study must be full or specific.")
if (!file.exists(cluster_path)) stop("Cluster result not found: ", cluster_path)

if (study == "full") data <- read_full_dataset(data_dir) else data <- read_cpt_csv(data_path)
clustering <- readRDS(cluster_path)
if (length(clustering$cluster) != nrow(data)) {
  stop("Cluster result row count does not match the requested dataset.")
}
data$cluster <- clustering$cluster

input_sets <- list(
  four_inputs = CPT_INPUTS,
  three_inputs = c("Depth_m", "qc_MPa", "fs_kPa")
)
ensure_dir(output_dir)

all_results <- list()
for (name in names(input_sets)) {
  cat("\nANN evaluation:", study, "/", name, "\n")
  res <- evaluate_ann_cv(
    data,
    inputs = input_sets[[name]],
    output = "cluster",
    seed = seed,
    minimum_per_class = minimum_per_class,
    max_iterations = max_iterations
  )
  res$study <- study
  res$input_set <- name
  all_results[[name]] <- res
  utils::write.csv(
    res$detail,
    file.path(output_dir, paste0(study, "_ann_", name, "_folds.csv")),
    row.names = FALSE
  )
  cat("Mean accuracy:", sprintf("%.2f", res$mean_accuracy), "%\n")
  cat("SD:", sprintf("%.2f", res$sd_accuracy), "%\n")
}

summary <- do.call(rbind, lapply(names(all_results), function(name) {
  res <- all_results[[name]]
  data.frame(
    study = study,
    input_set = name,
    mean_accuracy = res$mean_accuracy,
    sd_accuracy = res$sd_accuracy
  )
}))
utils::write.csv(summary, file.path(output_dir, paste0(study, "_ann_summary.csv")), row.names = FALSE)
saveRDS(all_results, file.path(output_dir, paste0(study, "_ann_results.rds")))
