test_that("scripts() finds .R files in project root", {
  # Create a temporary directory structure
  temp_dir <- tempdir()
  old_wd <- getwd()

  # Setup: Create a temporary project directory with _bakepipe.R
  project_dir <- file.path(temp_dir, "test_project")
  dir.create(project_dir, recursive = TRUE)

  # Create _bakepipe.R in the project root
  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Create some R files in the project root
  script1 <- file.path(project_dir, "analysis.R")
  script2 <- file.path(project_dir, "helpers.R")
  file.create(script1)
  file.create(script2)

  # Change to project directory
  setwd(project_dir)

  # Test: scripts() should find the R files
  result <- scripts()
  expect_type(result, "character")
  expect_length(result, 2)
  expect_true(normalizePath(script1) %in% result)
  expect_true(normalizePath(script2) %in% result)

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("scripts() finds .R files recursively in subdirectories", {
  # Create a temporary directory structure
  temp_dir <- tempdir()
  old_wd <- getwd()

  # Setup: Create nested directory structure
  project_dir <- file.path(temp_dir, "test_project")
  sub_dir <- file.path(project_dir, "scripts")
  sub_sub_dir <- file.path(sub_dir, "utils")
  dir.create(sub_sub_dir, recursive = TRUE)

  # Create _bakepipe.R in the project root
  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Create R files at different levels
  root_script <- file.path(project_dir, "main.R")
  sub_script <- file.path(sub_dir, "process.R")
  deep_script <- file.path(sub_sub_dir, "helpers.R")
  file.create(root_script)
  file.create(sub_script)
  file.create(deep_script)

  # Create a non-R file to ensure it's ignored
  txt_file <- file.path(project_dir, "readme.txt")
  file.create(txt_file)

  # Change to project directory
  setwd(project_dir)

  # Test: scripts() should find all R files recursively
  result <- scripts()
  expect_type(result, "character")
  expect_length(result, 3)
  expect_true(normalizePath(root_script) %in% result)
  expect_true(normalizePath(sub_script) %in% result)
  expect_true(normalizePath(deep_script) %in% result)
  expect_false(normalizePath(txt_file) %in% result)

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("scripts() handles case-insensitive .R extensions", {
  # Create a temporary directory structure
  temp_dir <- tempdir()
  old_wd <- getwd()

  # Setup: Create a temporary project directory
  project_dir <- file.path(temp_dir, "test_project")
  dir.create(project_dir, recursive = TRUE)

  # Create _bakepipe.R in the project root
  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Create R files with different case extensions
  script_lower <- file.path(project_dir, "script1.r")
  script_upper <- file.path(project_dir, "script2.R")
  file.create(script_lower)
  file.create(script_upper)

  # Change to project directory
  setwd(project_dir)

  # Test: scripts() should find both .r and .R files
  result <- scripts()
  expect_type(result, "character")
  expect_length(result, 2)
  expect_true(normalizePath(script_lower) %in% result)
  expect_true(normalizePath(script_upper) %in% result)

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("scripts() returns empty vector when no .R files found", {
  # Create a temporary directory structure
  temp_dir <- tempdir()
  old_wd <- getwd()

  # Setup: Create a project directory with only non-R files
  project_dir <- file.path(temp_dir, "test_project")
  dir.create(project_dir, recursive = TRUE)

  # Create _bakepipe.R in the project root
  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Create non-R files
  txt_file <- file.path(project_dir, "readme.txt")
  csv_file <- file.path(project_dir, "data.csv")
  file.create(txt_file)
  file.create(csv_file)

  # Change to project directory
  setwd(project_dir)

  # Test: scripts() should return empty character vector
  result <- scripts()
  expect_type(result, "character")
  expect_length(result, 0)

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("scripts() works from subdirectory", {
  # Create a temporary directory structure
  temp_dir <- tempdir()
  old_wd <- getwd()

  # Setup: Create nested directory structure
  project_dir <- file.path(temp_dir, "test_project")
  sub_dir <- file.path(project_dir, "analysis")
  dir.create(sub_dir, recursive = TRUE)

  # Create _bakepipe.R in the project root
  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Create R files
  root_script <- file.path(project_dir, "main.R")
  sub_script <- file.path(sub_dir, "analyze.R")
  file.create(root_script)
  file.create(sub_script)

  # Change to subdirectory
  setwd(sub_dir)

  # Test: scripts() should still find all R files in project
  result <- scripts()
  expect_type(result, "character")
  expect_length(result, 2)
  expect_true(normalizePath(root_script) %in% result)
  expect_true(normalizePath(sub_script) %in% result)

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("scripts() excludes hidden directories", {
  # Create a temporary directory structure
  temp_dir <- tempdir()
  old_wd <- getwd()

  # Setup: Create project with hidden directories
  project_dir <- file.path(temp_dir, "test_project")
  hidden_dir <- file.path(project_dir, ".cache")
  visible_dir <- file.path(project_dir, "scripts")
  dir.create(hidden_dir, recursive = TRUE)
  dir.create(visible_dir, recursive = TRUE)

  # Create _bakepipe.R in the project root
  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Create R files in visible and hidden directories
  visible_script <- file.path(visible_dir, "analysis.R")
  hidden_script <- file.path(hidden_dir, "cached.R")
  root_script <- file.path(project_dir, "main.R")
  file.create(visible_script)
  file.create(hidden_script)
  file.create(root_script)

  # Change to project directory
  setwd(project_dir)

  # Test: scripts() should only find files in visible directories
  result <- scripts()
  expect_type(result, "character")
  expect_length(result, 2)
  expect_true(normalizePath(visible_script) %in% result)
  expect_true(normalizePath(root_script) %in% result)
  expect_false(normalizePath(hidden_script) %in% result)

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})