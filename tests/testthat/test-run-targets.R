test_that("run() generates _targets.R before execution", {
  temp_dir <- tempfile()
  old_wd <- getwd()

  # Setup
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)

  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Create simple script
  script1 <- file.path(project_dir, "process.R")
  cat("
library(bakepipe)
data <- read.csv(external_in(\"input.csv\"))
write.csv(data, file_out(\"output.csv\"), row.names = FALSE)
", file = script1)

  # Create input file
  writeLines("x\n1\n2", file.path(project_dir, "input.csv"))

  setwd(project_dir)

  # Skip if targets not installed
  skip_if_not_installed("targets")

  # Run should generate _targets.R
  result <- capture.output({result_value <- run(verbose = FALSE)})
  result <- result_value

  # _targets.R should exist
  expect_true(file.exists("_targets.R"))

  # _targets.R should be valid
  targets_content <- readLines("_targets.R")
  expect_true(any(grepl("library\\(targets\\)", targets_content)))

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("run() uses targets::tar_make() for execution", {
  temp_dir <- tempfile()
  old_wd <- getwd()

  # Setup
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)

  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Create script
  script1 <- file.path(project_dir, "process.R")
  cat("
library(bakepipe)
data <- read.csv(external_in(\"input.csv\"))
write.csv(data, file_out(\"output.csv\"), row.names = FALSE)
", file = script1)

  # Create input file
  writeLines("x\n1\n2", file.path(project_dir, "input.csv"))

  setwd(project_dir)

  skip_if_not_installed("targets")

  # Run
  result <- capture.output({result_value <- run(verbose = FALSE)})
  result <- result_value

  # targets should have created its metadata directory
  expect_true(file.exists("_targets"))

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("run() with targets backend maintains incremental execution", {
  temp_dir <- tempfile()
  old_wd <- getwd()

  # Setup
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)

  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Create scripts
  script1 <- file.path(project_dir, "01_process.R")
  cat("
library(bakepipe)
data <- read.csv(external_in(\"input.csv\"))
data$doubled <- data$x * 2
write.csv(data, file_out(\"intermediate.csv\"), row.names = FALSE)
", file = script1)

  script2 <- file.path(project_dir, "02_summarize.R")
  cat("
library(bakepipe)
data <- read.csv(file_in(\"intermediate.csv\"))
result <- data.frame(total = sum(data$doubled))
write.csv(result, file_out(\"final.csv\"), row.names = FALSE)
", file = script2)

  # Create input file
  writeLines("x\n1\n2\n3", file.path(project_dir, "input.csv"))

  setwd(project_dir)

  skip_if_not_installed("targets")

  # First run
  result1 <- capture.output({result1_value <- run(verbose = FALSE)})
  result1 <- result1_value

  expect_true(file.exists("intermediate.csv"))
  expect_true(file.exists("final.csv"))
  expect_true("intermediate.csv" %in% result1)
  expect_true("final.csv" %in% result1)

  # Store modification times
  intermediate_time1 <- file.info("intermediate.csv")$mtime
  final_time1 <- file.info("final.csv")$mtime

  Sys.sleep(1)

  # Second run without changes - should skip everything
  result2 <- capture.output({result2_value <- run(verbose = FALSE)})
  result2 <- result2_value

  # Files should not have been recreated
  expect_equal(file.info("intermediate.csv")$mtime, intermediate_time1)
  expect_equal(file.info("final.csv")$mtime, final_time1)

  # Should return empty vector (no files created)
  expect_length(result2, 0)

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("run() targets backend detects file changes and reruns", {
  temp_dir <- tempfile()
  old_wd <- getwd()

  # Setup
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)

  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Create scripts
  script1 <- file.path(project_dir, "process.R")
  cat("
library(bakepipe)
data <- read.csv(external_in(\"input.csv\"))
data$doubled <- data$x * 2
write.csv(data, file_out(\"output.csv\"), row.names = FALSE)
", file = script1)

  # Create input file
  writeLines("x\n1\n2", file.path(project_dir, "input.csv"))

  setwd(project_dir)

  skip_if_not_installed("targets")

  # First run
  capture.output(run(verbose = FALSE))

  # Check initial output
  output1 <- read.csv("output.csv")
  expect_equal(nrow(output1), 2)

  # Modify input file
  Sys.sleep(1)
  writeLines("x\n1\n2\n3", file.path(project_dir, "input.csv"))

  Sys.sleep(1)

  # Second run should detect change and rerun
  result <- capture.output({result_value <- run(verbose = FALSE)})
  result <- result_value

  # Should return output file as it was recreated
  expect_true("output.csv" %in% result)

  # Output should reflect the change
  output2 <- read.csv("output.csv")
  expect_equal(nrow(output2), 3)

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("run() targets backend detects script changes", {
  temp_dir <- tempfile()
  old_wd <- getwd()

  # Setup
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)

  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Create script
  script1 <- file.path(project_dir, "process.R")
  cat("
library(bakepipe)
data <- data.frame(x = c(1, 2))
data$result <- data$x * 2
write.csv(data, file_out(\"output.csv\"), row.names = FALSE)
", file = script1)

  setwd(project_dir)

  skip_if_not_installed("targets")

  # First run
  capture.output(run(verbose = FALSE))

  output1 <- read.csv("output.csv")
  expect_equal(output1$result, c(2, 4))

  # Modify script
  Sys.sleep(1)
  cat("
library(bakepipe)
data <- data.frame(x = c(1, 2))
data$result <- data$x * 3
write.csv(data, file_out(\"output.csv\"), row.names = FALSE)
", file = script1)

  Sys.sleep(1)

  # Second run should detect script change
  result <- capture.output({result_value <- run(verbose = FALSE)})
  result <- result_value

  expect_true("output.csv" %in% result)

  # Output should reflect script change
  output2 <- read.csv("output.csv")
  expect_equal(output2$result, c(3, 6))

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("run() targets backend handles errors gracefully", {
  temp_dir <- tempfile()
  old_wd <- getwd()

  # Setup
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)

  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Create script with error
  script1 <- file.path(project_dir, "error.R")
  cat("
library(bakepipe)
stop(\"Intentional error for testing\")
", file = script1)

  setwd(project_dir)

  skip_if_not_installed("targets")

  # Should error with clear message
  expect_error(
    capture.output(run(verbose = FALSE)),
    "error"
  )

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("run() preserves return value compatibility", {
  temp_dir <- tempfile()
  old_wd <- getwd()

  # Setup
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)

  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Create script
  script1 <- file.path(project_dir, "process.R")
  cat("
library(bakepipe)
write.csv(data.frame(x = 1), file_out(\"output.csv\"), row.names = FALSE)
", file = script1)

  setwd(project_dir)

  skip_if_not_installed("targets")

  # Run and check return value
  result <- capture.output({result_value <- run(verbose = FALSE)})
  result <- result_value

  # Should return character vector of created files
  expect_type(result, "character")
  expect_true("output.csv" %in% result)

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("run() regenerates _targets.R on each run", {
  temp_dir <- tempfile()
  old_wd <- getwd()

  # Setup
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)

  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Create script
  script1 <- file.path(project_dir, "process.R")
  cat("
library(bakepipe)
write.csv(data.frame(x = 1), file_out(\"output.csv\"), row.names = FALSE)
", file = script1)

  setwd(project_dir)

  skip_if_not_installed("targets")

  # First run
  capture.output(run(verbose = FALSE))
  targets_time1 <- file.info("_targets.R")$mtime

  # Add new script
  Sys.sleep(1)
  script2 <- file.path(project_dir, "process2.R")
  cat("
library(bakepipe)
data <- read.csv(file_in(\"output.csv\"))
write.csv(data, file_out(\"output2.csv\"), row.names = FALSE)
", file = script2)

  Sys.sleep(1)

  # Second run should regenerate _targets.R with new script
  capture.output(run(verbose = FALSE))
  targets_time2 <- file.info("_targets.R")$mtime

  # _targets.R should have been regenerated
  expect_gt(targets_time2, targets_time1)

  # Should include new script target
  targets_content <- readLines("_targets.R")
  expect_true(any(grepl("process2", targets_content)))

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})
