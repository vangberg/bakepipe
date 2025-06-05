test_that("root() finds _bakepipe.R in current directory", {
  # Create a temporary directory structure
  temp_dir <- tempdir()
  old_wd <- getwd()
  
  # Setup: Create a temporary project directory with _bakepipe.R
  project_dir <- file.path(temp_dir, "test_project")
  dir.create(project_dir, recursive = TRUE)
  
  # Create _bakepipe.R in the project root
  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)
  
  # Change to project directory
  setwd(project_dir)
  
  # Test: root() should return the current directory
  expect_equal(root(), normalizePath(project_dir))
  
  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("root() finds _bakepipe.R in parent directory", {
  # Create a temporary directory structure
  temp_dir <- tempdir()
  old_wd <- getwd()
  
  # Setup: Create nested directory structure
  project_dir <- file.path(temp_dir, "test_project")
  sub_dir <- file.path(project_dir, "subdir")
  dir.create(sub_dir, recursive = TRUE)
  
  # Create _bakepipe.R in the project root
  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)
  
  # Change to subdirectory
  setwd(sub_dir)
  
  # Test: root() should return the parent directory containing _bakepipe.R
  expect_equal(root(), normalizePath(project_dir))
  
  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("root() finds _bakepipe.R in grandparent directory", {
  # Create a temporary directory structure
  temp_dir <- tempdir()
  old_wd <- getwd()
  
  # Setup: Create deeply nested directory structure
  project_dir <- file.path(temp_dir, "test_project")
  sub_dir <- file.path(project_dir, "subdir")
  sub_sub_dir <- file.path(sub_dir, "subsubdir")
  dir.create(sub_sub_dir, recursive = TRUE)
  
  # Create _bakepipe.R in the project root
  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)
  
  # Change to deeply nested subdirectory
  setwd(sub_sub_dir)
  
  # Test: root() should return the grandparent directory containing _bakepipe.R
  expect_equal(root(), normalizePath(project_dir))
  
  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("root() throws error when no _bakepipe.R found", {
  # Create a temporary directory structure without _bakepipe.R
  temp_dir <- tempdir()
  old_wd <- getwd()
  
  # Setup: Create directory without _bakepipe.R
  test_dir <- file.path(temp_dir, "no_bakepipe")
  dir.create(test_dir, recursive = TRUE)
  
  # Change to directory without _bakepipe.R
  setwd(test_dir)
  
  # Test: root() should throw an error
  expect_error(root(), "Could not find _bakepipe.R")
  
  # Cleanup
  setwd(old_wd)
  unlink(test_dir, recursive = TRUE)
})

test_that("root() stops at filesystem root", {
  # This test ensures we don't search beyond the filesystem root
  # We'll mock this by testing the search stops appropriately
  temp_dir <- tempdir()
  old_wd <- getwd()
  
  # Create a directory structure without _bakepipe.R
  test_dir <- file.path(temp_dir, "no_root_marker")
  dir.create(test_dir, recursive = TRUE)
  setwd(test_dir)
  
  # Should error because no _bakepipe.R found
  expect_error(root(), "Could not find _bakepipe.R")
  
  # Cleanup
  setwd(old_wd)
  unlink(test_dir, recursive = TRUE)
})