# ANN utilities reconstructed from the recovered 2018 development source.
#
# The original monolithic script uses RSNNS::mlp, nested train/validation/test
# folds, class-wise IQR candidate screening, 1-NN editing, a historical class-
# balancing rule, and validation-based architecture selection. These helpers
# preserve that study design while replacing system-time RNG resets with one
# explicit seed so cleaned reruns are deterministic.

require_ann_packages <- function() {
  missing <- c("RSNNS", "kknn", "caret")[
    !vapply(c("RSNNS", "kknn", "caret"), requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(missing) > 0L) {
    stop("Missing ANN dependencies: ", paste(missing, collapse = ", "))
  }
}

make_validation_fold_map <- function(k = 10L) {
  # Paper-oriented version of the fold-picking logic recovered from neuralnet.R.
  # Each test fold receives a distinct validation fold, using the historical
  # per-fold seeds. The explicit single-candidate branch avoids R's sample(n, 1)
  # shorthand, which would otherwise interpret a lone numeric fold ID as 1:n.
  pick <- seq_len(k)
  validation <- integer(k)
  for (j in seq_len(k)) {
    set.seed(j * 37L)
    if (j < k) {
      choices <- pick[pick != j]
      if (length(choices) == 0L) stop("No validation-fold candidate remains.")
      f <- if (length(choices) == 1L) choices[1L] else sample(choices, 1L)
    } else {
      f <- pick[1L]
    }
    validation[j] <- f
    pick <- pick[pick != f]
  }
  validation
}

flag_iqr_candidates <- function(train, inputs, output) {
  check_inputs <- setdiff(inputs, "Depth_m")
  flagged <- logical(nrow(train))
  for (class_value in sort(unique(train[[output]]))) {
    idx <- which(train[[output]] == class_value)
    if (length(idx) < 4L) next
    for (feature in check_inputs) {
      q <- stats::quantile(train[idx, feature], probs = c(0.25, 0.75), na.rm = TRUE, names = FALSE)
      iqr <- q[2] - q[1]
      flagged[idx] <- flagged[idx] |
        train[idx, feature] < (q[1] - 1.5 * iqr) |
        train[idx, feature] > (q[2] + 1.5 * iqr)
    }
  }
  which(flagged)
}

edit_iqr_candidates_1nn <- function(train, inputs, output) {
  require_ann_packages()
  candidates <- flag_iqr_candidates(train, inputs, output)
  if (length(candidates) == 0L) return(train)

  remove <- logical(nrow(train))
  formula <- stats::as.formula(paste(output, "~", paste(inputs, collapse = "+")))
  # Evaluate each candidate against the same unmodified training snapshot. This
  # avoids the index-shift side effect present in the interactive historical
  # script while retaining the intended leave-one-out 1-NN editing rule.
  for (row_id in candidates) {
    fit <- kknn::kknn(
      formula = formula,
      train = train[-row_id, c(inputs, output), drop = FALSE],
      test = train[row_id, c(inputs, output), drop = FALSE],
      k = 1,
      distance = 2,
      kernel = "rectangular",
      scale = FALSE
    )
    pred <- as.character(fit$fitted.values[1])
    remove[row_id] <- pred != as.character(train[[output]][row_id])
  }
  train[!remove, , drop = FALSE]
}

balance_historical_mean <- function(train, inputs, output, minimum_per_class = 1000L, seed = 2020L) {
  set.seed(seed)
  classes <- sort(unique(train[[output]]))
  counts <- vapply(classes, function(cl) sum(train[[output]] == cl), integer(1))
  target <- max(as.integer(minimum_per_class), 2L * min(counts))
  pieces <- vector("list", length(classes))

  for (i in seq_along(classes)) {
    cl <- classes[i]
    class_data <- train[train[[output]] == cl, , drop = FALSE]
    n <- nrow(class_data)
    if (n > target) {
      pieces[[i]] <- class_data[sample.int(n, target), , drop = FALSE]
    } else if (n < target) {
      synthetic <- vector("list", target - n)
      draw_size <- length(inputs) + 1L
      if (n < draw_size) stop("Class has too few rows for the historical balancing rule.")
      for (j in seq_along(synthetic)) {
        idx <- sample.int(n, draw_size, replace = FALSE)
        row <- class_data[1L, , drop = FALSE]
        for (feature in inputs) row[[feature]] <- mean(class_data[idx, feature])
        row[[output]] <- cl
        synthetic[[j]] <- row
      }
      pieces[[i]] <- rbind(class_data, do.call(rbind, synthetic))
    } else {
      pieces[[i]] <- class_data
    }
  }
  out <- do.call(rbind, pieces)
  rownames(out) <- NULL
  out
}

fit_ann_scaler <- function(train, inputs) fit_minmax(train, inputs)

apply_ann_scaler <- function(data, scaler) {
  out <- data
  out[scaler$inputs] <- as.data.frame(apply_minmax(data, scaler))
  out
}

prediction_classes <- function(scores, class_levels) {
  idx <- max.col(as.matrix(scores), ties.method = "first")
  class_levels[idx]
}

fit_mlp <- function(x, y, hidden, iterations) {
  require_ann_packages()
  RSNNS::mlp(
    x = as.matrix(x),
    y = as.matrix(y),
    size = hidden,
    maxit = as.integer(iterations),
    hiddenActFunc = "Act_Logistic",
    outputActFunc = "Act_Logistic"
  )
}

evaluate_mlp <- function(model, x, truth, class_levels) {
  scores <- stats::predict(model, as.matrix(x))
  pred <- prediction_classes(scores, class_levels)
  mean_class_recall(truth, pred)
}

tune_ann <- function(train,
                     validation,
                     inputs,
                     output,
                     seed = 2020L,
                     max_hidden_multiplier = 2L,
                     iteration_step = 200L,
                     max_iterations = 4000L) {
  require_ann_packages()
  class_levels <- sort(unique(train[[output]]))
  y_train <- one_hot(train[[output]], class_levels)
  n_classes <- length(class_levels)

  # Recover the original iteration search: start at 200 and stop after the
  # first non-improvement, retaining the previous value.
  best_iterations <- iteration_step
  best_score <- -Inf
  for (iterations in seq(iteration_step, max_iterations, by = iteration_step)) {
    set.seed(seed + iterations)
    model <- fit_mlp(train[inputs], y_train, hidden = n_classes, iterations = iterations)
    score <- evaluate_mlp(model, validation[inputs], validation[[output]], class_levels)
    if (score <= best_score) break
    best_score <- score
    best_iterations <- iterations
  }

  hidden_candidates <- seq_len(max_hidden_multiplier * n_classes)
  first_scores <- numeric(length(hidden_candidates))
  for (i in seq_along(hidden_candidates)) {
    n <- hidden_candidates[i]
    set.seed(seed + 10000L + n)
    model <- fit_mlp(train[inputs], y_train, hidden = n, iterations = best_iterations)
    first_scores[i] <- evaluate_mlp(model, validation[inputs], validation[[output]], class_levels)
  }
  n_best <- hidden_candidates[which.max(first_scores)]

  second_scores <- numeric(length(hidden_candidates))
  for (i in seq_along(hidden_candidates)) {
    m <- hidden_candidates[i]
    set.seed(seed + 20000L + m)
    model <- fit_mlp(train[inputs], y_train, hidden = c(n_best, m), iterations = best_iterations)
    second_scores[i] <- evaluate_mlp(model, validation[inputs], validation[[output]], class_levels)
  }
  m_best <- hidden_candidates[which.max(second_scores)]
  if (max(second_scores) <= max(first_scores)) m_best <- 0L

  list(
    first_hidden = n_best,
    second_hidden = m_best,
    iterations = best_iterations,
    validation_score = max(max(first_scores), max(second_scores)),
    class_levels = class_levels
  )
}

evaluate_ann_cv <- function(data,
                            inputs,
                            output = "cluster",
                            folds = 10L,
                            seed = 2020L,
                            minimum_per_class = 1000L,
                            max_iterations = 4000L) {
  require_ann_packages()
  set.seed(seed)
  fold_indices <- caret::createFolds(factor(data[[output]]), k = folds, list = TRUE, returnTrain = FALSE)
  validation_map <- make_validation_fold_map(folds)
  results <- vector("list", folds)

  for (i in seq_len(folds)) {
    test_idx <- fold_indices[[i]]
    valid_idx <- fold_indices[[validation_map[i]]]
    train_idx <- setdiff(seq_len(nrow(data)), c(test_idx, valid_idx))

    train <- data[train_idx, c(inputs, output), drop = FALSE]
    validation <- data[valid_idx, c(inputs, output), drop = FALSE]
    test <- data[test_idx, c(inputs, output), drop = FALSE]

    first_scaler <- fit_minmax(train, inputs)
    train[inputs] <- as.data.frame(signed_log_map(apply_minmax(train, first_scaler)))
    validation[inputs] <- as.data.frame(signed_log_map(apply_minmax(validation, first_scaler)))
    test[inputs] <- as.data.frame(signed_log_map(apply_minmax(test, first_scaler)))

    train[[output]] <- factor(train[[output]])
    validation[[output]] <- factor(validation[[output]], levels = levels(train[[output]]))
    test[[output]] <- factor(test[[output]], levels = levels(train[[output]]))

    train <- edit_iqr_candidates_1nn(train, inputs, output)
    balanced <- balance_historical_mean(
      train, inputs, output,
      minimum_per_class = minimum_per_class,
      seed = seed + i * 1000L
    )

    second_scaler <- fit_ann_scaler(balanced, inputs)
    balanced <- apply_ann_scaler(balanced, second_scaler)
    validation <- apply_ann_scaler(validation, second_scaler)
    test <- apply_ann_scaler(test, second_scaler)

    tuning <- tune_ann(
      balanced, validation, inputs, output,
      seed = seed + i * 10000L,
      max_iterations = max_iterations
    )
    hidden <- tuning$first_hidden
    if (tuning$second_hidden > 0L) hidden <- c(hidden, tuning$second_hidden)
    y_train <- one_hot(balanced[[output]], tuning$class_levels)
    set.seed(seed + i * 20000L)
    model <- fit_mlp(balanced[inputs], y_train, hidden, tuning$iterations)
    score <- evaluate_mlp(model, test[inputs], test[[output]], tuning$class_levels)

    results[[i]] <- data.frame(
      fold = i,
      validation_fold = validation_map[i],
      first_hidden = tuning$first_hidden,
      second_hidden = tuning$second_hidden,
      iterations = tuning$iterations,
      accuracy = 100 * score
    )
  }

  detail <- do.call(rbind, results)
  list(
    detail = detail,
    mean_accuracy = mean(detail$accuracy),
    sd_accuracy = stats::sd(detail$accuracy)
  )
}
