# Lightweight command-line parsing shared by the repository entry points.

parse_cli <- function(args = commandArgs(trailingOnly = TRUE)) {
  out <- list()
  i <- 1L
  while (i <= length(args)) {
    token <- args[i]
    if (!startsWith(token, "--")) stop("Unexpected argument: ", token)
    key <- sub("^--", "", token)
    if (i == length(args) || startsWith(args[i + 1L], "--")) {
      out[[key]] <- TRUE
      i <- i + 1L
    } else {
      out[[key]] <- args[i + 1L]
      i <- i + 2L
    }
  }
  out
}

cli_value <- function(options, key, default = NULL) {
  if (!is.null(options[[key]])) options[[key]] else default
}

cli_integer <- function(options, key, default) {
  value <- as.integer(cli_value(options, key, default))
  if (is.na(value)) stop("--", key, " must be an integer.")
  value
}

cli_csv_integers <- function(options, key, default) {
  raw <- cli_value(options, key, paste(default, collapse = ","))
  value <- as.integer(strsplit(raw, ",", fixed = TRUE)[[1]])
  if (anyNA(value)) stop("--", key, " must be a comma-separated integer list.")
  value
}

ensure_dir <- function(path) {
  if (!dir.exists(path)) dir.create(path, recursive = TRUE)
  invisible(path)
}
