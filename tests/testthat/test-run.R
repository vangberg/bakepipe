test_that("run() executes scripts in topological order", {
  temp_dir <- tempdir()
  old_wd <- getwd()
  setwd(temp_dir)

  writeLines("# Bakepipe root marker", "_bakepipe.R")

  writeLines("data,value\nA,1\nB,2", "input.csv")

  script1_content <- '
library(bakepipe)
data <- read.csv(file_in("input.csv"))
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

  result <- run()

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

  result <- run()
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
data <- read.csv(file_in("input.csv"))
cat("Processing", nrow(data), "rows\n")
'
  writeLines(script_content, "process.R")

  on.exit({
    setwd(old_wd)
    unlink(c(file.path(temp_dir, "_bakepipe.R"),
             file.path(temp_dir, "input.csv"),
             file.path(temp_dir, "process.R")))
  })

  result <- run()
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

  expect_error(run(), "Script error for testing")
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
data <- readLines(file_in("data.csv"))
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

  result <- run()

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
data <- read.csv(file_in("input.csv"))
data$processed <- data$value * 2
write.csv(data, file_out("intermediate.csv"), row.names = FALSE)
cat("Script 1 executed\n")
'
  writeLines(script1_content, "01_process.R")

  script2_content <- '
library(bakepipe)
data <- read.csv(file_in("intermediate.csv"))
summary_data <- data.frame(total = sum(data$processed))
write.csv(summary_data, file_out("final.csv"), row.names = FALSE)
cat("Script 2 executed\n")
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
  result1 <- run()
  expect_true(file.exists(".bakepipe.state"))
  expect_true(file.exists("intermediate.csv"))
  expect_true(file.exists("final.csv"))

  # Second run without changes - should run no scripts
  # We can't easily test console output, but we can test that files aren't recreated
  initial_intermediate_time <- file.info("intermediate.csv")$mtime
  initial_final_time <- file.info("final.csv")$mtime
  
  Sys.sleep(1) # Ensure time difference would be detectable
  
  result2 <- run()
  
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
data <- read.csv(file_in("input.csv"))
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
  run()
  
  # Modify input file
  Sys.sleep(1) # Ensure detectable time difference
  writeLines("data,value\nA,1\nB,2\nC,3", "input.csv")
  
  # Store modification times before second run
  initial_intermediate_time <- file.info("intermediate.csv")$mtime
  initial_final_time <- file.info("final.csv")$mtime
  
  Sys.sleep(1)
  
  # Second run should detect change and re-run both scripts
  result <- run()
  
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
data <- read.csv(file_in("input.csv"))
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
  run()
  
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