# Kernel k-means helpers for the 2020 CPT soil-classification study.

require_kernlab <- function() {
  if (!requireNamespace("kernlab", quietly = TRUE)) {
    stop("Package 'kernlab' is required. Install it with install.packages('kernlab').")
  }
}

estimate_rbf_sigma <- function(x) {
  require_kernlab()
  x <- as.matrix(x)
  # This mirrors kernlab's automatic RBF heuristic and the recovered source,
  # which takes the median estimate returned by sigest().
  as.numeric(kernlab::sigest(x, scaled = FALSE)[2])
}

fit_kernel_kmeans_once <- function(x, k, sigma = NULL, seed = NULL) {
  require_kernlab()
  x <- as.matrix(x)
  if (nrow(x) < k) stop("k cannot exceed the number of observations.")
  if (k < 2L) stop("k must be at least 2.")
  if (!is.null(seed)) set.seed(seed)
  if (is.null(sigma)) sigma <- estimate_rbf_sigma(x)

  model <- kernlab::kkmeans(
    x,
    centers = as.integer(k),
    kernel = "rbfdot",
    kpar = list(sigma = sigma)
  )
  cluster <- as.integer(as.vector(model))
  within <- as.numeric(kernlab::withinss(model))

  list(
    model = model,
    cluster = cluster,
    withinss = within,
    objective = sum(within),
    sigma = sigma,
    k = as.integer(k),
    seed = seed
  )
}

fit_kernel_kmeans <- function(x, k, restarts = 5L, seed = 2020L, sigma = NULL) {
  if (restarts < 1L) stop("restarts must be at least 1.")
  x <- as.matrix(x)
  if (is.null(sigma)) sigma <- estimate_rbf_sigma(x)

  objectives <- numeric(restarts)
  best_fit <- NULL
  best_objective <- Inf
  best_restart <- NA_integer_
  for (i in seq_len(restarts)) {
    fit <- fit_kernel_kmeans_once(x, k, sigma = sigma, seed = seed + i - 1L)
    objectives[i] <- fit$objective
    is_best <- fit$objective < best_objective
    if (is_best) {
      best_fit <- fit
      best_objective <- fit$objective
      best_restart <- i
    }
    if (!is_best) rm(fit)
  }
  best_fit$restart <- best_restart
  best_fit$all_objectives <- objectives
  best_fit
}

search_kernel_kmeans <- function(x,
                                 k_values = 7:10,
                                 restarts = 5L,
                                 seed = 2020L,
                                 sigma = NULL) {
  x <- as.matrix(x)
  k_values <- sort(unique(as.integer(k_values)))
  if (any(k_values < 2L)) stop("All k values must be at least 2.")
  if (is.null(sigma)) sigma <- estimate_rbf_sigma(x)

  summary <- data.frame(
    k = k_values,
    objective = NA_real_,
    best_restart = NA_integer_,
    sigma = rep(sigma, length(k_values))
  )
  best_fit <- NULL
  best_objective <- Inf
  for (i in seq_along(k_values)) {
    fit <- fit_kernel_kmeans(
      x,
      k = k_values[i],
      restarts = restarts,
      seed = seed + 1000L * (i - 1L),
      sigma = sigma
    )
    summary$objective[i] <- fit$objective
    summary$best_restart[i] <- fit$restart
    is_best <- fit$objective < best_objective
    if (is_best) {
      best_fit <- fit
      best_objective <- fit$objective
    }
    if (!is_best) rm(fit)
  }
  list(best = best_fit, summary = summary, sigma = sigma)
}
