source_file <- file.path(
  "archive", "original-project",
  "Sayar, Zandi, Türesin, AlMghawish_coding.xlsx"
)

if (!file.exists(source_file)) {
  stop("Source workbook not found: ", source_file)
}

dir.create(file.path("data", "processed"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path("outputs", "tables"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path("outputs", "figures"), recursive = TRUE, showWarnings = FALSE)

selected_raw <- readxl::read_excel(
  source_file,
  sheet = "Articles Selected",
  range = "A1:Y40",
  .name_repair = "minimal"
)

screening_raw <- readxl::read_excel(
  source_file,
  sheet = "Last Screening",
  range = "A1:AM71",
  .name_repair = "minimal"
)

selected <- data.frame(
  study = trimws(as.character(selected_raw[[1]])),
  publication_year = as.numeric(selected_raw[[2]]),
  journal = as.character(selected_raw[[3]]),
  journal_eigenfactor = as.numeric(selected_raw[[4]]),
  sample_size = as.numeric(selected_raw[[5]]),
  response_rate_pct = as.numeric(selected_raw[[6]]),
  firm_size_category = trimws(as.character(selected_raw[[7]])),
  firm_size_numeric = as.numeric(selected_raw[[8]]),
  firm_age = as.numeric(selected_raw[[9]]),
  data_year = as.numeric(selected_raw[[10]]),
  country = trimws(as.character(selected_raw[[11]])),
  continent = trimws(as.character(selected_raw[[12]])),
  motivation_success = as.numeric(selected_raw[[13]]),
  uncertainty_avoidance = as.numeric(selected_raw[[14]]),
  industry = trimws(as.character(selected_raw[[15]])),
  ac_measure = as.character(selected_raw[[16]]),
  ac_items = as.numeric(selected_raw[[17]]),
  ac_measure_type = trimws(as.character(selected_raw[[18]])),
  ac_reliability = as.numeric(selected_raw[[19]]),
  performance_measure = as.character(selected_raw[[20]]),
  performance_measure_type = trimws(as.character(selected_raw[[21]])),
  performance_items = as.numeric(selected_raw[[22]]),
  performance_reliability = as.numeric(selected_raw[[23]]),
  effect_observed = as.numeric(selected_raw[[24]]),
  effect_corrected_excel = as.numeric(selected_raw[[25]]),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

screening <- data.frame(
  study_key = tolower(trimws(as.character(screening_raw[[1]]))),
  include = toupper(trimws(as.character(screening_raw[[2]]))),
  screen_journal_eigenfactor = suppressWarnings(as.numeric(screening_raw[[5]])),
  screen_response_rate = suppressWarnings(as.numeric(screening_raw[[8]])),
  screen_firm_size_numeric = suppressWarnings(as.numeric(screening_raw[[11]])),
  screen_firm_age = suppressWarnings(as.numeric(screening_raw[[13]])),
  screen_ac_reliability = suppressWarnings(as.numeric(screening_raw[[29]])),
  screen_performance_reliability = suppressWarnings(as.numeric(screening_raw[[34]])),
  screen_effect = suppressWarnings(as.numeric(screening_raw[[36]])),
  effect_comment = as.character(screening_raw[[37]]),
  stringsAsFactors = FALSE
)

selected$study_key <- tolower(trimws(selected$study))
match_index <- match(selected$study_key, screening$study_key)

if (anyNA(match_index)) {
  stop("Selected studies could not all be matched to the screening sheet.")
}

selected$effect_comment <- screening$effect_comment[match_index]
selected$effect_comment[is.na(selected$effect_comment)] <- ""

normalise_comment <- function(x) {
  x <- tolower(x)
  x <- gsub("ß", "beta", x, fixed = TRUE)
  x <- gsub("β", "beta", x, fixed = TRUE)
  x
}

comment_norm <- normalise_comment(selected$effect_comment)

correlation_signal <- grepl(
  "correlation matrix|direct correlation|mean of the correlation|mean of the correlations|correlations of",
  comment_norm
)
regression_signal <- grepl(
  "beta|path coeff|indirect effect|direct effect|mediat",
  comment_norm
)

selected$effect_source_type <- ifelse(
  correlation_signal & regression_signal,
  "mixed_or_ambiguous",
  ifelse(
    correlation_signal,
    "correlation_or_mean_of_correlations",
    ifelse(regression_signal, "regression_or_path", "unclear")
  )
)

selected$manual_plus_005 <- grepl(
  "\\+\\s*0[\\.,]05|added\\s*0[\\.,]05|adding\\s*0[\\.,]05",
  comment_norm
)

screen_effect <- screening$screen_effect[match_index]
selected$effect_mean_imputed <-
  is.na(screen_effect) &
  abs(selected$effect_observed - mean(selected$effect_observed)) < 1e-12

selected$journal_eigenfactor_imputed <- is.na(
  screening$screen_journal_eigenfactor[match_index]
)
selected$response_rate_imputed <- is.na(
  screening$screen_response_rate[match_index]
)
selected$firm_size_imputed <- is.na(
  screening$screen_firm_size_numeric[match_index]
)
selected$firm_age_imputed <- is.na(screening$screen_firm_age[match_index])
selected$ac_reliability_imputed <- is.na(
  screening$screen_ac_reliability[match_index]
)
selected$performance_reliability_imputed <- is.na(
  screening$screen_performance_reliability[match_index]
)

selected$effect_corrected <- with(
  selected,
  effect_observed / sqrt(ac_reliability * performance_reliability)
)

if (!isTRUE(all.equal(
  selected$effect_corrected,
  selected$effect_corrected_excel,
  tolerance = 1e-12
))) {
  stop("The R reliability correction does not match the Excel formulas.")
}

selected$continent_group <- ifelse(
  selected$continent %in% c("Africa", "South America"),
  "Other",
  selected$continent
)

selected$primary_analysis <- !selected$effect_mean_imputed
selected$no_manual_adjustment <-
  selected$primary_analysis & !selected$manual_plus_005
selected$correlation_only <-
  selected$no_manual_adjustment &
  selected$effect_source_type == "correlation_or_mean_of_correlations"
selected$reported_reliability_only <-
  selected$primary_analysis &
  !selected$ac_reliability_imputed &
  !selected$performance_reliability_imputed

selected$yi_observed <- atanh(selected$effect_observed)
selected$yi_corrected <- atanh(selected$effect_corrected)
selected$vi <- 1 / (selected$sample_size - 3)

if (any(!is.finite(selected$yi_observed)) || any(selected$vi <= 0)) {
  stop("Invalid correlation or sample size found in the analysis data.")
}

write.csv(
  selected,
  file.path("data", "processed", "study_level_data.csv"),
  row.names = FALSE,
  na = ""
)

audit_summary <- data.frame(
  issue = c(
    "Candidate studies screened",
    "Studies included in submitted analysis",
    "Grand-mean-imputed outcomes",
    "Documented +0.05 adjustments",
    "Effects classified as correlations",
    "Effects classified as regression/path coefficients",
    "Effects with mixed or ambiguous descriptions",
    "Effects with unclear provenance",
    "Imputed ACAP reliabilities",
    "Imputed performance reliabilities",
    "Imputed firm ages",
    "Imputed numeric firm sizes"
  ),
  n = c(
    nrow(screening),
    nrow(selected),
    sum(selected$effect_mean_imputed),
    sum(selected$manual_plus_005),
    sum(selected$effect_source_type == "correlation_or_mean_of_correlations"),
    sum(selected$effect_source_type == "regression_or_path"),
    sum(selected$effect_source_type == "mixed_or_ambiguous"),
    sum(selected$effect_source_type == "unclear"),
    sum(selected$ac_reliability_imputed),
    sum(selected$performance_reliability_imputed),
    sum(selected$firm_age_imputed),
    sum(selected$firm_size_imputed)
  ),
  stringsAsFactors = FALSE
)

write.csv(
  audit_summary,
  file.path("outputs", "tables", "data_audit_summary.csv"),
  row.names = FALSE
)

