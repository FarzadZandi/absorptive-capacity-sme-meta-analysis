library(metafor)

meta_essentials_random <- function(effect, sample_size, label) {
  yi <- atanh(effect)
  vi <- 1 / (sample_size - 3)
  fixed_weights <- 1 / vi
  fixed_mean <- sum(fixed_weights * yi) / sum(fixed_weights)
  q <- sum(fixed_weights * (yi - fixed_mean)^2)
  df <- length(yi) - 1
  c_value <- sum(fixed_weights) -
    sum(fixed_weights^2) / sum(fixed_weights)
  tau2 <- max(0, (q - df) / c_value)
  random_weights <- 1 / (vi + tau2)
  estimate <- sum(random_weights * yi) / sum(random_weights)

  weighted_variance_se <- sqrt(
    sum(random_weights * (yi - estimate)^2) /
      (df * sum(random_weights))
  )
  critical_value <- qt(0.975, df = df)
  ci <- estimate + c(-1, 1) * critical_value * weighted_variance_se
  prediction <- estimate + c(-1, 1) * critical_value *
    sqrt(tau2 + weighted_variance_se^2)

  data.frame(
    analysis = label,
    estimator = "Meta-Essentials-compatible DL random effects",
    k = length(effect),
    total_n = sum(sample_size),
    estimate_z = estimate,
    estimate_r = tanh(estimate),
    ci_lower_r = tanh(ci[1]),
    ci_upper_r = tanh(ci[2]),
    pi_lower_r = tanh(prediction[1]),
    pi_upper_r = tanh(prediction[2]),
    tau2_z = tau2,
    q = q,
    q_df = df,
    q_p = pchisq(q, df = df, lower.tail = FALSE),
    i2_pct = max(0, (q - df) / q) * 100,
    p_value = 2 * pt(
      abs(estimate / weighted_variance_se),
      df = df,
      lower.tail = FALSE
    ),
    stringsAsFactors = FALSE
  )
}

fit_reml_knha <- function(data, effect_column, label) {
  yi <- atanh(data[[effect_column]])
  vi <- 1 / (data$sample_size - 3)
  fit <- rma.uni(yi = yi, vi = vi, method = "REML", test = "knha")
  pred <- predict(fit, transf = tanh)

  row <- data.frame(
    analysis = label,
    estimator = "REML random effects with Knapp-Hartung inference",
    k = fit$k,
    total_n = sum(data$sample_size),
    estimate_z = as.numeric(fit$b[1]),
    estimate_r = tanh(as.numeric(fit$b[1])),
    ci_lower_r = tanh(fit$ci.lb),
    ci_upper_r = tanh(fit$ci.ub),
    pi_lower_r = as.numeric(pred$pi.lb),
    pi_upper_r = as.numeric(pred$pi.ub),
    tau2_z = fit$tau2,
    q = fit$QE,
    q_df = fit$k - 1,
    q_p = fit$QEp,
    i2_pct = fit$I2,
    p_value = fit$pval,
    stringsAsFactors = FALSE
  )

  list(row = row, fit = fit)
}

benchmark_observed <- meta_essentials_random(
  selected$effect_observed,
  selected$sample_size,
  "Submitted benchmark: observed effects"
)

benchmark_corrected <- meta_essentials_random(
  selected$effect_corrected,
  selected$sample_size,
  "Submitted benchmark: reliability-corrected effects"
)

primary_data <- selected[selected$primary_analysis, , drop = FALSE]
no_manual_data <- selected[selected$no_manual_adjustment, , drop = FALSE]
correlation_data <- selected[selected$correlation_only, , drop = FALSE]
reported_reliability_data <- selected[
  selected$reported_reliability_only,
  ,
  drop = FALSE
]

primary_result <- fit_reml_knha(
  primary_data,
  "effect_observed",
  "Primary audited model: remove mean-imputed outcome"
)

no_manual_result <- fit_reml_knha(
  no_manual_data,
  "effect_observed",
  "Sensitivity: also remove documented +0.05 adjustments"
)

correlation_result <- fit_reml_knha(
  correlation_data,
  "effect_observed",
  "Sensitivity: clearly documented correlations only"
)

reliability_result <- fit_reml_knha(
  reported_reliability_data,
  "effect_corrected",
  "Sensitivity: corrected effects with reported reliabilities only"
)

model_summary <- rbind(
  benchmark_observed,
  benchmark_corrected,
  primary_result$row,
  no_manual_result$row,
  correlation_result$row,
  reliability_result$row
)

fixed_weighted_moderator <- function(data, moderator, label) {
  y <- data$yi_observed
  x <- data[[moderator]]
  w <- 1 / data$vi
  keep <- is.finite(y) & is.finite(x) & is.finite(w)
  y <- y[keep]
  x <- x[keep]
  w <- w[keep]
  design <- cbind(1, x)
  bread <- solve(crossprod(design, w * design))
  coefficients <- bread %*% crossprod(design, w * y)
  se <- sqrt(diag(bread))
  z_value <- coefficients[2] / se[2]
  weighted_x_mean <- sum(w * x) / sum(w)
  weighted_y_mean <- sum(w * y) / sum(w)
  weighted_x_sd <- sqrt(sum(w * (x - weighted_x_mean)^2) / sum(w))
  weighted_y_sd <- sqrt(sum(w * (y - weighted_y_mean)^2) / sum(w))
  standardized_beta <- coefficients[2] * weighted_x_sd / weighted_y_sd

  data.frame(
    analysis = paste0("Submitted fixed-effect replication: ", label),
    moderator = label,
    k = length(y),
    slope_z_scale = as.numeric(coefficients[2]),
    standardized_beta = as.numeric(standardized_beta),
    test_statistic = as.numeric(z_value),
    df = NA_real_,
    p_value = 2 * pnorm(abs(z_value), lower.tail = FALSE),
    method = "Fixed-effect inverse-variance weighted regression",
    stringsAsFactors = FALSE
  )
}

fit_reml_moderator <- function(data, moderator, label) {
  keep <- is.finite(data[[moderator]])
  analysis_data <- data[keep, , drop = FALSE]
  fit <- rma.uni(
    yi = analysis_data$yi_observed,
    vi = analysis_data$vi,
    mods = as.formula(paste("~", moderator)),
    data = analysis_data,
    method = "REML",
    test = "knha"
  )

  data.frame(
    analysis = paste0("Audited random-effects model: ", label),
    moderator = label,
    k = fit$k,
    slope_z_scale = as.numeric(fit$b[2]),
    standardized_beta = NA_real_,
    test_statistic = as.numeric(fit$zval[2]),
    df = fit$ddf,
    p_value = as.numeric(fit$pval[2]),
    method = "REML meta-regression with Knapp-Hartung inference",
    stringsAsFactors = FALSE
  )
}

moderator_results <- rbind(
  fixed_weighted_moderator(selected, "data_year", "Data-collection year"),
  fixed_weighted_moderator(selected, "uncertainty_avoidance", "Uncertainty avoidance"),
  fit_reml_moderator(primary_data, "data_year", "Data-collection year"),
  fit_reml_moderator(
    primary_data,
    "uncertainty_avoidance",
    "Uncertainty avoidance"
  )
)

fit_subgroup_models <- function(data, group_column, label) {
  groups <- sort(unique(data[[group_column]]))
  rows <- lapply(groups, function(group_value) {
    group_data <- data[data[[group_column]] == group_value, , drop = FALSE]
    if (nrow(group_data) == 1) {
      estimate_z <- group_data$yi_observed[1]
      se_z <- sqrt(group_data$vi[1])
      ci_z <- estimate_z + c(-1, 1) * qnorm(0.975) * se_z
      return(data.frame(
        moderator = label,
        subgroup = group_value,
        k = 1,
        estimate_r = tanh(estimate_z),
        ci_lower_r = tanh(ci_z[1]),
        ci_upper_r = tanh(ci_z[2]),
        pi_lower_r = NA_real_,
        pi_upper_r = NA_real_,
        i2_pct = NA_real_,
        stringsAsFactors = FALSE
      ))
    }
    result <- fit_reml_knha(
      group_data,
      "effect_observed",
      paste(label, group_value, sep = ": ")
    )$row
    data.frame(
      moderator = label,
      subgroup = group_value,
      k = result$k,
      estimate_r = result$estimate_r,
      ci_lower_r = result$ci_lower_r,
      ci_upper_r = result$ci_upper_r,
      pi_lower_r = result$pi_lower_r,
      pi_upper_r = result$pi_upper_r,
      i2_pct = result$i2_pct,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

fit_omnibus <- function(data, group_column, label) {
  group_factor <- factor(data[[group_column]])
  fit <- rma.uni(
    yi = data$yi_observed,
    vi = data$vi,
    mods = ~ group_factor,
    method = "REML",
    test = "knha"
  )
  data.frame(
    moderator = label,
    k = fit$k,
    test_statistic = fit$QM,
    df_num = fit$m,
    df_den = fit$ddf,
    p_value = fit$QMp,
    method = "REML omnibus moderator test with Knapp-Hartung inference",
    stringsAsFactors = FALSE
  )
}

subgroup_results <- rbind(
  fit_subgroup_models(primary_data, "continent_group", "Continent"),
  fit_subgroup_models(primary_data, "industry", "Industry")
)

omnibus_results <- rbind(
  fit_omnibus(primary_data, "continent_group", "Continent"),
  fit_omnibus(primary_data, "industry", "Industry")
)

egger_result <- regtest(
  primary_result$fit,
  model = "rma",
  predictor = "sei"
)
trimfill_result <- trimfill(primary_result$fit)
primary_prediction <- predict(primary_result$fit, transf = tanh)

publication_bias_results <- data.frame(
  analysis = c("Egger regression", "Trim-and-fill"),
  estimate = c(as.numeric(egger_result$est), tanh(as.numeric(trimfill_result$b[1]))),
  statistic = c(as.numeric(egger_result$zval), NA_real_),
  p_value = c(as.numeric(egger_result$pval), NA_real_),
  imputed_studies = c(NA_real_, trimfill_result$k0),
  note = c(
    "Exploratory because heterogeneity is very high.",
    "Exploratory adjustment; not evidence that missingness mechanism is correct."
  ),
  stringsAsFactors = FALSE
)

influence_result <- influence(primary_result$fit)
influence_table <- data.frame(
  study = primary_data$study,
  standardized_residual = influence_result$inf$rstudent,
  dffits = influence_result$inf$dffits,
  cook_distance = influence_result$inf$cook.d,
  covariance_ratio = influence_result$inf$cov.r,
  hat = influence_result$inf$hat,
  influential = influence_result$is.infl,
  stringsAsFactors = FALSE
)

leave_one_out <- leave1out(primary_result$fit, transf = tanh)
leave_one_out_table <- data.frame(
  study_removed = primary_data$study,
  estimate_r = leave_one_out$estimate,
  ci_lower_r = leave_one_out$ci.lb,
  ci_upper_r = leave_one_out$ci.ub,
  q = leave_one_out$Q,
  q_p = leave_one_out$Qp,
  i2_pct = leave_one_out$I2,
  stringsAsFactors = FALSE
)
