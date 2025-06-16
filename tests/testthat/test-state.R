test_that("read_state() reads existing state file correctly", {
  # Create temporary directory and state file
  temp_dir <- tempdir()
  state_file <- file.path(temp_dir, ".bakepipe.state")
  
  # Create test state file content
  state_content <- c(
    '"file","checksum","last_modified"',
    '"script1.R","abc123","2023-01-01 10:00:00"',
    '"data.csv","def456","2023-01-01 09:00:00"',
    '"output.csv","ghi789","2023-01-01 11:00:00"'
  )
  writeLines(state_content, state_file)
  
  # Test reading state file
  state_df <- read_state(state_file)
  
  expect_s3_class(state_df, "data.frame")
  expect_true("script1.R" %in% state_df$file)
  expect_true("data.csv" %in% state_df$file)
  expect_true("output.csv" %in% state_df$file)
  
  # Check that all files are marked as stale since they don't exist with those checksums
  expect_true(all(state_df$stale))
  
  # Check data frame structure
  expect_equal(ncol(state_df), 2)
  expect_equal(colnames(state_df), c("file", "stale"))
  
  # Clean up
  unlink(state_file)
})

test_that("read_state() handles missing state file", {
  # Test with non-existent state file
  non_existent_file <- file.path(tempdir(), "non_existent.state")
  
  state_df <- read_state(non_existent_file)
  
  expect_s3_class(state_df, "data.frame")
  expect_equal(nrow(state_df), 0)
  expect_equal(ncol(state_df), 2)
  expect_equal(colnames(state_df), c("file", "stale"))
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
    scripts = list(
      "test.R" = list(inputs = c("input.csv"), outputs = c("output.csv"))
    ),
    inputs = c("input.csv"),
    outputs = c("output.csv")
  )
  
  # Create state file with old checksums (intentionally wrong)
  state_file <- file.path(temp_dir, ".bakepipe.state")
  state_content <- c(
    '"file","checksum","last_modified"',
    '"test.R","old_checksum","2023-01-01 10:00:00"',
    '"input.csv","old_checksum","2023-01-01 09:00:00"',
    '"output.csv","old_checksum","2023-01-01 11:00:00"'
  )
  writeLines(state_content, state_file)
  
  state_df <- read_state(state_file)
  
  # Should detect files as stale due to checksum mismatch
  stale_files <- state_df$file[state_df$stale]
  
  # All files should be detected as stale due to checksum mismatch
  expect_true("test.R" %in% stale_files)
  expect_true("input.csv" %in% stale_files)
  expect_true("output.csv" %in% stale_files)
  
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
    scripts = list(
      "process.R" = list(inputs = c("input.csv"), outputs = c("output.csv"))
    ),
    inputs = c("input.csv"),
    outputs = c("output.csv")
  )
  
  # Create state file with correct checksums initially
  write_state(".bakepipe.state", parse_data)
  
  # Modify input file
  writeLines(c("data,value", "A,2", "B,1"), "input.csv")
  
  # Read state - only the file should be marked stale by read_state()
  state_df <- read_state(".bakepipe.state")
  stale_files <- state_df$file[state_df$stale]
  expect_true("input.csv" %in% stale_files)
  expect_false("process.R" %in% stale_files)  # Script staleness handled by compute_stale_nodes
  
  # Create graph to test script staleness propagation
  graph_obj <- graph(parse_data, state_df)
  process_stale <- graph_obj$nodes$stale[graph_obj$nodes$file == "process.R"]
  expect_true(process_stale)  # Script should be stale due to input change
  
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
    scripts = list(
      "generate.R" = list(inputs = character(0), outputs = c("report.txt"))
    ),
    inputs = character(0),
    outputs = c("report.txt")
  )
  
  # Create state file
  write_state(".bakepipe.state", parse_data)
  
  # User manually edits output file
  writeLines(c("User modified report content"), "report.txt")
  
  # Read state - only the file should be marked stale by read_state()
  state_df <- read_state(".bakepipe.state")
  stale_files <- state_df$file[state_df$stale]
  expect_true("report.txt" %in% stale_files)
  expect_false("generate.R" %in% stale_files)  # Script staleness handled by compute_stale_nodes
  
  # Create graph to test script staleness propagation
  graph_obj <- graph(parse_data, state_df)
  generate_stale <- graph_obj$nodes$stale[graph_obj$nodes$file == "generate.R"]
  expect_true(generate_stale)  # Script should be stale due to output change
  
  # Clean up
  setwd(old_wd)
  unlink(file.path(temp_dir, c("generate.R", "report.txt", ".bakepipe.state")))
})

test_that("write_state() creates correct state file format", {
  temp_dir <- tempdir()
  old_wd <- getwd()
  
  # Work in temp directory to match relative paths
  setwd(temp_dir)
  
  state_file <- ".bakepipe.state"
  
  # Create test files with relative names 
  writeLines(c("# Test script"), "script.R")
  writeLines(c("col1,col2", "1,2"), "data.csv")
  writeLines(c("Results here"), "result.txt")
  
  # Parse data
  parse_data <- list(
    scripts = list(
      "script.R" = list(inputs = c("data.csv"), outputs = c("result.txt"))
    ),
    inputs = c("data.csv"),
    outputs = c("result.txt")
  )
  
  # Write state
  write_state(state_file, parse_data)
  
  # Check file was created
  expect_true(file.exists(state_file))
  
  # Read and verify content using read_state()
  state_df <- read_state(state_file)
  expect_true("script.R" %in% state_df$file)
  expect_true("data.csv" %in% state_df$file)
  expect_true("result.txt" %in% state_df$file)
  
  # All files should be marked as fresh (since they exist and match their checksums)
  expect_false(state_df$stale[state_df$file == "script.R"])
  expect_false(state_df$stale[state_df$file == "data.csv"])
  expect_false(state_df$stale[state_df$file == "result.txt"])
  
  # Clean up
  setwd(old_wd)
  unlink(file.path(temp_dir, c("script.R", "data.csv", "result.txt", ".bakepipe.state")))
})

test_that("write_state() handles missing files gracefully", {
  temp_dir <- tempdir()
  state_file <- file.path(temp_dir, ".bakepipe.state")
  
  # Parse data with non-existent files
  parse_data <- list(
    scripts = list(
      "missing_script.R" = list(inputs = c("missing_input.csv"), outputs = c("missing_output.csv"))
    ),
    inputs = c("missing_input.csv"),
    outputs = c("missing_output.csv")
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
    scripts = list(
      "process.R" = list(inputs = c("input.csv"), outputs = c("output.csv"))
    ),
    inputs = c("input.csv"),
    outputs = c("output.csv")
  )
  
  # Write state
  write_state(".bakepipe.state", parse_data)
  
  # Read state back immediately - should be fresh
  state_df <- read_state(".bakepipe.state")
  
  stale_files <- state_df$file[state_df$stale]
  expect_equal(length(stale_files), 0)
  # Check that files exist in the data frame
  expect_true("process.R" %in% state_df$file)
  expect_true("input.csv" %in% state_df$file)
  expect_false(state_df$stale[state_df$file == "process.R"])
  
  # Clean up
  setwd(old_wd)
  unlink(file.path(temp_dir, c("process.R", "input.csv", "output.csv", ".bakepipe.state")))
})

test_that("read_state() returns data frame format with file and stale columns", {
  # Create temporary directory and state file
  temp_dir <- tempdir()
  state_file <- file.path(temp_dir, ".bakepipe.state")
  
  # Create test state file content
  state_content <- c(
    '"file","checksum","last_modified"',
    '"script1.R","abc123","2023-01-01 10:00:00"',
    '"data.csv","def456","2023-01-01 09:00:00"',
    '"output.csv","ghi789","2023-01-01 11:00:00"'
  )
  writeLines(state_content, state_file)
  
  # Test reading state file
  state_df <- read_state(state_file)
  
  # Should return data frame format with file and stale columns
  expect_s3_class(state_df, "data.frame")
  expect_equal(ncol(state_df), 2)
  expect_equal(colnames(state_df), c("file", "stale"))
  
  # Should contain all files
  expect_true("script1.R" %in% state_df$file)
  expect_true("data.csv" %in% state_df$file)
  expect_true("output.csv" %in% state_df$file)
  
  # All files should be stale since they don't exist with those checksums
  expect_true(all(state_df$stale))
  
  # Should be able to extract stale files
  stale_files <- state_df$file[state_df$stale]
  expect_type(stale_files, "character")
  expect_equal(length(stale_files), 3)
  
  # Clean up
  unlink(state_file)
})

test_that("read_state() data frame format detects stale files correctly", {
  temp_dir <- tempdir()
  
  # Create test files with known content
  test_script <- file.path(temp_dir, "test.R")
  test_input <- file.path(temp_dir, "input.csv")
  test_output <- file.path(temp_dir, "output.csv")
  
  writeLines(c("# Test script", "data <- read.csv('input.csv')", "write.csv(data, 'output.csv')"), test_script)
  writeLines(c("name,value", "A,1", "B,2"), test_input)
  writeLines(c("name,value", "A,1", "B,2"), test_output)
  
  # Create state file with old checksums (intentionally wrong)
  state_file <- file.path(temp_dir, ".bakepipe.state")
  state_content <- c(
    '"file","checksum","last_modified"',
    '"test.R","old_checksum","2023-01-01 10:00:00"',
    '"input.csv","old_checksum","2023-01-01 09:00:00"',
    '"output.csv","old_checksum","2023-01-01 11:00:00"'
  )
  writeLines(state_content, state_file)
  
  state_df <- read_state(state_file)
  
  # Should detect files as stale due to checksum mismatch
  stale_files <- state_df$file[state_df$stale]
  expect_true("test.R" %in% stale_files)
  expect_true("input.csv" %in% stale_files)
  expect_true("output.csv" %in% stale_files)
  
  # Individual files should be accessible in the data frame
  expect_true("test.R" %in% state_df$file)
  expect_true("input.csv" %in% state_df$file)
  expect_true("output.csv" %in% state_df$file)
  
  # Clean up
  unlink(c(test_script, test_input, test_output, state_file))
})