library(targets)

list(
  tar_target(raw_data_csv, "raw_data.csv", format = "file"),
  tar_target(script_01_clean_data_r, "01_clean_data.R", format = "file"),
  tar_target(
    output_01_clean_data_r,
    {
      script_01_clean_data_r
      raw_data_csv
      callr::r(
        func = function(script_path) {
          source(script_path, local = TRUE)
        },
        args = list(script_path = "01_clean_data.R")
      )
      c("cleaned_data.csv")
    },
    format = "file"
  ),
  tar_target(script_02_analyze_data_r, "02_analyze_data.R", format = "file"),
  tar_target(
    output_02_analyze_data_r,
    {
      script_02_analyze_data_r
      output_01_clean_data_r
      callr::r(
        func = function(script_path) {
          source(script_path, local = TRUE)
        },
        args = list(script_path = "02_analyze_data.R")
      )
      c("analysis_results.rds")
    },
    format = "file"
  ),
  tar_target(script_03_generate_report_r, "03_generate_report.R", format = "file"),
  tar_target(
    output_03_generate_report_r,
    {
      script_03_generate_report_r
      output_02_analyze_data_r
      callr::r(
        func = function(script_path) {
          source(script_path, local = TRUE)
        },
        args = list(script_path = "03_generate_report.R")
      )
      c("report.txt")
    },
    format = "file"
  )
)
