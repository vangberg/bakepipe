library(targets)

list(
  tar_target(raw_data_csv, "raw_data.csv", format = "file"),
  tar_target(script_01_clean_data_r, "01_clean_data.R", format = "file"),
  tar_target(
    output_01_clean_data_r,
    {
      script_01_clean_data_r
      raw_data_csv
      source("01_clean_data.R")
      c("cleaned_data.csv")
    }
  ),
  tar_target(script_02_analyze_data_r, "02_analyze_data.R", format = "file"),
  tar_target(
    output_02_analyze_data_r,
    {
      script_02_analyze_data_r
      output_01_clean_data_r
      source("02_analyze_data.R")
      c("analysis_results.rds")
    }
  ),
  tar_target(script_03_generate_report_r, "03_generate_report.R", format = "file"),
  tar_target(
    output_03_generate_report_r,
    {
      script_03_generate_report_r
      output_02_analyze_data_r
      source("03_generate_report.R")
      c("report.txt")
    }
  )
)
