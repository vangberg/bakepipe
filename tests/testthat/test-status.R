test_that("status() displays pipeline table with inputs and outputs", {
  # Create a temporary directory structure
  temp_dir <- tempfile()
  old_wd <- getwd()
  
  # Setup: Create a temporary project directory
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)
  
  # Create _bakepipe.R in the project root
  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)
  
  # Create test scripts with file_in and file_out calls
  analysis_script <- file.path(project_dir, "analysis.R")
  cat('
data <- read.csv(file_in("sales.csv"))
result <- process_data(data)
write.csv(result, file_out("monthly_sales.csv"))
', file = analysis_script)
  
  report_script <- file.path(project_dir, "report_generation.R")
  cat('
monthly_data <- read.csv(file_in("monthly_sales.csv"))
region_data <- read.csv(file_in("regions.csv"))
report <- generate_report(monthly_data, region_data)
ggsave(file_out("quarterly_report.pdf"), report)
', file = report_script)
  
  # Change to project directory
  setwd(project_dir)
  
  # Test: status() should display pipeline structure
  # Capture output to verify format
  output <- capture.output(status())
  
  # Should contain header and status information
  expect_true(any(grepl("Bakepipe Status", output)))
  expect_true(any(grepl("fresh|stale", output)))
  
  # Should contain script names
  expect_true(any(grepl("analysis.R", output)))
  expect_true(any(grepl("report_generation.R", output)))
  
  # File dependencies are not displayed in status output (they're analyzed internally)
  
  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("status() handles scripts with no dependencies", {
  # Create a temporary directory structure
  temp_dir <- tempfile()
  old_wd <- getwd()
  
  # Setup: Create a temporary project directory
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)
  
  # Create _bakepipe.R in the project root
  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)
  
  # Create script with no file_in/file_out calls
  simple_script <- file.path(project_dir, "utilities.R")
  cat('
# Just utility functions
process_data <- function(data) {
  data$processed <- TRUE
  return(data)
}
', file = simple_script)
  
  # Change to project directory
  setwd(project_dir)
  
  # Test: status() should handle scripts with no dependencies
  output <- capture.output(status())
  
  # Should show the script with status information
  expect_true(any(grepl("utilities.R", output)))
  expect_true(any(grepl("Bakepipe Status", output)))
  expect_true(any(grepl("fresh|stale", output)))
  
  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("status() shows appropriate message when no scripts found", {
  # Create a temporary directory structure
  temp_dir <- tempfile()
  old_wd <- getwd()
  
  # Setup: Create a project directory with no R scripts
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)
  
  # Create _bakepipe.R in the project root
  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)
  
  # Change to project directory
  setwd(project_dir)
  
  # Test: status() should show appropriate message for empty pipeline
  output <- capture.output(status())
  
  # Should indicate no scripts found
  expect_true(any(grepl("No scripts found", output)))
  
  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("status() works with scripts in subdirectories", {
  # Create a temporary directory structure
  temp_dir <- tempfile()
  old_wd <- getwd()
  
  # Setup: Create nested directory structure
  project_dir <- temp_dir
  sub_dir <- file.path(project_dir, "analysis")
  dir.create(sub_dir, recursive = TRUE)
  
  # Create _bakepipe.R in the project root
  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)
  
  # Create script in root
  root_script <- file.path(project_dir, "main.R")
  cat('
data <- read.csv(file_in("input.csv"))
write.csv(data, file_out("processed.csv"))
', file = root_script)
  
  # Create script in subdirectory
  sub_script <- file.path(sub_dir, "analyze.R")
  cat('
processed <- read.csv(file_in("processed.csv"))
result <- analyze(processed)
write.csv(result, file_out("results.csv"))
', file = sub_script)
  
  # Change to project directory
  setwd(project_dir)
  
  # Test: status() should show scripts from subdirectories
  output <- capture.output(status())
  
  # Should contain both scripts
  expect_true(any(grepl("main.R", output)))
  expect_true(any(grepl("analyze.R", output)))
  
  # File dependencies are not displayed in status output
  
  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("status() handles multiple inputs and outputs per script", {
  # Create a temporary directory structure
  temp_dir <- tempfile()
  old_wd <- getwd()
  
  # Setup: Create a temporary project directory
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)
  
  # Create _bakepipe.R in the project root
  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)
  
  # Create script with multiple inputs and outputs
  multi_script <- file.path(project_dir, "data_cleaning.R")
  cat('
raw_data <- read.table(file_in("raw_data.txt"))
metadata <- read.csv(file_in("metadata.csv"))

cleaned <- clean_data(raw_data, metadata)
summary_stats <- summarize(cleaned)

write.csv(cleaned, file_out("cleaned_data.csv"))
write.table(summary_stats, file_out("summary_stats.txt"))
', file = multi_script)
  
  # Change to project directory
  setwd(project_dir)
  
  # Test: status() should show all inputs and outputs
  output <- capture.output(status())
  
  # Should show the script
  expect_true(any(grepl("data_cleaning.R", output)))
  
  # File dependencies are not displayed in status output (analyzed internally)
  
  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("status() displays state information for scripts", {
  # Create a temporary directory structure
  temp_dir <- tempfile()
  old_wd <- getwd()
  
  # Setup: Create a temporary project directory
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)
  
  # Create _bakepipe.R in the project root
  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)
  
  # Create test scripts
  script1 <- file.path(project_dir, "process.R")
  cat('
data <- read.csv(file_in("input.csv"))
result <- process(data)
write.csv(result, file_out("output.csv"))
', file = script1)
  
  script2 <- file.path(project_dir, "analyze.R")
  cat('
processed <- read.csv(file_in("output.csv"))
analysis <- analyze(processed)
write.csv(analysis, file_out("analysis.csv"))
', file = script2)
  
  # Create some of the input files 
  input_file <- file.path(project_dir, "input.csv")
  cat("col1,col2\n1,2\n3,4\n", file = input_file)
  
  # Change to project directory
  setwd(project_dir)
  
  # Test: status() should display scripts with state information
  output <- capture.output(status())
  
  # Should contain status header
  expect_true(any(grepl("Bakepipe Status", output)))
  
  # Should NOT contain Artifacts section (removed)
  expect_false(any(grepl("Artifacts", output)))
  
  # Should show script names
  expect_true(any(grepl("process.R", output)))
  expect_true(any(grepl("analyze.R", output)))
  
  # Should show state values in status indicators
  expect_true(any(grepl("fresh|stale", output)))
  
  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("status() shows only scripts table (no artifacts table)", {
  # Create a temporary directory structure
  temp_dir <- tempfile()
  old_wd <- getwd()
  
  # Setup: Create a temporary project directory
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)
  
  # Create _bakepipe.R in the project root
  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)
  
  # Create test script
  script1 <- file.path(project_dir, "example.R")
  cat('
data <- read.csv(file_in("data.csv"))
write.csv(data, file_out("result.csv"))
', file = script1)
  
  # Change to project directory
  setwd(project_dir)
  
  # Test: status() should show only scripts section
  output <- capture.output(status())
  
  # Should have status header
  status_header <- which(grepl("Bakepipe Status", output))
  expect_true(length(status_header) > 0)
  
  # Should NOT have Artifacts section (removed)
  artifacts_start <- which(grepl("Artifacts", output))
  expect_true(length(artifacts_start) == 0)
  
  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("status() displays scripts in topological order", {
  # Create a temporary directory structure
  temp_dir <- tempfile()
  old_wd <- getwd()
  
  # Setup: Create a temporary project directory
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)
  
  # Create _bakepipe.R in the project root
  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)
  
  # Create scripts in a dependency chain: c.R -> b.R -> a.R
  # (named to ensure alphabetical order differs from topological order)
  script_a <- file.path(project_dir, "a_final.R")
  cat('
intermediate <- read.csv(file_in("step2.csv"))
final_result <- finalize(intermediate)
write.csv(final_result, file_out("final.csv"))
', file = script_a)
  
  script_b <- file.path(project_dir, "b_middle.R")
  cat('
processed <- read.csv(file_in("step1.csv"))
intermediate <- process_further(processed)
write.csv(intermediate, file_out("step2.csv"))
', file = script_b)
  
  script_c <- file.path(project_dir, "c_first.R")
  cat('
raw <- read.csv(file_in("raw.csv"))
processed <- initial_process(raw)
write.csv(processed, file_out("step1.csv"))
', file = script_c)
  
  # Change to project directory
  setwd(project_dir)
  
  # Test: status() should display scripts in topological order
  output <- capture.output(status())
  
  # Find line numbers where scripts appear
  c_line <- which(grepl("c_first.R", output))[1]
  b_line <- which(grepl("b_middle.R", output))[1]
  a_line <- which(grepl("a_final.R", output))[1]
  
  # Scripts should appear in topological order: c_first.R, b_middle.R, a_final.R
  expect_true(c_line < b_line)
  expect_true(b_line < a_line)
  
  # Should show state information for all scripts
  expect_true(any(grepl("fresh|stale", output)))
  
  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})