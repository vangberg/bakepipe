test_that("parse() returns correct structure for scripts with file_in and file_out", {
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
  
  # Test: parse() should return correct structure
  result <- parse()
  
  expect_type(result, "list")
  expect_length(result, 4)  # scripts, inputs, outputs, externals
  expect_true("scripts" %in% names(result))
  expect_true("inputs" %in% names(result))
  expect_true("outputs" %in% names(result))
  expect_true("externals" %in% names(result))
  
  # Check scripts structure
  scripts <- result$scripts
  expect_length(scripts, 2)
  expect_true("analysis.R" %in% names(scripts))
  expect_true("report_generation.R" %in% names(scripts))
  
  # Check analysis.R structure
  analysis_result <- scripts[["analysis.R"]]
  expect_type(analysis_result, "list")
  expect_true("inputs" %in% names(analysis_result))
  expect_true("outputs" %in% names(analysis_result))
  expect_equal(analysis_result$inputs, "sales.csv")
  expect_equal(analysis_result$outputs, "monthly_sales.csv")
  
  # Check report_generation.R structure
  report_result <- scripts[["report_generation.R"]]
  expect_type(report_result, "list")
  expect_equal(sort(report_result$inputs), c("monthly_sales.csv", "regions.csv"))
  expect_equal(report_result$outputs, "quarterly_report.pdf")
  
  # Check top-level inputs and outputs
  expect_true("sales.csv" %in% result$inputs)
  expect_true("monthly_sales.csv" %in% result$inputs)
  expect_true("regions.csv" %in% result$inputs)
  expect_true("monthly_sales.csv" %in% result$outputs)
  expect_true("quarterly_report.pdf" %in% result$outputs)
  
  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("parse() handles scripts with no file_in or file_out calls", {
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
  
  # Test: parse() should handle scripts with no dependencies
  result <- parse()
  
  expect_type(result, "list")
  expect_length(result, 4)  # scripts, inputs, outputs, externals
  expect_true("scripts" %in% names(result))
  expect_length(result$scripts, 1)
  expect_true("utilities.R" %in% names(result$scripts))
  
  utilities_result <- result$scripts[["utilities.R"]]
  expect_type(utilities_result, "list")
  expect_equal(utilities_result$inputs, character(0))
  expect_equal(utilities_result$outputs, character(0))
  
  # Check top-level inputs, outputs, and externals are empty
  expect_equal(result$inputs, character(0))
  expect_equal(result$outputs, character(0))
  expect_equal(result$externals, character(0))
  
  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("parse() fails when file_in or file_out uses non-string literals", {
  # Create a temporary directory structure
  temp_dir <- tempfile()
  old_wd <- getwd()
  
  # Setup: Create a temporary project directory
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)
  
  # Create _bakepipe.R in the project root
  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)
  
  # Create script with variable in file_in call
  bad_script1 <- file.path(project_dir, "bad_file_in.R")
  cat('
f1 <- "file.csv"
data <- read.csv(file_in(f1))
', file = bad_script1)
  
  # Change to project directory
  setwd(project_dir)
  
  # Test: parse() should fail with non-string literal in file_in
  expect_error(parse(), "only.*string.*literal")
  
  # Cleanup and setup for file_out test
  unlink(bad_script1)
  
  # Create script with variable in file_out call
  bad_script2 <- file.path(project_dir, "bad_file_out.R")
  cat('
f2 <- "output.csv"
write.csv(data, file_out(f2))
', file = bad_script2)
  
  # Test: parse() should fail with non-string literal in file_out
  expect_error(parse(), "only.*string.*literal")
  
  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("parse() handles multiple file_in and file_out calls in same script", {
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
  
  # Test: parse() should capture all inputs and outputs
  result <- parse()
  
  expect_type(result, "list")
  expect_length(result, 4)  # scripts, inputs, outputs, externals
  
  multi_result <- result$scripts[["data_cleaning.R"]]
  expect_equal(sort(multi_result$inputs), c("metadata.csv", "raw_data.txt"))
  expect_equal(sort(multi_result$outputs), c("cleaned_data.csv", "summary_stats.txt"))
  
  # Check top-level inputs and outputs
  expect_true("metadata.csv" %in% result$inputs)
  expect_true("raw_data.txt" %in% result$inputs)
  expect_true("cleaned_data.csv" %in% result$outputs)
  expect_true("summary_stats.txt" %in% result$outputs)
  
  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("parse() works with scripts in subdirectories", {
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
data <- read.csv(external_in("input.csv"))
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
  
  # Test: parse() should find scripts in subdirectories
  result <- parse()
  
  expect_type(result, "list")
  expect_length(result, 4)  # scripts, inputs, outputs, externals
  expect_true("main.R" %in% names(result$scripts))
  expect_true(file.path("analysis", "analyze.R") %in% names(result$scripts) || 
              "analysis/analyze.R" %in% names(result$scripts))
  
  # Check that the subdirectory script is parsed correctly
  sub_key <- names(result$scripts)[grepl("analyze.R", names(result$scripts))]
  sub_result <- result$scripts[[sub_key]]
  expect_equal(sub_result$inputs, "processed.csv")
  expect_equal(sub_result$outputs, "results.csv")
  
  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("parse() returns empty list when no R scripts found", {
  # Create a temporary directory structure
  temp_dir <- tempfile()
  old_wd <- getwd()
  
  # Setup: Create a project directory with no R scripts
  project_dir <- temp_dir
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
  
  # Test: parse() should return empty named list
  result <- parse()
  
  expect_type(result, "list")
  expect_length(result, 4)  # Still has scripts, inputs, outputs, externals structure
  expect_length(result$scripts, 0)
  expect_length(result$inputs, 0)
  expect_length(result$outputs, 0)
  expect_length(result$externals, 0)
  
  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("parse() handles different quote types in file paths", {
  # Create a temporary directory structure
  temp_dir <- tempfile()
  old_wd <- getwd()
  
  # Setup: Create a temporary project directory
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)
  
  # Create _bakepipe.R in the project root
  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)
  
  # Create script with both single and double quotes
  quote_script <- file.path(project_dir, "quotes.R")
  cat("
data1 <- read.csv(file_in('single_quote.csv'))
data2 <- read.csv(file_in(\"double_quote.csv\"))
write.csv(data1, file_out('output_single.csv'))
write.csv(data2, file_out(\"output_double.csv\"))
", file = quote_script)
  
  # Change to project directory
  setwd(project_dir)
  
  # Test: parse() should handle both quote types
  result <- parse()
  
  expect_type(result, "list")
  expect_length(result, 4)  # scripts, inputs, outputs, externals
  
  quote_result <- result$scripts[["quotes.R"]]
  expect_equal(sort(quote_result$inputs), c("double_quote.csv", "single_quote.csv"))
  expect_equal(sort(quote_result$outputs), c("output_double.csv", "output_single.csv"))
  
  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("parse() ignores file_in and file_out calls in comments", {
  # Create a temporary directory structure
  temp_dir <- tempfile()
  old_wd <- getwd()
  
  # Setup: Create a temporary project directory
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)
  
  # Create _bakepipe.R in the project root
  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)
  
  # Create script with commented file_in/file_out calls
  comment_script <- file.path(project_dir, "comments.R")
  cat('
# This is commented: file_in("ignored.csv")
data <- read.csv(external_in("real_input.csv"))
# write.csv(data, file_out("ignored_output.csv"))
write.csv(data, file_out("real_output.csv"))
', file = comment_script)
  
  # Change to project directory
  setwd(project_dir)
  
  # Test: parse() should ignore commented calls
  result <- parse()
  
  expect_type(result, "list")
  expect_length(result, 4)  # scripts, inputs, outputs, externals
  
  comment_result <- result$scripts[["comments.R"]]
  expect_equal(comment_result$externals, "real_input.csv")
  expect_equal(comment_result$outputs, "real_output.csv")
  
  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("parse() handles external_in calls correctly", {
  # Create a temporary directory structure
  temp_dir <- tempfile()
  old_wd <- getwd()
  
  # Setup: Create a temporary project directory
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)
  
  # Create _bakepipe.R in the project root
  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)
  
  # Create script with external_in calls
  external_script <- file.path(project_dir, "with_external.R")
  cat('
user_data <- read.csv(external_in("user_provided.csv"))
config <- readRDS(external_in("config.rds"))
processed <- process_data(user_data, config)
write.csv(processed, file_out("processed.csv"))
', file = external_script)
  
  # Change to project directory
  setwd(project_dir)
  
  # Test: parse() should extract external_in calls
  result <- parse()
  
  expect_type(result, "list")
  expect_length(result, 4)  # scripts, inputs, outputs, externals
  expect_true("externals" %in% names(result))
  
  # Check script structure
  script_result <- result$scripts[["with_external.R"]]
  expect_type(script_result, "list")
  expect_true("externals" %in% names(script_result))
  
  expect_equal(sort(script_result$externals), c("config.rds", "user_provided.csv"))
  expect_equal(script_result$outputs, "processed.csv")
  expect_equal(script_result$inputs, character(0))
  
  # Check top-level externals
  expect_equal(sort(result$externals), c("config.rds", "user_provided.csv"))
  
  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("parse() handles mixed file_in, external_in, and file_out calls", {
  # Create a temporary directory structure
  temp_dir <- tempfile()
  old_wd <- getwd()
  
  # Setup: Create a temporary project directory
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)
  
  # Create _bakepipe.R in the project root
  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)
  
  # Create test scripts with mixed calls
  script1_path <- file.path(project_dir, "clean.R")
  cat('
external_data <- read.csv(external_in("raw_data.csv"))
cleaned <- clean_data(external_data)
write.csv(cleaned, file_out("cleaned_data.csv"))
', file = script1_path)
  
  script2_path <- file.path(project_dir, "analyze.R")
  cat('
cleaned_data <- read.csv(file_in("cleaned_data.csv"))
config <- read.json(external_in("config.json"))
analysis <- analyze(cleaned_data, config)
write.csv(analysis, file_out("analysis_results.csv"))
', file = script2_path)
  
  # Change to project directory
  setwd(project_dir)
  
  # Test: parse() should handle all three types correctly
  result <- parse()
  
  expect_type(result, "list")
  expect_length(result, 4)  # scripts, inputs, outputs, externals
  
  # Check clean.R
  clean_result <- result$scripts[["clean.R"]]
  expect_equal(clean_result$externals, "raw_data.csv")
  expect_equal(clean_result$inputs, character(0))
  expect_equal(clean_result$outputs, "cleaned_data.csv")
  
  # Check analyze.R
  analyze_result <- result$scripts[["analyze.R"]]
  expect_equal(analyze_result$externals, "config.json")
  expect_equal(analyze_result$inputs, "cleaned_data.csv")
  expect_equal(analyze_result$outputs, "analysis_results.csv")
  
  # Check top-level aggregation
  expect_equal(sort(result$externals), c("config.json", "raw_data.csv"))
  expect_equal(result$inputs, "cleaned_data.csv")
  expect_equal(sort(result$outputs), c("analysis_results.csv", "cleaned_data.csv"))
  
  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})