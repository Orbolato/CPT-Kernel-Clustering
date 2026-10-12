# Clean-room kernel X-means implementation for this repository.
#
# The recovered archive contains a locally modified copy of Tsunenori Ishioka's
# X-means R code. Because no explicit redistribution license was identified for
# that third-party file, it is NOT republished here. This implementation is an
# independent rewrite of the split/BIC procedure described in the paper and of
# the statistical rule documented by the recovered development source.

.diag_gaussian_loglik <- function(x, center) {
  x <- as.matrix(x)
  n <- nrow(x)
  p <- ncol(x)
  if (n <= 2L) return(list(loglik = NA_real_, det_var = NA_real_))

  v <- apply(x, 2L, stats::var)
  if (any(!is.finite(v)) || any(v <= 0)) {
    return(list(loglik = NA_real_, det_var = NA_real_))
  }
  centered <- sweep(x, 2L, center, FUN = "-")
  quad <- sum(sweep(centered^2, 2L, v, FUN = "/"))
  det_var <- prod(v)
  loglik <- n * (-0.5 * p * log(2 * pi) - 0.5 * log(det_var)) - 0.5 * quad
  list(loglik = as.numeric(loglik), det_var = as.numeric(det_var))
}

.single_cluster_bic <- function(x) {
  x <- as.matrix(x)
  p <- ncol(x)
  q <- 2 * p
  ll <- .diag_gaussian_loglik(x, colMeans(x))
  if (!is.finite(ll$loglik)) return(list(bic = Inf, loglik = ll$loglik, det_var = ll$det_var))
  list(
    bic = -2 * ll$loglik + q * log(nrow(x)),
    loglik = ll$loglik,
    det_var = ll$det_var
  )
}

.two_cluster_bic <- function(x, cluster) {
  x <- as.matrix(x)
  p <- ncol(x)
  q <- 2 * p
  idx1 <- which(cluster == 1L)
  idx2 <- which(cluster == 2L)
  if (length(idx1) <= 2L || length(idx2) <= 2L) return(Inf)

  x1 <- x[idx1, , drop = FALSE]
  x2 <- x[idx2, , drop = FALSE]
  c1 <- colMeans(x1)
  c2 <- colMeans(x2)
  ll1 <- .diag_gaussian_loglik(x1, c1)
  ll2 <- .diag_gaussian_loglik(x2, c2)
  if (!is.finite(ll1$loglik) || !is.finite(ll2$loglik)) return(Inf)

  beta <- sqrt(sum((c1 - c2)^2)) / sqrt(ll1$det_var + ll2$det_var)
  alpha <- 0.5 / stats::pnorm(beta)
  n <- nrow(x)
  -2 * ll1$loglik - 2 * ll2$loglik + 2 * q * log(n) - 2 * n * log(alpha)
}

renumber_clusters <- function(cluster) {
  ids <- sort(unique(cluster))
  map <- setNames(seq_along(ids), ids)
  as.integer(unname(map[as.character(cluster)]))
}

kernel_xmeans <- function(x,
                          initial_k = 2L,
                          max_k = 20L,
                          seed = 2020L,
                          sigma = NULL,
                          split_restarts = 1L,
                          max_rounds = 20L,
                          verbose = FALSE) {
  x <- as.matrix(x)
  if (initial_k < 2L) initial_k <- 2L
  if (max_k < initial_k) stop("max_k must be at least initial_k.")
  fixed_sigma <- sigma
  initial_sigma <- if (is.null(fixed_sigma)) estimate_rbf_sigma(x) else fixed_sigma

  initial <- fit_kernel_kmeans(
    x,
    k = initial_k,
    restarts = split_restarts,
    seed = seed,
    sigma = initial_sigma
  )
  cluster <- initial$cluster
  history <- list()

  for (round_id in seq_len(max_rounds)) {
    old_ids <- sort(unique(cluster))
    current_k <- length(old_ids)
    accepted <- 0L
    new_cluster <- integer(length(cluster))
    next_label <- 1L
    decisions <- list()

    for (cluster_id in old_ids) {
      idx <- which(cluster == cluster_id)
      subset_x <- x[idx, , drop = FALSE]
      parent <- .single_cluster_bic(subset_x)
      can_split <- nrow(subset_x) > 4L && (current_k + accepted) < max_k

      split_fit <- NULL
      split_bic <- Inf
      accept <- FALSE
      if (can_split && is.finite(parent$bic)) {
        split_fit <- fit_kernel_kmeans(
          subset_x,
          k = 2L,
          restarts = split_restarts,
          seed = seed + round_id * 10000L + cluster_id * 100L,
          sigma = if (is.null(fixed_sigma)) NULL else fixed_sigma
        )
        split_bic <- .two_cluster_bic(subset_x, split_fit$cluster)
        accept <- is.finite(split_bic) && split_bic < parent$bic
      }

      if (accept) {
        child <- split_fit$cluster
        new_cluster[idx[child == 1L]] <- next_label
        new_cluster[idx[child == 2L]] <- next_label + 1L
        next_label <- next_label + 2L
        accepted <- accepted + 1L
      } else {
        new_cluster[idx] <- next_label
        next_label <- next_label + 1L
      }

      decisions[[length(decisions) + 1L]] <- data.frame(
        round = round_id,
        parent_cluster = cluster_id,
        n = length(idx),
        parent_bic = parent$bic,
        split_bic = split_bic,
        accepted = accept,
        split_sigma = if (is.null(split_fit)) NA_real_ else split_fit$sigma
      )
    }

    cluster <- renumber_clusters(new_cluster)
    history[[length(history) + 1L]] <- do.call(rbind, decisions)
    if (verbose) {
      cat("Round", round_id, ":", length(unique(cluster)), "clusters; accepted", accepted, "splits\n")
    }
    if (accepted == 0L || length(unique(cluster)) >= max_k) break
  }

  structure(
    list(
      cluster = cluster,
      k = length(unique(cluster)),
      sigma = initial_sigma,
      fixed_sigma = fixed_sigma,
      history = do.call(rbind, history),
      centers = rowsum(x, cluster) / as.vector(table(cluster)),
      preprocessing_space = TRUE
    ),
    class = "kernel_xmeans_result"
  )
}
