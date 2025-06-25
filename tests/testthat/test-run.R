test_that("run() executes scripts in topological order", {
  temp_dir <- tempdir()
  old_wd <- getwd()
  setwd(temp_dir)

  writeLines("# Bakepipe root marker", "_bakepipe.R")

  writeLines("data,value\nA,1\nB,2", "input.csv")

  script1_content <- '
library(bakepipe)
data <- read.csv(external_in("input.csv"))
data$processed <- data$value * 2
write.csv(data, file_out("intermediate.csv"), row.names = FALSE)
'
  writeLines(script1_content, "01_process.R")

  script2_content <- '
library(bakepipe)
data <- read.csv(file_in("intermediate.csv"))
summary_data <- data.frame(total = sum(data$processed))
write.csv(summary_data, file_out("final.csv"), row.names = FALSE)
'
  writeLines(script2_content, "02_summarize.R")

  on.exit({
    setwd(old_wd)
    unlink(c(file.path(temp_dir, "_bakepipe.R"),
             file.path(temp_dir, "input.csv"),
             file.path(temp_dir, "01_process.R"),
             file.path(temp_dir, "02_summarize.R"),
             file.path(temp_dir, "intermediate.csv"),
             file.path(temp_dir, "final.csv")))
  })

  result <- capture.output({result_value <- run()}); result <- result_value

  expect_true(file.exists("intermediate.csv"))
  expect_true(file.exists("final.csv"))

  final_data <- read.csv("final.csv")
  expect_equal(final_data$total, 6)

  expect_type(result, "character")
  expect_true("intermediate.csv" %in% result)
  expect_true("final.csv" %in% result)
})

test_that("run() returns empty vector when no scripts exist", {
  temp_dir <- tempdir()
  old_wd <- getwd()
  setwd(temp_dir)

  writeLines("# Bakepipe root marker", "_bakepipe.R")

  on.exit({
    setwd(old_wd)
    unlink(file.path(temp_dir, "_bakepipe.R"))
  })

  result <- capture.output({result_value <- run()}); result <- result_value
  expect_type(result, "character")
  expect_length(result, 0)
})

test_that("run() handles scripts with no outputs", {
  temp_dir <- tempdir()
  old_wd <- getwd()
  setwd(temp_dir)

  writeLines("# Bakepipe root marker", "_bakepipe.R")

  writeLines("data,value\nA,1\nB,2", "input.csv")

  script_content <- '
library(bakepipe)
data <- read.csv(external_in("input.csv"))
'
  writeLines(script_content, "process.R")

  on.exit({
    setwd(old_wd)
    unlink(c(file.path(temp_dir, "_bakepipe.R"),
             file.path(temp_dir, "input.csv"),
             file.path(temp_dir, "process.R")))
  })

  result <- capture.output({result_value <- run()}); result <- result_value
  expect_type(result, "character")
  expect_length(result, 0)
})

test_that("run() stops on script execution error", {
  temp_dir <- file.path(tempdir(), "test_script_error")
  dir.create(temp_dir, showWarnings = FALSE)
  old_wd <- getwd()
  setwd(temp_dir)

  writeLines("# Bakepipe root marker", "_bakepipe.R")

  script_content <- '
library(bakepipe)
stop("Script error for testing")
'
  writeLines(script_content, "error_script.R")

  on.exit({
    setwd(old_wd)
    unlink(c(file.path(temp_dir, "_bakepipe.R"),
             file.path(temp_dir, "error_script.R"),
             file.path(temp_dir, ".bakepipe.state")))
  })

  # Test that an error occurs, but be more flexible about the exact message
  # since callr may wrap the error differently
  expect_error(capture.output(run()), "Error executing script.*error_script.R")
})

test_that("run() respects dependency order", {
  temp_dir <- file.path(tempdir(), "test_dependency_order")
  dir.create(temp_dir, showWarnings = FALSE)
  old_wd <- getwd()
  setwd(temp_dir)

  writeLines("# Bakepipe root marker", "_bakepipe.R")

  writeLines("1,2,3", "data.csv")

  script1_content <- '
library(bakepipe)
data <- readLines(external_in("data.csv"))
writeLines(paste("step1:", data), file_out("step1.txt"))
'
  writeLines(script1_content, "01_first.R")

  script2_content <- '
library(bakepipe)
data <- readLines(file_in("step1.txt"))
writeLines(paste("step2:", data), file_out("step2.txt"))
'
  writeLines(script2_content, "02_second.R")

  on.exit({
    setwd(old_wd)
    unlink(c(file.path(temp_dir, "_bakepipe.R"),
             file.path(temp_dir, "data.csv"),
             file.path(temp_dir, "01_first.R"),
             file.path(temp_dir, "02_second.R"),
             file.path(temp_dir, "step1.txt"),
             file.path(temp_dir, "step2.txt"),
             file.path(temp_dir, ".bakepipe.state")))
  })

  result <- capture.output({result_value <- run()}); result <- result_value

  expect_true(file.exists("step1.txt"))
  expect_true(file.exists("step2.txt"))

  step2_content <- readLines("step2.txt")
  expect_true(grepl("step2: step1: 1,2,3", step2_content))

  expect_true("step1.txt" %in% result)
  expect_true("step2.txt" %in% result)
})

test_that("run() performs incremental execution based on state", {
  temp_dir <- file.path(tempdir(), "test_incremental_execution")
  dir.create(temp_dir, showWarnings = FALSE)
  old_wd <- getwd()
  setwd(temp_dir)

  writeLines("# Bakepipe root marker", "_bakepipe.R")
  writeLines("data,value\nA,1\nB,2", "input.csv")

  script1_content <- '
library(bakepipe)
data <- read.csv(external_in("input.csv"))
data$processed <- data$value * 2
write.csv(data, file_out("intermediate.csv"), row.names = FALSE)
'
  writeLines(script1_content, "01_process.R")

  script2_content <- '
library(bakepipe)
data <- read.csv(file_in("intermediate.csv"))
summary_data <- data.frame(total = sum(data$processed))
write.csv(summary_data, file_out("final.csv"), row.names = FALSE)
'
  writeLines(script2_content, "02_summarize.R")

  on.exit({
    setwd(old_wd)
    unlink(c(file.path(temp_dir, "_bakepipe.R"),
             file.path(temp_dir, "input.csv"),
             file.path(temp_dir, "01_process.R"),
             file.path(temp_dir, "02_summarize.R"),
             file.path(temp_dir, "intermediate.csv"),
             file.path(temp_dir, "final.csv"),
             file.path(temp_dir, ".bakepipe.state")))
  })

  # First run - should run all scripts and create state file
  result1 <- capture.output({result1_value <- run()}); result1 <- result1_value
  expect_true(file.exists(".bakepipe.state"))
  expect_true(file.exists("intermediate.csv"))
  expect_true(file.exists("final.csv"))

  # Second run without changes - should run no scripts
  # We can't easily test console output, but we can test that files aren't recreated
  initial_intermediate_time <- file.info("intermediate.csv")$mtime
  initial_final_time <- file.info("final.csv")$mtime
  
  Sys.sleep(1) # Ensure time difference would be detectable
  
  result2 <- capture.output({result2_value <- run()}); result2 <- result2_value
  
  # Files should not have been recreated (same modification times)
  expect_equal(file.info("intermediate.csv")$mtime, initial_intermediate_time)
  expect_equal(file.info("final.csv")$mtime, initial_final_time)
  
  # Should return empty vector since no files were created
  expect_length(result2, 0)
})

test_that("run() detects changes and re-runs affected scripts", {
  temp_dir <- file.path(tempdir(), "test_change_detection")
  dir.create(temp_dir, showWarnings = FALSE)
  old_wd <- getwd()
  setwd(temp_dir)

  writeLines("# Bakepipe root marker", "_bakepipe.R")
  writeLines("data,value\nA,1\nB,2", "input.csv")

  script1_content <- '
library(bakepipe)
data <- read.csv(external_in("input.csv"))
data$processed <- data$value * 2
write.csv(data, file_out("intermediate.csv"), row.names = FALSE)
'
  writeLines(script1_content, "01_process.R")

  script2_content <- '
library(bakepipe)
data <- read.csv(file_in("intermediate.csv"))
summary_data <- data.frame(total = sum(data$processed))
write.csv(summary_data, file_out("final.csv"), row.names = FALSE)
'
  writeLines(script2_content, "02_summarize.R")

  on.exit({
    setwd(old_wd)
    unlink(c(file.path(temp_dir, "_bakepipe.R"),
             file.path(temp_dir, "input.csv"),
             file.path(temp_dir, "01_process.R"),
             file.path(temp_dir, "02_summarize.R"),
             file.path(temp_dir, "intermediate.csv"),
             file.path(temp_dir, "final.csv"),
             file.path(temp_dir, ".bakepipe.state")))
  })

  # First run
  capture.output(run())
  
  # Modify input file
  Sys.sleep(1) # Ensure detectable time difference
  writeLines("data,value\nA,1\nB,2\nC,3", "input.csv")
  
  # Store modification times before second run
  initial_intermediate_time <- file.info("intermediate.csv")$mtime
  initial_final_time <- file.info("final.csv")$mtime
  
  Sys.sleep(1)
  
  # Second run should detect change and re-run both scripts
  result <- capture.output({result_value <- run()}); result <- result_value
  
  # Both output files should have been recreated
  expect_gt(file.info("intermediate.csv")$mtime, initial_intermediate_time)
  expect_gt(file.info("final.csv")$mtime, initial_final_time)
  
  # Should return updated files
  expect_true("intermediate.csv" %in% result)
  expect_true("final.csv" %in% result)
  
  # Check that final result reflects the change
  final_data <- read.csv("final.csv")
  expect_equal(final_data$total, 12) # (1+2+3)*2 = 12
})

test_that("run() updates state file after execution", {
  temp_dir <- file.path(tempdir(), "test_state_update")
  dir.create(temp_dir, showWarnings = FALSE)
  old_wd <- getwd()
  setwd(temp_dir)

  writeLines("# Bakepipe root marker", "_bakepipe.R")
  writeLines("data,value\nA,1", "input.csv")

  script_content <- '
library(bakepipe)
data <- read.csv(external_in("input.csv"))
write.csv(data, file_out("output.csv"), row.names = FALSE)
'
  writeLines(script_content, "process.R")

  on.exit({
    setwd(old_wd)
    unlink(c(file.path(temp_dir, "_bakepipe.R"),
             file.path(temp_dir, "input.csv"),
             file.path(temp_dir, "process.R"),
             file.path(temp_dir, "output.csv"),
             file.path(temp_dir, ".bakepipe.state")))
  })

  # Run pipeline
  capture.output(run())
  
  # State file should exist and contain all relevant files
  expect_true(file.exists(".bakepipe.state"))
  
  state_data <- read.csv(".bakepipe.state", stringsAsFactors = FALSE)
  expect_true("process.R" %in% state_data$file)
  expect_true("input.csv" %in% state_data$file)
  expect_true("output.csv" %in% state_data$file)
  
  # All files should be marked as fresh
  expect_true(all(state_data$status == "fresh"))
  
  # Checksums should be non-empty for existing files
  existing_files <- state_data[state_data$file %in% c("process.R", "input.csv", "output.csv"), ]
  expect_true(all(nchar(existing_files$checksum) > 0))
})

test_that("run() executes scripts in isolated environments", {
  temp_dir <- file.path(tempdir(), "test_isolated_execution")
  dir.create(temp_dir, showWarnings = FALSE)
  old_wd <- getwd()
  setwd(temp_dir)

  writeLines("# Bakepipe root marker", "_bakepipe.R")
  writeLines("data,value\nA,1\nB,2", "input.csv")

  # First script that creates a variable in its environment
  script1_content <- '
library(bakepipe)
data <- read.csv(external_in("input.csv"))
secret_variable <- "should_not_be_accessible"
data$processed <- data$value * 2
write.csv(data, file_out("intermediate.csv"), row.names = FALSE)
'
  writeLines(script1_content, "01_process.R")

  # Second script that tries to access the variable from first script
  # This should work because it reads from the file, not from the environment
  script2_content <- '
library(bakepipe)
data <- read.csv(file_in("intermediate.csv"))
# secret_variable should not be available from previous script
if (exists("secret_variable")) {
  stop("Script environments are not isolated - secret_variable is accessible")
}
summary_data <- data.frame(total = sum(data$processed))
write.csv(summary_data, file_out("final.csv"), row.names = FALSE)
'
  writeLines(script2_content, "02_summarize.R")

  on.exit({
    setwd(old_wd)
    unlink(c(file.path(temp_dir, "_bakepipe.R"),
             file.path(temp_dir, "input.csv"),
             file.path(temp_dir, "01_process.R"),
             file.path(temp_dir, "02_summarize.R"),
             file.path(temp_dir, "intermediate.csv"),
             file.path(temp_dir, "final.csv"),
             file.path(temp_dir, ".bakepipe.state")))
  })

  # This should succeed - scripts run in isolation
  result <- capture.output({result_value <- run()}); result <- result_value

  expect_true(file.exists("intermediate.csv"))
  expect_true(file.exists("final.csv"))

  final_data <- read.csv("final.csv")
  expect_equal(final_data$total, 6)
})

test_that("run() scripts cannot pollute global environment", {
  temp_dir <- file.path(tempdir(), "test_no_global_pollution")
  dir.create(temp_dir, showWarnings = FALSE)
  old_wd <- getwd()
  setwd(temp_dir)

  writeLines("# Bakepipe root marker", "_bakepipe.R")
  writeLines("test_value", "input.txt")

  # Script that tries to create a global variable
  script_content <- '
library(bakepipe)
content <- readLines(external_in("input.txt"))
global_pollution_test <- "this_should_not_appear_globally"
writeLines(paste("Processed:", content), file_out("output.txt"))
'
  writeLines(script_content, "process.R")

  on.exit({
    setwd(old_wd)
    unlink(c(file.path(temp_dir, "_bakepipe.R"),
             file.path(temp_dir, "input.txt"),
             file.path(temp_dir, "process.R"),
             file.path(temp_dir, "output.txt"),
             file.path(temp_dir, ".bakepipe.state")))
  })

  # Make sure the variable doesn't exist before
  expect_false(exists("global_pollution_test", envir = globalenv()))

  # Run pipeline
  capture.output(run())

  # The variable should still not exist in global environment
  expect_false(exists("global_pollution_test", envir = globalenv()))
  expect_true(file.exists("output.txt"))
})

test_that("run() fails when file_in has no corresponding file_out", {
  temp_dir <- tempdir()
  old_wd <- getwd()
  setwd(temp_dir)

  writeLines("# Bakepipe root marker", "_bakepipe.R")

  # Create a script that uses file_in() for a file that's not produced by any script
  script_content <- '
library(bakepipe)
# This file_in should cause validation to fail since no script produces orphaned.csv
data <- read.csv(file_in("orphaned.csv"))
write.csv(data, file_out("output.csv"))
'
  writeLines(script_content, "broken.R")

  on.exit({
    setwd(old_wd)
    unlink(c(file.path(temp_dir, "_bakepipe.R"),
             file.path(temp_dir, "broken.R")))
  })

  # Test: validation should fail
  expect_error({invisible(capture.output(run()))}, "Pipeline validation failed.*orphaned.csv")
})

test_that("run() passes when file_in has corresponding file_out", {
  temp_dir <- tempdir()
  old_wd <- getwd()
  setwd(temp_dir)

  writeLines("# Bakepipe root marker", "_bakepipe.R")

  # Create external input file
  writeLines("x\n1\n2\n3", "external.csv")

  # Create test scripts with proper dependencies
  script1_content <- '
library(bakepipe)
external_data <- read.csv(external_in("external.csv"))
processed <- data.frame(y = external_data$x * 2)
write.csv(processed, file_out("processed.csv"), row.names = FALSE)
'
  writeLines(script1_content, "01_process.R")

  script2_content <- '
library(bakepipe)
processed_data <- read.csv(file_in("processed.csv"))
result <- data.frame(z = mean(processed_data$y))
write.csv(result, file_out("result.csv"), row.names = FALSE)
'
  writeLines(script2_content, "02_analyze.R")

  on.exit({
    setwd(old_wd)
    unlink(c(file.path(temp_dir, "_bakepipe.R"),
             file.path(temp_dir, "external.csv"),
             file.path(temp_dir, "01_process.R"),
             file.path(temp_dir, "02_analyze.R"),
             file.path(temp_dir, "processed.csv"),
             file.path(temp_dir, "result.csv"),
             file.path(temp_dir, ".bakepipe.state")))
  })

  # Test: validation should pass and pipeline should run
  expect_no_error({invisible(capture.output(run()))})

  # Verify files were created
  expect_true(file.exists("processed.csv"))
  expect_true(file.exists("result.csv"))
})

test_that("run() allows external_in files without corresponding file_out", {
  temp_dir <- tempdir()
  old_wd <- getwd()
  setwd(temp_dir)

  writeLines("# Bakepipe root marker", "_bakepipe.R")

  # Create external input file
  writeLines("a\n1\n2\n3", "user_provided.csv")

  # Create test script that uses external_in for a file not produced by any script
  script_content <- '
library(bakepipe)
# This external_in should NOT cause validation to fail
user_data <- read.csv(external_in("user_provided.csv"))
processed <- data.frame(b = user_data$a * 3)
write.csv(processed, file_out("processed.csv"), row.names = FALSE)
'
  writeLines(script_content, "process.R")

  on.exit({
    setwd(old_wd)
    unlink(c(file.path(temp_dir, "_bakepipe.R"),
             file.path(temp_dir, "user_provided.csv"),
             file.path(temp_dir, "process.R"),
             file.path(temp_dir, "processed.csv"),
             file.path(temp_dir, ".bakepipe.state")))
  })

  # Test: validation should pass because external_in is not subject to the same rules
  expect_no_error({invisible(capture.output(run()))})

  # Verify file was created
  expect_true(file.exists("processed.csv"))
})