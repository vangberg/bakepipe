library(targets)
library(callr)

list(
  tar_target(script_01_clean_data_r, "01_clean_data.R", format = "file"),
  tar_target(raw_data_csv, "raw_data.csv", format = "file"),
  tar_target(
    run_01_clean_data_r,
    {
      script_01_clean_data_r
      raw_data_csv
      callr::r(
        func = function(script_path) {
          source(script_path, local = TRUE)
        },
        args = list(script_path = "01_clean_data.R")
      )
      TRUE
    }
  ),
  tar_target(cleaned_data_csv, { run_01_clean_data_r; "cleaned_data.csv" }, format = "file"),
  tar_target(script_02_analyze_data_r, "02_analyze_data.R", format = "file"),
  tar_target(
    run_02_analyze_data_r,
    {
      script_02_analyze_data_r
      cleaned_data_csv
      callr::r(
        func = function(script_path) {
          source(script_path, local = TRUE)
        },
        args = list(script_path = "02_analyze_data.R")
      )
      TRUE
    }
  ),
  tar_target(analysis_results_rds, { run_02_analyze_data_r; "analysis_results.rds" }, format = "file"),
  tar_target(script_03_generate_report_r, "03_generate_report.R", format = "file"),
  tar_target(
    run_03_generate_report_r,
    {
      script_03_generate_report_r
      analysis_results_rds
      callr::r(
        func = function(script_path) {
          source(script_path, local = TRUE)
        },
        args = list(script_path = "03_generate_report.R")
      )
      TRUE
    }
  ),
  tar_target(report_txt, { run_03_generate_report_r; "report.txt" }, format = "file"),
  tar_target(script_targets_r, "_targets.R", format = "file"),
  tar_target(
    run_targets_r,
    {
      script_targets_r
      callr::r(
        func = function(script_path) {
          source(script_path, local = TRUE)
        },
        args = list(script_path = "_targets.R")
      )
      TRUE
    }
  )
)
