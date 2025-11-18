library(targets)
library(callr)

list(
  tar_target(script_01_process_r, "01_process.R", format = "file"),
  tar_target(input_csv, "input.csv", format = "file"),
  tar_target(
    run_01_process_r,
    {
      script_01_process_r
      input_csv
      callr::r(
        func = function(script_path) {
          source(script_path, local = TRUE)
        },
        args = list(script_path = "01_process.R")
      )
      TRUE
    }
  ),
  tar_target(output_01_process_r, { run_01_process_r; c("processed.csv") }, format = "file"),
  tar_target(script_02_summarize_r, "02_summarize.R", format = "file"),
  tar_target(
    run_02_summarize_r,
    {
      script_02_summarize_r
      output_01_process_r
      callr::r(
        func = function(script_path) {
          source(script_path, local = TRUE)
        },
        args = list(script_path = "02_summarize.R")
      )
      TRUE
    }
  ),
  tar_target(output_02_summarize_r, { run_02_summarize_r; c("summary.csv") }, format = "file")
)
