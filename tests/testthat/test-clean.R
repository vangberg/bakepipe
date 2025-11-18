test_that("clean() removes targets metadata directory", {
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
data <- data.frame(x = 1)
write.csv(data, file_out(\"output.csv\"), row.names = FALSE)
", file = script1)

  setwd(project_dir)

  skip_if_not_installed("targets")

  # Run pipeline to create targets metadata
  capture.output(run())

  # Verify targets directory exists
  expect_true(file.exists("_targets"))

  # Clean should remove targets directory
  result <- clean(verbose = FALSE)

  # Targets directory should be removed
  expect_false(file.exists("_targets"))

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("clean() removes output files", {
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
data <- data.frame(x = 1)
write.csv(data, file_out(\"output.csv\"), row.names = FALSE)
", file = script1)

  setwd(project_dir)

  skip_if_not_installed("targets")

  # Run pipeline
  capture.output(run())

  # Verify output exists
  expect_true(file.exists("output.csv"))

  # Clean should remove output files
  result <- clean(verbose = FALSE)

  # Output should be removed
  expect_false(file.exists("output.csv"))

  # Should return list of removed files
  expect_true("output.csv" %in% result)

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("clean() removes _targets.R", {
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
data <- data.frame(x = 1)
write.csv(data, file_out(\"output.csv\"), row.names = FALSE)
", file = script1)

  setwd(project_dir)

  skip_if_not_installed("targets")

  # Run pipeline to generate _targets.R
  capture.output(run())

  # Verify _targets.R exists
  expect_true(file.exists("_targets.R"))

  # Clean should remove _targets.R
  clean(verbose = FALSE)

  # _targets.R should be removed
  expect_false(file.exists("_targets.R"))

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("clean() after run() allows pipeline to run again", {
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
data <- data.frame(x = 1)
write.csv(data, file_out(\"output.csv\"), row.names = FALSE)
", file = script1)

  setwd(project_dir)

  skip_if_not_installed("targets")

  # Run pipeline
  capture.output(run())
  expect_true(file.exists("output.csv"))

  # Clean
  clean(verbose = FALSE)
  expect_false(file.exists("output.csv"))

  # Should be able to run again
  result <- run()

  # Output should be recreated
  expect_true(file.exists("output.csv"))
  expect_true("output.csv" %in% result)

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("clean() preserves input files and scripts", {
  temp_dir <- tempfile()
  old_wd <- getwd()

  # Setup
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)

  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Create input file
  writeLines("x\n1\n2", file.path(project_dir, "input.csv"))

  # Create script
  script1 <- file.path(project_dir, "process.R")
  cat("
library(bakepipe)
data <- read.csv(external_in(\"input.csv\"))
write.csv(data, file_out(\"output.csv\"), row.names = FALSE)
", file = script1)

  setwd(project_dir)

  skip_if_not_installed("targets")

  # Run pipeline
  capture.output(run())

  # Clean
  clean(verbose = FALSE)

  # Input and script should remain
  expect_true(file.exists("input.csv"))
  expect_true(file.exists("process.R"))
  expect_true(file.exists("_bakepipe.R"))

  # Output should be removed
  expect_false(file.exists("output.csv"))

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})
