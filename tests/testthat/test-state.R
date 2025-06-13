test_that("read_state() reads existing state file correctly", {
  # Create temporary directory and state file
  temp_dir <- tempdir()
  state_file <- file.path(temp_dir, ".bakepipe.state")
  
  # Create test state file content
  state_content <- c(
    '"file","checksum","last_modified","status"',
    '"script1.R","abc123","2023-01-01 10:00:00","fresh"',
    '"data.csv","def456","2023-01-01 09:00:00","fresh"',
    '"output.csv","ghi789","2023-01-01 11:00:00","fresh"'
  )
  writeLines(state_content, state_file)
  
  # Test reading state file
  state_obj <- read_state(state_file)
  
  expect_type(state_obj, "list")
  expect_true("files" %in% names(state_obj))
  expect_equal(nrow(state_obj$files), 3)
  expect_true(all(c("file", "checksum", "last_modified", "status") %in% names(state_obj$files)))
  
  # Check specific entries
  expect_true("script1.R" %in% state_obj$files$file)
  expect_true("data.csv" %in% state_obj$files$file)
  expect_true("output.csv" %in% state_obj$files$file)
  
  # Clean up
  unlink(state_file)
})

test_that("read_state() handles missing state file", {
  # Test with non-existent state file
  non_existent_file <- file.path(tempdir(), "non_existent.state")
  
  state_obj <- read_state(non_existent_file)
  
  expect_type(state_obj, "list")
  expect_true("files" %in% names(state_obj))
  expect_equal(nrow(state_obj$files), 0)
})

test_that("read_state() computes current checksums and detects stale files", {
  temp_dir <- tempdir()
  
  # Create test files with known content
  test_script <- file.path(temp_dir, "test.R")
  test_input <- file.path(temp_dir, "input.csv")
  test_output <- file.path(temp_dir, "output.csv")
  
  writeLines(c("# Test script", "data <- read.csv('input.csv')", "write.csv(data, 'output.csv')"), test_script)
  writeLines(c("name,value", "A,1", "B,2"), test_input)
  writeLines(c("name,value", "A,1", "B,2"), test_output)
  
  # Parse data to understand file relationships
  parse_data <- list(
    "test.R" = list(inputs = c("input.csv"), outputs = c("output.csv"))
  )
  
  # Create state file with old checksums (intentionally wrong)
  state_file <- file.path(temp_dir, ".bakepipe.state")
  state_content <- c(
    '"file","checksum","last_modified","status"',
    '"test.R","old_checksum","2023-01-01 10:00:00","fresh"',
    '"input.csv","old_checksum","2023-01-01 09:00:00","fresh"',
    '"output.csv","old_checksum","2023-01-01 11:00:00","fresh"'
  )
  writeLines(state_content, state_file)
  
  state_obj <- read_state(state_file)
  
  # Should detect files as stale due to checksum mismatch
  expect_true("current_checksums" %in% names(state_obj))
  expect_true("stale_files" %in% names(state_obj))
  
  # All files should be detected as stale due to checksum mismatch
  expect_true("test.R" %in% state_obj$stale_files)
  expect_true("input.csv" %in% state_obj$stale_files)
  expect_true("output.csv" %in% state_obj$stale_files)
  
  # Clean up
  unlink(c(test_script, test_input, test_output, state_file))
})

test_that("script staleness propagates when input file changes (integration test)", {
  temp_dir <- tempdir()
  old_wd <- getwd()
  
  # Work in temp directory to match relative paths
  setwd(temp_dir)
  
  # Create files
  writeLines(c("# Process script"), "process.R")
  writeLines(c("data,value", "A,1"), "input.csv")
  writeLines(c("result,final", "A,10"), "output.csv")
  
  parse_data <- list(
    "process.R" = list(inputs = c("input.csv"), outputs = c("output.csv"))
  )
  
  # Create state file with correct checksums initially
  write_state(".bakepipe.state", parse_data)
  
  # Modify input file
  writeLines(c("data,value", "A,2", "B,1"), "input.csv")
  
  # Read state - only the file should be marked stale by read_state()
  state_obj <- read_state(".bakepipe.state")
  expect_true("input.csv" %in% state_obj$stale_files)
  expect_false("process.R" %in% state_obj$stale_files)  # Script staleness handled by compute_stale_nodes
  
  # Create graph to test script staleness propagation
  graph_obj <- graph(parse_data, state_obj)
  expect_true("process.R" %in% graph_obj$stale_nodes)  # Script should be stale due to input change
  
  # Clean up
  setwd(old_wd)
  unlink(file.path(temp_dir, c("process.R", "input.csv", "output.csv", ".bakepipe.state")))
})

test_that("script staleness propagates when output file changes (integration test)", {
  temp_dir <- tempdir()
  old_wd <- getwd()
  
  # Work in temp directory to match relative paths
  setwd(temp_dir)
  
  # Create files
  writeLines(c("# Generate report"), "generate.R")
  writeLines(c("Original report content"), "report.txt")
  
  parse_data <- list(
    "generate.R" = list(inputs = character(0), outputs = c("report.txt"))
  )
  
  # Create state file
  write_state(".bakepipe.state", parse_data)
  
  # User manually edits output file
  writeLines(c("User modified report content"), "report.txt")
  
  # Read state - only the file should be marked stale by read_state()
  state_obj <- read_state(".bakepipe.state")
  expect_true("report.txt" %in% state_obj$stale_files)
  expect_false("generate.R" %in% state_obj$stale_files)  # Script staleness handled by compute_stale_nodes
  
  # Create graph to test script staleness propagation
  graph_obj <- graph(parse_data, state_obj)
  expect_true("generate.R" %in% graph_obj$stale_nodes)  # Script should be stale due to output change
  
  # Clean up
  setwd(old_wd)
  unlink(file.path(temp_dir, c("generate.R", "report.txt", ".bakepipe.state")))
})

test_that("write_state() creates correct state file format", {
  temp_dir <- tempdir()
  state_file <- file.path(temp_dir, ".bakepipe.state")
  
  # Create test files  
  test_script <- file.path(temp_dir, "script.R")
  test_input <- file.path(temp_dir, "data.csv")
  test_output <- file.path(temp_dir, "result.txt")
  
  writeLines(c("# Test script"), test_script)
  writeLines(c("col1,col2", "1,2"), test_input)
  writeLines(c("Results here"), test_output)
  
  # Parse data
  parse_data <- list(
    "script.R" = list(inputs = c("data.csv"), outputs = c("result.txt"))
  )
  
  # Write state
  write_state(state_file, parse_data)
  
  # Check file was created
  expect_true(file.exists(state_file))
  
  # Read and verify content
  state_data <- read.csv(state_file, stringsAsFactors = FALSE)
  expect_true(all(c("file", "checksum", "last_modified", "status") %in% names(state_data)))
  expect_true("script.R" %in% state_data$file)
  expect_true("data.csv" %in% state_data$file)
  expect_true("result.txt" %in% state_data$file)
  
  # All files should be marked as fresh
  expect_true(all(state_data$status == "fresh"))
  
  # Checksums should be valid (non-empty)
  expect_true(all(nchar(state_data$checksum) > 0))
  
  # Clean up
  unlink(c(test_script, test_input, test_output, state_file))
})

test_that("write_state() handles missing files gracefully", {
  temp_dir <- tempdir()
  state_file <- file.path(temp_dir, ".bakepipe.state")
  
  # Parse data with non-existent files
  parse_data <- list(
    "missing_script.R" = list(inputs = c("missing_input.csv"), outputs = c("missing_output.csv"))
  )
  
  # Should not error, but should handle missing files appropriately
  expect_no_error(write_state(state_file, parse_data))
  
  # Clean up
  if (file.exists(state_file)) unlink(state_file)
})

test_that("state functions work together for round-trip", {
  temp_dir <- tempdir()
  old_wd <- getwd()
  
  # Work in temp directory to match relative paths
  setwd(temp_dir)
  
  # Create files
  writeLines(c("# Process data"), "process.R")
  writeLines(c("name,score", "Alice,95"), "input.csv")
  writeLines(c("name,score", "Alice,95"), "output.csv")
  
  parse_data <- list(
    "process.R" = list(inputs = c("input.csv"), outputs = c("output.csv"))
  )
  
  # Write state
  write_state(".bakepipe.state", parse_data)
  
  # Read state back immediately - should be fresh
  state_obj <- read_state(".bakepipe.state")
  
  expect_equal(length(state_obj$stale_files), 0)
  expect_true(all(state_obj$files$status == "fresh"))
  
  # Clean up
  setwd(old_wd)
  unlink(file.path(temp_dir, c("process.R", "input.csv", "output.csv", ".bakepipe.state")))
})