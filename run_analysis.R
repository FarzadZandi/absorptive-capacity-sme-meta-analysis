#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE, scipen = 999)

required_packages <- c("readxl", "metafor")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  stop(
    "Missing packages: ", paste(missing_packages, collapse = ", "),
    ". Run renv::restore() before executing the analysis."
  )
}

source(file.path("R", "01_prepare_data.R"), encoding = "UTF-8")
source(file.path("R", "02_analysis.R"), encoding = "UTF-8")
source(file.path("R", "03_outputs.R"), encoding = "UTF-8")

message("Analysis complete. Results are in outputs/ and data/processed/.")

