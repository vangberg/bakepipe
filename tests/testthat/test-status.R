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
  
  # Should contain table headers
  expect_true(any(grepl("Script", output)))
  expect_true(any(grepl("Inputs", output)))
  expect_true(any(grepl("Outputs", output)))
  
  # Should contain script names
  expect_true(any(grepl("analysis.R", output)))
  expect_true(any(grepl("report_generation.R", output)))
  
  # Should contain file dependencies
  expect_true(any(grepl("sales.csv", output)))
  expect_true(any(grepl("monthly_sales.csv", output)))
  expect_true(any(grepl("regions.csv", output)))
  expect_true(any(grepl("quarterly_report.pdf", output)))
  
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
  
  # Should show the script but with empty dependencies
  expect_true(any(grepl("utilities.R", output)))
  expect_true(any(grepl("Script", output)))
  expect_true(any(grepl("Inputs", output)))
  expect_true(any(grepl("Outputs", output)))
  
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
  expect_true(any(grepl("No R scripts found", output)) || 
              any(grepl("empty", output, ignore.case = TRUE)))
  
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
  
  # Should show the dependency chain
  expect_true(any(grepl("input.csv", output)))
  expect_true(any(grepl("processed.csv", output)))
  expect_true(any(grepl("results.csv", output)))
  
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
  
  # Should show all inputs
  expect_true(any(grepl("raw_data.txt", output)))
  expect_true(any(grepl("metadata.csv", output)))
  
  # Should show all outputs
  expect_true(any(grepl("cleaned_data.csv", output)))
  expect_true(any(grepl("summary_stats.txt", output)))
  
  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})