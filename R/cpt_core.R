# Shared data and preprocessing utilities for the CPT clustering study.
#
# The 2020 paper works with four directly measured CPT quantities: depth,
# cone resistance, sleeve friction, and pore pressure. The recovered 2018
# development source applies a min-max transform followed by a signed base-10
# mapping before clustering. The exact numerical preprocessing is not stated in
# full detail in the article, so the maintained code makes that recovered choice
# explicit and configurable rather than hiding it inside a monolithic script.

CPT_INPUTS <- c("Depth_m", "qc_MPa", "fs_kPa", "u_kPa")
CPT_REFERENCE_COLUMNS <- c("SBTn", "MSBTn", "Cspt")

assert_numeric_columns <- function(data, columns) {
  missing <- setdiff(columns, names(data))
  if (length(missing) > 0L) {
    stop("Missing required columns: ", paste(missing, collapse = ", "))
  }
  non_numeric <- columns[!vapply(data[columns], is.numeric, logical(1))]
  if (length(non_numeric) > 0L) {
    stop("Columns must be numeric: ", paste(non_numeric, collapse = ", "))
  }
  invisible(TRUE)
}

read_cpt_csv <- function(path, required = CPT_INPUTS) {
  if (!file.exists(path)) {
    stop("CPT data file not found: ", path)
  }
  data <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  assert_numeric_columns(data, required)
  if (anyNA(data[required])) {
    stop("Missing values found in required CPT input columns in: ", path)
  }
  data
}

read_full_dataset <- function(data_dir = "data") {
  files <- c("completa.csv", "metro.csv", "cunha.csv", "erosao.csv")
  paths <- file.path(data_dir, files)
  datasets <- Map(function(path, source_name) {
    d <- read_cpt_csv(path)
    d$.source_file <- source_name
    d$.source_row <- seq_len(nrow(d))
    d
  }, paths, files)
  data <- do.call(rbind, datasets)
  rownames(data) <- NULL
  data
}

fit_minmax <- function(data, inputs = CPT_INPUTS) {
  assert_numeric_columns(data, inputs)
  mins <- vapply(data[inputs], min, numeric(1), na.rm = TRUE)
  maxs <- vapply(data[inputs], max, numeric(1), na.rm = TRUE)
  spans <- maxs - mins
  if (any(spans <= 0)) {
    bad <- names(spans)[spans <= 0]
    stop("Cannot scale constant input columns: ", paste(bad, collapse = ", "))
  }
  list(min = mins, max = maxs, inputs = inputs)
}

apply_minmax <- function(data, scaler) {
  x <- as.matrix(data[scaler$inputs])
  mins <- scaler$min[scaler$inputs]
  spans <- scaler$max[scaler$inputs] - scaler$min[scaler$inputs]
  x <- sweep(x, 2L, mins, FUN = "-")
  sweep(x, 2L, spans, FUN = "/")
}

signed_log_map <- function(x, base_power = 2) {
  # Recovered transformation: sign(t) * log10(1 + (10^2 - 1) * |t|) / 2.
  # Keeping the formula parameterized makes its historical origin explicit.
  scale_factor <- 10^base_power - 1
  sign(x) * log10(1 + scale_factor * abs(x)) / base_power
}

prepare_clustering_matrix <- function(data,
                                      inputs = CPT_INPUTS,
                                      preprocessing = c("recovered", "minmax", "none"),
                                      scaler = NULL) {
  preprocessing <- match.arg(preprocessing)
  assert_numeric_columns(data, inputs)

  if (preprocessing == "none") {
    return(list(x = as.matrix(data[inputs]), scaler = NULL,
                preprocessing = preprocessing, inputs = inputs))
  }

  if (is.null(scaler)) {
    scaler <- fit_minmax(data, inputs)
  }
  x <- apply_minmax(data, scaler)
  if (preprocessing == "recovered") {
    x <- signed_log_map(x)
  }
  colnames(x) <- inputs
  list(x = x, scaler = scaler, preprocessing = preprocessing, inputs = inputs)
}

cluster_centers_original_units <- function(data, cluster, inputs = CPT_INPUTS) {
  if (length(cluster) != nrow(data)) {
    stop("Cluster vector length does not match the number of data rows.")
  }
  groups <- split(seq_len(nrow(data)), cluster)
  centers <- do.call(rbind, lapply(groups, function(idx) {
    vapply(data[idx, inputs, drop = FALSE], mean, numeric(1), na.rm = TRUE)
  }))
  centers <- as.data.frame(centers)
  centers$cluster <- as.integer(rownames(centers))
  centers <- centers[c("cluster", inputs)]
  rownames(centers) <- NULL
  centers
}

row_percent_table <- function(cluster, reference, drop_reference = NULL) {
  keep <- !is.na(cluster) & !is.na(reference)
  cluster <- cluster[keep]
  reference <- reference[keep]
  if (!is.null(drop_reference)) {
    keep <- !(reference %in% drop_reference)
    cluster <- cluster[keep]
    reference <- reference[keep]
  }
  tab <- table(cluster = cluster, reference = reference)
  100 * prop.table(tab, margin = 1L)
}

mean_class_recall <- function(truth, prediction) {
  truth <- as.factor(truth)
  prediction <- factor(prediction, levels = levels(truth))
  recalls <- vapply(levels(truth), function(level) {
    idx <- truth == level
    if (!any(idx)) return(NA_real_)
    mean(prediction[idx] == level, na.rm = TRUE)
  }, numeric(1))
  mean(recalls, na.rm = TRUE)
}

one_hot <- function(y, levels = sort(unique(y))) {
  y <- factor(y, levels = levels)
  out <- matrix(0, nrow = length(y), ncol = length(levels))
  out[cbind(seq_along(y), as.integer(y))] <- 1
  colnames(out) <- paste0("class_", levels)
  out
}
