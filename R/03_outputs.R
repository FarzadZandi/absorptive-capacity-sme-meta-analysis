table_dir <- file.path("outputs", "tables")
figure_dir <- file.path("outputs", "figures")

write.csv(model_summary, file.path(table_dir, "model_summary.csv"), row.names = FALSE)
write.csv(
  moderator_results,
  file.path(table_dir, "moderator_results.csv"),
  row.names = FALSE
)
write.csv(
  subgroup_results,
  file.path(table_dir, "subgroup_results.csv"),
  row.names = FALSE
)
write.csv(
  omnibus_results,
  file.path(table_dir, "subgroup_omnibus_tests.csv"),
  row.names = FALSE
)
write.csv(
  publication_bias_results,
  file.path(table_dir, "publication_bias_results.csv"),
  row.names = FALSE
)
write.csv(
  influence_table,
  file.path(table_dir, "influence_diagnostics.csv"),
  row.names = FALSE
)
write.csv(
  leave_one_out_table,
  file.path(table_dir, "leave_one_out.csv"),
  row.names = FALSE
)

png(
  file.path(figure_dir, "forest_plot_primary.png"),
  width = 1800,
  height = 2200,
  res = 180
)
par(mar = c(4, 4, 2, 2))
forest(
  primary_result$fit,
  slab = primary_data$study,
  transf = tanh,
  refline = 0,
  xlab = "Correlation",
  header = c("Study", "Correlation [95% CI]"),
  cex = 0.68,
  alim = c(-0.5, 1)
)
dev.off()

png(
  file.path(figure_dir, "funnel_plot_primary.png"),
  width = 1400,
  height = 1100,
  res = 180
)
funnel(
  primary_result$fit,
  yaxis = "sei",
  xlab = "Fisher's z",
  ylab = "Standard error",
  main = "Funnel plot: primary audited model"
)
dev.off()

png(
  file.path(figure_dir, "funnel_plot_trimfill.png"),
  width = 1400,
  height = 1100,
  res = 180
)
funnel(
  trimfill_result,
  yaxis = "sei",
  xlab = "Fisher's z",
  ylab = "Standard error",
  main = "Exploratory trim-and-fill analysis"
)
dev.off()

png(
  file.path(figure_dir, "baujat_plot.png"),
  width = 1400,
  height = 1100,
  res = 180
)
baujat(primary_result$fit, main = "Contribution to heterogeneity and pooled result")
dev.off()

plot_meta_regression <- function(data, moderator, title, xlab, filename) {
  keep <- is.finite(data[[moderator]])
  d <- data[keep, , drop = FALSE]
  fit <- rma.uni(
    yi = d$yi_observed,
    vi = d$vi,
    mods = as.formula(paste("~", moderator)),
    data = d,
    method = "REML",
    test = "knha"
  )
  png(file.path(figure_dir, filename), width = 1400, height = 1000, res = 180)
  regplot(
    fit,
    mod = 2,
    transf = tanh,
    xlab = xlab,
    ylab = "Correlation",
    main = title,
    psize = "seinv",
    shade = TRUE
  )
  abline(h = 0, lty = 3, col = "grey50")
  dev.off()
}

plot_meta_regression(
  primary_data,
  "data_year",
  "Data-collection year as a moderator",
  "Data-collection year",
  "meta_regression_year.png"
)

plot_meta_regression(
  primary_data,
  "uncertainty_avoidance",
  "Uncertainty avoidance as a moderator",
  "Uncertainty avoidance index",
  "meta_regression_uai.png"
)

session_lines <- capture.output(sessionInfo())
writeLines(session_lines, file.path("outputs", "session-info.txt"), useBytes = TRUE)
