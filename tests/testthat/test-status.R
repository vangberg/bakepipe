test_that("status() generates _targets.R before checking", {
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

  setwd(project_dir)

  skip_if_not_installed("targets")

  # status() should generate _targets.R
  output <- capture.output(status(verbose = TRUE), type = "message")

  # _targets.R should exist
  expect_true(file.exists("_targets.R"))

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("status() shows fresh scripts after run()", {
  temp_dir <- tempfile()
  old_wd <- getwd()

  # Setup
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)

  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Create script and input
  script1 <- file.path(project_dir, "process.R")
  cat("
library(bakepipe)
data <- read.csv(external_in(\"input.csv\"))
write.csv(data, file_out(\"output.csv\"), row.names = FALSE)
", file = script1)

  writeLines("x\n1\n2", file.path(project_dir, "input.csv"))

  setwd(project_dir)

  skip_if_not_installed("targets")

  # Run pipeline
  capture.output(run())

  # Check status
  output <- capture.output(status(verbose = TRUE), type = "message")

  # Should show script as fresh
  expect_true(any(grepl("process.R", output)))
  expect_true(any(grepl("fresh", output)))

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("status() shows stale scripts after file change", {
  temp_dir <- tempfile()
  old_wd <- getwd()

  # Setup
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)

  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Create script and input
  script1 <- file.path(project_dir, "process.R")
  cat("
library(bakepipe)
data <- read.csv(external_in(\"input.csv\"))
write.csv(data, file_out(\"output.csv\"), row.names = FALSE)
", file = script1)

  writeLines("x\n1\n2", file.path(project_dir, "input.csv"))

  setwd(project_dir)

  skip_if_not_installed("targets")

  # Run pipeline
  capture.output(run())

  # Modify input file
  Sys.sleep(1)
  writeLines("x\n1\n2\n3", file.path(project_dir, "input.csv"))

  # Check status
  output <- capture.output(status(verbose = TRUE), type = "message")

  # Should show script as stale
  expect_true(any(grepl("process.R", output)))
  expect_true(any(grepl("stale", output)))

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("status() shows stale scripts after script change", {
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

  # Run pipeline
  capture.output(run())

  # Modify script
  Sys.sleep(1)
  cat("
library(bakepipe)
data <- data.frame(x = c(1, 2))
data$result <- data$x * 3
write.csv(data, file_out(\"output.csv\"), row.names = FALSE)
", file = script1)

  # Check status
  output <- capture.output(status(verbose = TRUE), type = "message")

  # Should show script as stale
  expect_true(any(grepl("process.R", output)))
  expect_true(any(grepl("stale", output)))

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})



test_that("status() maintains output format compatibility", {
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

  # Check status
  output <- capture.output(status(verbose = TRUE), type = "message")

  # Should have standard bakepipe status output format
  expect_true(any(grepl("Bakepipe Status", output)))
  expect_true(any(grepl("process.R", output)))
  expect_true(any(grepl("fresh|stale", output)))

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})
