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

test_that("status() displays artifacts table with file status", {
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
  
  # Create some of the input files (to test Present/Missing status)
  input_file <- file.path(project_dir, "input.csv")
  cat("col1,col2\n1,2\n3,4\n", file = input_file)
  
  # Change to project directory
  setwd(project_dir)
  
  # Test: status() should display both scripts and artifacts tables
  output <- capture.output(status())
  
  # Should contain Scripts section
  expect_true(any(grepl("Scripts", output)))
  
  # Should contain Artifacts section
  expect_true(any(grepl("Artifacts", output)))
  
  # Should show artifact names
  expect_true(any(grepl("input.csv", output)))
  expect_true(any(grepl("output.csv", output)))
  expect_true(any(grepl("analysis.csv", output)))
  
  # Should show file status
  expect_true(any(grepl("Present", output)))
  expect_true(any(grepl("Missing", output)))
  
  # Should show Status column header
  expect_true(any(grepl("Status", output)))
  
  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("status() shows two separate tables for scripts and artifacts", {
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
  
  # Test: status() should show distinct sections
  output <- capture.output(status())
  
  # Should have Scripts section
  scripts_start <- which(grepl("Scripts", output))
  expect_true(length(scripts_start) > 0)
  
  # Should have Artifacts section
  artifacts_start <- which(grepl("Artifacts", output))
  expect_true(length(artifacts_start) > 0)
  
  # Scripts section should come before Artifacts section
  expect_true(scripts_start[1] < artifacts_start[1])
  
  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("status() displays scripts and artifacts in topological order", {
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
  
  # Find the Artifacts section start
  artifacts_start <- which(grepl("Artifacts:", output))[1]

  # Find artifacts in the artifacts section only
  artifacts_lines <- output[(artifacts_start + 1):length(output)]
  raw_line <- which(grepl("raw.csv", artifacts_lines))[1] + artifacts_start
  step1_line <- which(grepl("step1.csv", artifacts_lines))[1] + artifacts_start
  step2_line <- which(grepl("step2.csv", artifacts_lines))[1] + artifacts_start
  final_line <- which(grepl("final.csv", artifacts_lines))[1] + artifacts_start

  # Artifacts should appear in dependency order
  expect_true(raw_line < step1_line)
  expect_true(step1_line < step2_line)
  expect_true(step2_line < final_line)
  
  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})