library(testthat)
library(bakepipe)

# Helper to create a temporary test project directory
setup_test_proj <- function(path = "test_pipeline_project") {
  if (dir.exists(path)) {
    unlink(path, recursive = TRUE, force = TRUE)
  }
  dir.create(path, recursive = TRUE)
  return(normalizePath(path))
}

# Helper to create a script file within the test project
create_script <- function(proj_path, filename, content) {
  script_path <- file.path(proj_path, filename)
  writeLines(content, script_path)
  return(script_path)
}

test_that("file_in and file_out record dependencies", {
  reset_bakepipe_state()

  # Simulate being inside a run() call for a specific script
  .bakepipe_env$current_script_path <- "test_script.R"

  input_path <- file_in("input.csv")
  output_path <- file_out("output.csv")

  expect_equal(input_path, "input.csv")
  expect_equal(output_path, "output.csv")

  script_info <- .bakepipe_env$scripts[["test_script.R"]]
  expect_true("input.csv" %in% script_info$inputs)
  expect_true("output.csv" %in% script_info$outputs)

  reset_bakepipe_state() # Clean up
})

test_that("run executes scripts in correct order", {
  proj_path <- setup_test_proj()
  on.exit(unlink(proj_path, recursive = TRUE, force = TRUE), add = TRUE) # Cleanup after test

  # Create dummy files that would be inputs, to avoid script errors if they try to read them
  # This is not strictly necessary if scripts only declare file_in/file_out and don't read/write
  # For this test, our dummy scripts only declare.

  # Reset state before run
  reset_bakepipe_state()

  # Capture messages to infer order (less robust but simple)
  # A better way would be for scripts to write to a log file in order.
  # For now, we check if the execution completes and which files are reported.

  # The `run` function's topological sort should handle the order.
  # We expect "01_data_prep.R", "02_analysis.R", "03_visualization.R" to be in order.
  # "independent_script.R" can be anywhere as it has no dependencies with the main chain.

  # We need to check the order of execution more directly.
  # Modify scripts to record their execution.
  # Ensure log is clean relative to proj_path
  exec_log_path <- file.path(proj_path, "exec_log.txt")
  unlink(exec_log_path, force=TRUE)

  s1_path <- create_script(proj_path, "01_data_prep.R", paste0("file_out('data_intermediate.csv'); cat('01_data_prep\n', file='", exec_log_path, "', append=TRUE)"))
  s2_path <- create_script(proj_path, "02_analysis.R", paste0("file_in('data_intermediate.csv'); file_out('results.csv'); cat('02_analysis\n', file='", exec_log_path, "', append=TRUE)"))
  s3_path <- create_script(proj_path, "03_visualization.R", paste0("file_in('results.csv'); file_out('plot.png'); cat('03_visualization\n', file='", exec_log_path, "', append=TRUE)"))
  s_ind_path <- create_script(proj_path, "independent_script.R", paste0("file_out('other_output.txt'); cat('independent_script\n', file='", exec_log_path, "', append=TRUE)"))

  # Change working directory for the run, so it finds the scripts
  old_wd <- getwd()
  setwd(proj_path)
  on.exit(setwd(old_wd), add = TRUE) # Restore WD

  output_files <- suppressMessages(run(".")) # Run in current dir (proj_path)

  # Check execution order from log
  expect_true(file.exists(exec_log_path), info = "Execution log file was not created.")
  log_content <- readLines(exec_log_path)

  # Find positions of main chain scripts
  pos_01 <- which(log_content == "01_data_prep")
  pos_02 <- which(log_content == "02_analysis")
  pos_03 <- which(log_content == "03_visualization")

  expect_true(length(pos_01) > 0, info = "Script 01 did not run")
  expect_true(length(pos_02) > 0, info = "Script 02 did not run")
  expect_true(length(pos_03) > 0, info = "Script 03 did not run")

  expect_true(pos_01 < pos_02, info = "Script 01 did not run before Script 02")
  expect_true(pos_02 < pos_03, info = "Script 02 did not run before Script 03")

  # Check returned output files (order doesn't matter here, just presence)
  # Note: file paths in output_files will be normalized by run()
  expected_outputs_relative <- c("data_intermediate.csv", "results.csv", "plot.png", "other_output.txt")
  # Normalize expected_outputs to match the absolute paths returned by run()
  expected_outputs_abs <- normalizePath(expected_outputs_relative, winslash="/", mustWork=FALSE)

  expect_setequal(output_files, expected_outputs_abs)

  # Clean up execution log
  unlink(exec_log_path, force=TRUE)
})

test_that("run detects circular dependencies", {
  proj_path <- setup_test_proj("circular_proj")
  on.exit(unlink(proj_path, recursive = TRUE, force = TRUE), add = TRUE)

  create_script(proj_path, "script_A.R", "file_in('B_out.txt'); file_out('A_out.txt')")
  create_script(proj_path, "script_B.R", "file_in('A_out.txt'); file_out('B_out.txt')")

  old_wd <- getwd()
  setwd(proj_path)
  on.exit(setwd(old_wd), add = TRUE)

  reset_bakepipe_state()
  expect_error(suppressMessages(run(".")), "Circular dependency detected|Could not determine a valid execution order")
})

test_that("show function provides output", {
  proj_path <- setup_test_proj("show_proj")
  on.exit(unlink(proj_path, recursive = TRUE, force = TRUE), add = TRUE)

  # Need to use normalized paths for script names in checks, as that's what bakepipe stores
  s1_name <- normalizePath(create_script(proj_path, "s1.R", "file_out('out1.txt')"), winslash="/", mustWork=FALSE)
  s2_name <- normalizePath(create_script(proj_path, "s2.R", "file_in('out1.txt'); file_out('out2.txt')"), winslash="/", mustWork=FALSE)

  old_wd <- getwd()
  setwd(proj_path)
  on.exit(setwd(old_wd), add = TRUE)

  reset_bakepipe_state()

  # Option 1: Run 'run()' first to populate .bakepipe_env$scripts
  suppressMessages(run(".")) # Populate the internal state
  output_show_after_run <- capture.output(show("."), type="message")

  # Normalize script paths for matching, as they appear in .bakepipe_env$scripts
  # Grepl patterns need to be careful with path separators (use / or \\\\ for Windows)
  # Using file.path for script names in grepl might be safer if complex paths are an issue
  # For now, direct matching with expected normalized path.

  expect_true(any(grepl(paste0("Script: ", s1_name), output_show_after_run, fixed = TRUE)))
  expect_true(any(grepl("Outputs:", output_show_after_run, fixed = TRUE)))
  expect_true(any(grepl("- out1.txt", output_show_after_run, fixed = TRUE)))
  expect_true(any(grepl(paste0("Script: ", s2_name), output_show_after_run, fixed = TRUE)))
  expect_true(any(grepl("Inputs:", output_show_after_run, fixed = TRUE)))
  expect_true(any(grepl("- out1.txt", output_show_after_run, fixed = TRUE))) # s2 input
  expect_true(any(grepl("- out2.txt", output_show_after_run, fixed = TRUE))) # s2 output

  # Option 2: Test 'show()' when it has to parse itself
  reset_bakepipe_state() # Clear state so show() has to parse
  output_show_standalone <- capture.output(show("."), type="message")

  expect_true(any(grepl("Parsing scripts to detect dependencies", output_show_standalone, fixed = TRUE)))
  expect_true(any(grepl(paste0("Script: ", s1_name), output_show_standalone, fixed = TRUE)))
  expect_true(any(grepl("Outputs:", output_show_standalone, fixed = TRUE)))
  expect_true(any(grepl("- out1.txt", output_show_standalone, fixed = TRUE)))
})

# Test for scripts with no bakepipe declarations
test_that("run handles scripts with no bakepipe declarations gracefully", {
  proj_path <- setup_test_proj("no_declarations_proj")
  on.exit(unlink(proj_path, recursive = TRUE, force = TRUE), add = TRUE)

  create_script(proj_path, "plain_script.R", "a <- 1+1; print(a)")

  old_wd <- getwd()
  setwd(proj_path)
  on.exit(setwd(old_wd), add = TRUE)

  reset_bakepipe_state()

  output_files <- NULL
  # Check that the script itself is run if it's the only one, even with no declarations.
  # The current run() behavior is to message "No bakepipe declarations" and return empty.
  # If we wanted plain scripts to run, run() logic would need adjustment.
  # The test confirms current behavior.
  expect_message(output_files <- suppressMessages(run(".")), "No bakepipe declarations")
  expect_equal(length(output_files), 0)
})

test_that("run handles empty directory", {
  proj_path <- setup_test_proj("empty_proj")
  on.exit(unlink(proj_path, recursive = TRUE, force = TRUE), add = TRUE)

  old_wd <- getwd()
  setwd(proj_path)
  on.exit(setwd(old_wd), add = TRUE)

  reset_bakepipe_state()
  output_files <- NULL
  expect_message(output_files <- run("."), "No .R scripts found")
  expect_equal(length(output_files), 0)
})

test_that("file_in/file_out warn when current_script_path is NULL", {
  reset_bakepipe_state()
  expect_warning(file_in("input.csv"), "file_in() called outside of a script run")
  expect_warning(file_out("output.csv"), "file_out() called outside of a script run")
  # Check that no entries were made to .bakepipe_env$scripts
  expect_equal(length(.bakepipe_env$scripts), 0)
})
