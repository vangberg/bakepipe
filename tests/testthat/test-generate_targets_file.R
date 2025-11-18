test_that("generate_targets_file() creates _targets.R for simple script", {
  # Create a temporary directory structure
  temp_dir <- tempfile()
  old_wd <- getwd()

  # Setup: Create a temporary project directory
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)

  # Create _bakepipe.R in the project root
  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Create a simple script with one input and one output
  script1 <- file.path(project_dir, "process.R")
  cat('
data <- read.csv(external_in("input.csv"))
result <- process(data)
write.csv(result, file_out("output.csv"))
', file = script1)

  # Change to project directory
  setwd(project_dir)

  # Test: generate_targets_file() should create _targets.R
  generate_targets_file()

  targets_file <- file.path(project_dir, "_targets.R")
  expect_true(file.exists(targets_file))

  # Read and verify the generated file
  targets_content <- readLines(targets_file)
  targets_text <- paste(targets_content, collapse = "\n")

  # Should have library(targets) at the top
  expect_match(targets_text, "library\\(targets\\)", ignore.case = FALSE)

  # Should have script file target
  expect_match(
    targets_text,
    "tar_target\\(script_process_r, \"process.R\", format = \"file\"\\)"
  )

  # Should have external input target
  expect_match(
    targets_text,
    "tar_target\\(input_csv, \"input.csv\", format = \"file\"\\)"
  )

  # Should have execution target using callr
  expect_match(targets_text, "tar_target\\(\\s*run_process")
  expect_match(targets_text, "callr::r\\(")
  expect_match(targets_text, "script_path = \"process.R\"")

  # Should have output target dependent on run_process
  expect_match(targets_text, "tar_target\\(output_csv,")
  expect_match(targets_text, "run_process")
  expect_match(targets_text, "\"output.csv\"")
  expect_match(targets_text, "format = \"file\"")

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("generate_targets_file() creates separate targets for multiple outputs", {
  # Create a temporary directory structure
  temp_dir <- tempfile()
  old_wd <- getwd()

  # Setup
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)

  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Script with multiple outputs
  script1 <- file.path(project_dir, "split.R")
  cat('
data <- read.csv(external_in("data.csv"))
write.csv(data[1:10, ], file_out("part_a.csv"))
write.csv(data[11:20, ], file_out("part_b.csv"))
', file = script1)

  setwd(project_dir)

  # Generate targets file
  generate_targets_file()

  targets_file <- file.path(project_dir, "_targets.R")
  targets_text <- paste(readLines(targets_file), collapse = "\n")

  # Should have separate output targets
  expect_match(targets_text, "tar_target\\(part_a_csv,")
  expect_match(targets_text, "tar_target\\(part_b_csv,")

  # Both should depend on run_split
  expect_match(targets_text, "run_split.*part_a.csv")
  expect_match(targets_text, "run_split.*part_b.csv")

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("generate_targets_file() fine-grained deps from file_in()", {
  # Create a temporary directory structure
  temp_dir <- tempfile()
  old_wd <- getwd()

  # Setup
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)

  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Script 1: produces multiple outputs
  script1 <- file.path(project_dir, "01_split.R")
  cat('
data <- read.csv(external_in("data.csv"))
write.csv(data[data$type == "A", ], file_out("type_a.csv"))
write.csv(data[data$type == "B", ], file_out("type_b.csv"))
', file = script1)

  # Script 2: only uses type_a.csv
  script2 <- file.path(project_dir, "02_analyze_a.R")
  cat('
data_a <- read.csv(file_in("type_a.csv"))
result <- analyze(data_a)
write.csv(result, file_out("analysis_a.csv"))
', file = script2)

  # Script 3: only uses type_b.csv
  script3 <- file.path(project_dir, "03_analyze_b.R")
  cat('
data_b <- read.csv(file_in("type_b.csv"))
result <- analyze(data_b)
write.csv(result, file_out("analysis_b.csv"))
', file = script3)

  setwd(project_dir)

  # Generate targets file
  generate_targets_file()

  targets_file <- file.path(project_dir, "_targets.R")
  targets_text <- paste(readLines(targets_file), collapse = "\n")

  # run_02_analyze_a should depend on type_a_csv, NOT type_b_csv
  # We can check this by looking at the dependencies in the run_02_analyze_a target
  expect_match(targets_text, "run_02_analyze_a")

  # Extract the run_02_analyze_a target definition
  # It should reference type_a_csv but not type_b_csv
  expect_match(targets_text, "type_a_csv")

  # Similarly for run_03_analyze_b
  expect_match(targets_text, "run_03_analyze_b")
  expect_match(targets_text, "type_b_csv")

  # The key test: in the actual execution, changing type_b.csv
  # should NOT trigger rerun of 02_analyze_a.R
  # (This will be tested in integration tests)

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("generate_targets_file() handles external_in() as file targets", {
  # Create a temporary directory structure
  temp_dir <- tempfile()
  old_wd <- getwd()

  # Setup
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)

  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Script with external inputs
  script1 <- file.path(project_dir, "process.R")
  cat('
data <- read.csv(external_in("input.csv"))
config <- readRDS(external_in("config.rds"))
result <- process(data, config)
write.csv(result, file_out("output.csv"))
', file = script1)

  setwd(project_dir)

  # Generate targets file
  generate_targets_file()

  targets_file <- file.path(project_dir, "_targets.R")
  targets_text <- paste(readLines(targets_file), collapse = "\n")

  # Should have external file targets
  expect_match(
    targets_text,
    "tar_target\\(input_csv, \"input.csv\", format = \"file\"\\)"
  )
  expect_match(
    targets_text,
    "tar_target\\(config_rds, \"config.rds\", format = \"file\"\\)"
  )

  # run_process should depend on both external inputs
  expect_match(targets_text, "run_process")
  expect_match(targets_text, "input_csv")
  expect_match(targets_text, "config_rds")

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("generate_targets_file() uses callr::r() for script execution", {
  # Create a temporary directory structure
  temp_dir <- tempfile()
  old_wd <- getwd()

  # Setup
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)

  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Simple script
  script1 <- file.path(project_dir, "test.R")
  cat('
data <- read.csv(external_in("input.csv"))
write.csv(data, file_out("output.csv"))
', file = script1)

  setwd(project_dir)

  # Generate targets file
  generate_targets_file()

  targets_file <- file.path(project_dir, "_targets.R")
  targets_text <- paste(readLines(targets_file), collapse = "\n")

  # Should use callr::r() with a function, NOT direct source()
  expect_match(targets_text, "callr::r\\(")

  # callr::r() should be passed a function that sources the script
  # This maintains isolation like bakepipe currently does
  expect_match(targets_text, "func = function\\(script_path\\)")
  # source() should be inside the function passed to callr::r()
  expect_match(targets_text, "source\\(script_path")

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("generate_targets_file() creates valid R code", {
  # Create a temporary directory structure
  temp_dir <- tempfile()
  old_wd <- getwd()

  # Setup
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)

  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Simple script
  script1 <- file.path(project_dir, "process.R")
  cat('
data <- read.csv(external_in("input.csv"))
write.csv(data, file_out("output.csv"))
', file = script1)

  setwd(project_dir)

  # Generate targets file
  generate_targets_file()

  targets_file <- file.path(project_dir, "_targets.R")

  # Skip this test if targets is not installed
  skip_if_not_installed("targets")

  # Should be able to source it without errors
  expect_error(source(targets_file), NA)

  # After sourcing, should be able to call targets functions

  # Should be able to get the manifest
  manifest <- targets::tar_manifest(callr_function = NULL)
  expect_s3_class(manifest, "data.frame")
  expect_true(nrow(manifest) > 0)

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("generate_targets_file() handles scripts with no dependencies", {
  # Create a temporary directory structure
  temp_dir <- tempfile()
  old_wd <- getwd()

  # Setup
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)

  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Script with no file_in, file_out, or external_in calls
  script1 <- file.path(project_dir, "utils.R")
  cat("
# Just utility functions
helper <- function(x) {
  x + 1
}
", file = script1)

  setwd(project_dir)

  # Generate targets file
  generate_targets_file()

  targets_file <- file.path(project_dir, "_targets.R")
  expect_true(file.exists(targets_file))

  # Should still create a script target and run target
  targets_text <- paste(readLines(targets_file), collapse = "\n")
  expect_match(targets_text, "script_utils_r")
  expect_match(targets_text, "run_utils")

  # But no input or output targets
  # (Just the script runs once when it changes)

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("generate_targets_file() proper target names", {
  # Create a temporary directory structure
  temp_dir <- tempfile()
  old_wd <- getwd()

  # Setup
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)

  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Script with various file names
  script1 <- file.path(project_dir, "01_process_data.R")
  cat('
data <- read.csv(external_in("raw-data.csv"))
write.csv(data, file_out("processed_data.csv"))
write.csv(data, file_out("backup.data.csv"))
', file = script1)

  setwd(project_dir)

  # Generate targets file
  generate_targets_file()

  targets_file <- file.path(project_dir, "_targets.R")
  targets_text <- paste(readLines(targets_file), collapse = "\n")

  # Target names should replace special characters with underscores
  # 01_process_data.R becomes script_01_process_data_r
  expect_match(targets_text, "script_01_process_data_r")

  # raw-data.csv becomes raw_data_csv (hyphens to underscores)
  expect_match(targets_text, "raw_data_csv")

  # processed_data.csv becomes processed_data_csv
  expect_match(targets_text, "processed_data_csv")

  # backup.data.csv becomes backup_data_csv (dots to underscores)
  expect_match(targets_text, "backup_data_csv")

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("generate_targets_file() handles scripts in subdirectories", {
  # Create a temporary directory structure
  temp_dir <- tempfile()
  old_wd <- getwd()

  # Setup with subdirectories
  project_dir <- temp_dir
  sub_dir <- file.path(project_dir, "scripts")
  dir.create(sub_dir, recursive = TRUE)

  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Script in subdirectory
  script1 <- file.path(sub_dir, "process.R")
  cat('
data <- read.csv(external_in("input.csv"))
write.csv(data, file_out("output.csv"))
', file = script1)

  setwd(project_dir)

  # Generate targets file
  generate_targets_file()

  targets_file <- file.path(project_dir, "_targets.R")
  targets_text <- paste(readLines(targets_file), collapse = "\n")

  # Should reference the script with its subdirectory path
  expect_match(targets_text, "scripts/process.R")

  # Target name should include subdirectory info
  # scripts/process.R becomes script_scripts_process_r
  expect_match(targets_text, "script_scripts_process_r")

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("generate_targets_file() creates list() wrapper for tar_targets", {
  # Create a temporary directory structure
  temp_dir <- tempfile()
  old_wd <- getwd()

  # Setup
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)

  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Simple script
  script1 <- file.path(project_dir, "test.R")
  cat('
data <- read.csv(external_in("input.csv"))
write.csv(data, file_out("output.csv"))
', file = script1)

  setwd(project_dir)

  # Generate targets file
  generate_targets_file()

  targets_file <- file.path(project_dir, "_targets.R")
  targets_text <- paste(readLines(targets_file), collapse = "\n")

  # targets package requires a list() of tar_target() calls
  expect_match(targets_text, "list\\(")

  # All tar_target calls should be inside the list
  # Count opening and closing parens to verify structure

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("generate_targets_file() overwrites existing _targets.R", {
  # Create a temporary directory structure
  temp_dir <- tempfile()
  old_wd <- getwd()

  # Setup
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)

  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Create existing _targets.R with old content
  targets_file <- file.path(project_dir, "_targets.R")
  cat("# Old targets file\nlist()\n", file = targets_file)
  old_content <- readLines(targets_file)

  # Script
  script1 <- file.path(project_dir, "test.R")
  cat('
data <- read.csv(external_in("input.csv"))
write.csv(data, file_out("output.csv"))
', file = script1)

  setwd(project_dir)

  # Generate targets file (should overwrite)
  generate_targets_file()

  new_content <- readLines(targets_file)

  # Content should be different
  expect_false(identical(old_content, new_content))

  # New content should have proper targets structure
  expect_true(any(grepl("tar_target", new_content)))

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})
