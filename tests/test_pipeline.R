options(stringsAsFactors = FALSE)

source(file.path("R", "01_prepare_data.R"), encoding = "UTF-8")
source(file.path("R", "02_analysis.R"), encoding = "UTF-8")

stopifnot(
  nrow(selected) == 39,
  sum(selected$sample_size) == 10011,
  sum(selected$effect_mean_imputed) == 1,
  sum(selected$manual_plus_005) == 10,
  sum(selected$correlation_only) == 13,
  abs(benchmark_observed$estimate_r - 0.3854763391) < 1e-9,
  abs(benchmark_corrected$estimate_r - 0.4652563256) < 1e-9,
  abs(benchmark_corrected$q - 1033.3337337) < 1e-6,
  abs(benchmark_corrected$i2_pct - 96.32258207) < 1e-6,
  abs(moderator_results$standardized_beta[1] - 0.2253213586) < 1e-9,
  abs(moderator_results$standardized_beta[2] + 0.0907567374) < 1e-9,
  moderator_results$p_value[3] > 0.05,
  moderator_results$p_value[4] > 0.05,
  omnibus_results$p_value[omnibus_results$moderator == "Continent"] > 0.05,
  omnibus_results$p_value[omnibus_results$moderator == "Industry"] > 0.05
)

required_outputs <- c(
  file.path("outputs", "tables", "model_summary.csv"),
  file.path("outputs", "tables", "moderator_results.csv"),
  file.path("outputs", "tables", "subgroup_results.csv"),
  file.path("outputs", "figures", "forest_plot_primary.png"),
  file.path("outputs", "figures", "funnel_plot_primary.png"),
  file.path("outputs", "figures", "meta_regression_year.png"),
  file.path("outputs", "figures", "meta_regression_uai.png"),
  "README.md"
)

stopifnot(all(file.exists(required_outputs)))
message("All pipeline regression checks passed.")

