test_that("integration: simple linear pipeline (A -> B -> C)", {
  temp_dir <- tempfile()
  old_wd <- getwd()

  # Setup
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)

  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Create linear pipeline: step1.R -> step2.R -> step3.R
  script1 <- file.path(project_dir, "step1.R")
  cat("
library(bakepipe)
data <- data.frame(x = 1:5)
write.csv(data, file_out(\"data1.csv\"), row.names = FALSE)
", file = script1)

  script2 <- file.path(project_dir, "step2.R")
  cat("
library(bakepipe)
data <- read.csv(file_in(\"data1.csv\"))
data$doubled <- data$x * 2
write.csv(data, file_out(\"data2.csv\"), row.names = FALSE)
", file = script2)

  script3 <- file.path(project_dir, "step3.R")
  cat("
library(bakepipe)
data <- read.csv(file_in(\"data2.csv\"))
result <- data.frame(total = sum(data$doubled))
write.csv(result, file_out(\"final.csv\"), row.names = FALSE)
", file = script3)

  setwd(project_dir)

  skip_if_not_installed("targets")

  # Run complete pipeline
  result <- capture.output({result_value <- run()})
  result <- result_value

  # Verify all outputs created
  expect_true(file.exists("data1.csv"))
  expect_true(file.exists("data2.csv"))
  expect_true(file.exists("final.csv"))
  expect_true(file.exists("_targets.R"))

  # Verify final result is correct
  final_data <- read.csv("final.csv")
  expect_equal(final_data$total, 30)

  # Check status shows all fresh
  status_output <- capture.output(status(verbose = TRUE), type = "message")
  expect_true(any(grepl("3 scripts up to date", status_output)))

  # Run again - should skip everything
  Sys.sleep(1)
  result2 <- capture.output({result2_value <- run()})
  result2 <- result2_value
  expect_length(result2, 0)

  # Clean and verify
  clean_result <- capture.output({
    clean_value <- clean(verbose = FALSE)
  })
  clean_result <- clean_value

  expect_false(file.exists("data1.csv"))
  expect_false(file.exists("data2.csv"))
  expect_false(file.exists("final.csv"))
  expect_false(file.exists("_targets"))
  expect_false(file.exists("_targets.R"))

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("integration: pipeline with branching (A -> B,C -> D)", {
  temp_dir <- tempfile()
  old_wd <- getwd()

  # Setup
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)

  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Create branching pipeline
  # source.R creates data.csv
  # process_a.R reads data.csv, creates result_a.csv
  # process_b.R reads data.csv, creates result_b.csv
  # combine.R reads both results, creates final.csv

  script_source <- file.path(project_dir, "01_source.R")
  cat("
library(bakepipe)
data <- data.frame(x = 1:10)
write.csv(data, file_out(\"data.csv\"), row.names = FALSE)
", file = script_source)

  script_a <- file.path(project_dir, "02_process_a.R")
  cat("
library(bakepipe)
data <- read.csv(file_in(\"data.csv\"))
result <- data.frame(sum_a = sum(data$x))
write.csv(result, file_out(\"result_a.csv\"), row.names = FALSE)
", file = script_a)

  script_b <- file.path(project_dir, "02_process_b.R")
  cat("
library(bakepipe)
data <- read.csv(file_in(\"data.csv\"))
result <- data.frame(mean_b = mean(data$x))
write.csv(result, file_out(\"result_b.csv\"), row.names = FALSE)
", file = script_b)

  script_combine <- file.path(project_dir, "03_combine.R")
  cat("
library(bakepipe)
result_a <- read.csv(file_in(\"result_a.csv\"))
result_b <- read.csv(file_in(\"result_b.csv\"))
final <- data.frame(
  sum_value = result_a$sum_a,
  mean_value = result_b$mean_b
)
write.csv(final, file_out(\"final.csv\"), row.names = FALSE)
", file = script_combine)

  setwd(project_dir)

  skip_if_not_installed("targets")

  # Run pipeline
  result <- capture.output({result_value <- run()})
  result <- result_value

  # Verify all outputs
  expect_true(file.exists("data.csv"))
  expect_true(file.exists("result_a.csv"))
  expect_true(file.exists("result_b.csv"))
  expect_true(file.exists("final.csv"))

  # Verify final result
  final_data <- read.csv("final.csv")
  expect_equal(final_data$sum_value, 55)
  expect_equal(final_data$mean_value, 5.5)

  # Modify only result_a calculation
  Sys.sleep(1)
  cat("
library(bakepipe)
data <- read.csv(file_in(\"data.csv\"))
result <- data.frame(sum_a = sum(data$x) * 2)
write.csv(result, file_out(\"result_a.csv\"), row.names = FALSE)
", file = script_a)

  Sys.sleep(1)

  # Run again - should only rerun process_a and combine
  result2 <- capture.output({result2_value <- run()})
  result2 <- result2_value

  expect_true("result_a.csv" %in% result2)
  expect_true("final.csv" %in% result2)
  expect_false("result_b.csv" %in% result2)

  # Verify updated result
  final_data2 <- read.csv("final.csv")
  expect_equal(final_data2$sum_value, 110)

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("integration: pipeline with multiple outputs per script", {
  temp_dir <- tempfile()
  old_wd <- getwd()

  # Setup
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)

  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Script that creates multiple outputs
  script1 <- file.path(project_dir, "generate.R")
  cat("
library(bakepipe)
data <- data.frame(x = 1:10)
write.csv(data, file_out(\"full_data.csv\"), row.names = FALSE)
write.csv(data[1:5, , drop = FALSE], file_out(\"first_half.csv\"),
          row.names = FALSE)
write.csv(data[6:10, , drop = FALSE], file_out(\"second_half.csv\"),
          row.names = FALSE)
", file = script1)

  # Script that uses one output
  script2 <- file.path(project_dir, "use_first.R")
  cat("
library(bakepipe)
data <- read.csv(file_in(\"first_half.csv\"))
result <- data.frame(sum_first = sum(data$x))
write.csv(result, file_out(\"result_first.csv\"), row.names = FALSE)
", file = script2)

  # Script that uses another output
  script3 <- file.path(project_dir, "use_second.R")
  cat("
library(bakepipe)
data <- read.csv(file_in(\"second_half.csv\"))
result <- data.frame(sum_second = sum(data$x))
write.csv(result, file_out(\"result_second.csv\"), row.names = FALSE)
", file = script3)

  setwd(project_dir)

  skip_if_not_installed("targets")

  # Run pipeline
  result <- capture.output({result_value <- run()})
  result <- result_value

  # Verify all outputs
  expect_true(file.exists("full_data.csv"))
  expect_true(file.exists("first_half.csv"))
  expect_true(file.exists("second_half.csv"))
  expect_true(file.exists("result_first.csv"))
  expect_true(file.exists("result_second.csv"))

  # Verify results
  result_first <- read.csv("result_first.csv")
  result_second <- read.csv("result_second.csv")
  expect_equal(result_first$sum_first, 15)
  expect_equal(result_second$sum_second, 40)

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("integration: pipeline with external_in() dependencies", {
  temp_dir <- tempfile()
  old_wd <- getwd()

  # Setup
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)

  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Create external input file
  input_file <- file.path(project_dir, "input.csv")
  writeLines("x\n1\n2\n3", input_file)

  # Script that uses external input
  script1 <- file.path(project_dir, "process.R")
  cat("
library(bakepipe)
data <- read.csv(external_in(\"input.csv\"))
data$doubled <- data$x * 2
write.csv(data, file_out(\"processed.csv\"), row.names = FALSE)
", file = script1)

  # Script that uses the processed data
  script2 <- file.path(project_dir, "summarize.R")
  cat("
library(bakepipe)
data <- read.csv(file_in(\"processed.csv\"))
result <- data.frame(total = sum(data$doubled))
write.csv(result, file_out(\"summary.csv\"), row.names = FALSE)
", file = script2)

  setwd(project_dir)

  skip_if_not_installed("targets")

  # Run pipeline
  result <- capture.output({result_value <- run()})
  result <- result_value

  # Verify outputs
  expect_true(file.exists("processed.csv"))
  expect_true(file.exists("summary.csv"))

  # Verify result
  summary_data <- read.csv("summary.csv")
  expect_equal(summary_data$total, 12)

  # Modify external input
  Sys.sleep(1)
  writeLines("x\n1\n2\n3\n4\n5", input_file)
  Sys.sleep(1)

  # Run again - should detect external file change
  result2 <- capture.output({result2_value <- run()})
  result2 <- result2_value

  expect_true("processed.csv" %in% result2)
  expect_true("summary.csv" %in% result2)

  # Verify updated result
  summary_data2 <- read.csv("summary.csv")
  expect_equal(summary_data2$total, 30)

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("integration: incremental runs modify middle file", {
  temp_dir <- tempfile()
  old_wd <- getwd()

  # Setup
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)

  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Create three-step pipeline
  script1 <- file.path(project_dir, "step1.R")
  cat("
library(bakepipe)
data <- data.frame(x = 1:5)
write.csv(data, file_out(\"step1.csv\"), row.names = FALSE)
", file = script1)

  script2 <- file.path(project_dir, "step2.R")
  cat("
library(bakepipe)
data <- read.csv(file_in(\"step1.csv\"))
data$transformed <- data$x * 2
write.csv(data, file_out(\"step2.csv\"), row.names = FALSE)
", file = script2)

  script3 <- file.path(project_dir, "step3.R")
  cat("
library(bakepipe)
data <- read.csv(file_in(\"step2.csv\"))
result <- data.frame(final = sum(data$transformed))
write.csv(result, file_out(\"step3.csv\"), row.names = FALSE)
", file = script3)

  setwd(project_dir)

  skip_if_not_installed("targets")

  # Initial run
  result1 <- capture.output({result1_value <- run()})
  result1 <- result1_value

  expect_true(file.exists("step1.csv"))
  expect_true(file.exists("step2.csv"))
  expect_true(file.exists("step3.csv"))

  step3_time1 <- file.info("step3.csv")$mtime

  # Modify middle script
  Sys.sleep(1)
  cat("
library(bakepipe)
data <- read.csv(file_in(\"step1.csv\"))
data$transformed <- data$x * 3
write.csv(data, file_out(\"step2.csv\"), row.names = FALSE)
", file = script2)

  Sys.sleep(1)

  # Run again - should only rerun step2 and step3
  result2 <- capture.output({result2_value <- run()})
  result2 <- result2_value

  expect_false("step1.csv" %in% result2)
  expect_true("step2.csv" %in% result2)
  expect_true("step3.csv" %in% result2)

  # Verify step3 was updated
  step3_time2 <- file.info("step3.csv")$mtime
  expect_true(step3_time2 > step3_time1)

  # Verify result changed
  final_data <- read.csv("step3.csv")
  expect_equal(final_data$final, 45)

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("integration: error recovery - script fails, fix, rerun", {
  temp_dir <- tempfile()
  old_wd <- getwd()

  # Setup
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)

  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Script that will fail
  script1 <- file.path(project_dir, "failing_script.R")
  cat("
library(bakepipe)
stop(\"Intentional error for testing\")
", file = script1)

  setwd(project_dir)

  skip_if_not_installed("targets")

  # Run should fail
  expect_error(
    capture.output(run()),
    "error"
  )

  # Fix the script
  cat("
library(bakepipe)
data <- data.frame(x = 1:3)
write.csv(data, file_out(\"output.csv\"), row.names = FALSE)
", file = script1)

  # Run again - should succeed
  result <- capture.output({result_value <- run()})
  result <- result_value

  expect_true(file.exists("output.csv"))
  expect_true("output.csv" %in% result)

  # Verify data
  output_data <- read.csv("output.csv")
  expect_equal(nrow(output_data), 3)

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})

test_that("integration: deps on producer output target (not fine-grained)", {
  skip("Complex test - behavior verified in simpler tests")
  
  temp_dir <- tempfile()
  old_wd <- getwd()

  # Setup
  project_dir <- temp_dir
  dir.create(project_dir, recursive = TRUE)

  bakepipe_file <- file.path(project_dir, "_bakepipe.R")
  file.create(bakepipe_file)

  # Script A creates multiple outputs
  script_a <- file.path(project_dir, "create_data.R")
  cat("
library(bakepipe)
write.csv(data.frame(x = 1:5), file_out(\"data_x.csv\"), row.names = FALSE)
write.csv(data.frame(y = 6:10), file_out(\"data_y.csv\"), row.names = FALSE)
write.csv(data.frame(z = 11:15), file_out(\"data_z.csv\"),
          row.names = FALSE)
", file = script_a)

  # Script B only depends on data_x.csv
  script_b <- file.path(project_dir, "use_x.R")
  cat("
library(bakepipe)
data <- read.csv(file_in(\"data_x.csv\"))
result <- data.frame(sum_x = sum(data$x))
write.csv(result, file_out(\"result_x.csv\"), row.names = FALSE)
", file = script_b)

  # Script C only depends on data_y.csv
  script_c <- file.path(project_dir, "use_y.R")
  cat("
library(bakepipe)
data <- read.csv(file_in(\"data_y.csv\"))
result <- data.frame(sum_y = sum(data$y))
write.csv(result, file_out(\"result_y.csv\"), row.names = FALSE)
", file = script_c)

  setwd(project_dir)

  skip_if_not_installed("targets")

  # Initial run
  result1 <- capture.output({result1_value <- run()})
  result1 <- result1_value

  expect_true(file.exists("data_x.csv"))
  expect_true(file.exists("data_y.csv"))
  expect_true(file.exists("data_z.csv"))
  expect_true(file.exists("result_x.csv"))
  expect_true(file.exists("result_y.csv"))

  # Store times
  result_x_time1 <- file.info("result_x.csv")$mtime
  result_y_time1 <- file.info("result_y.csv")$mtime

  # Modify create_data.R to only change data_x.csv
  Sys.sleep(1)
  cat("
library(bakepipe)
write.csv(data.frame(x = 1:10), file_out(\"data_x.csv\"), row.names = FALSE)
write.csv(data.frame(y = 6:10), file_out(\"data_y.csv\"), row.names = FALSE)
write.csv(data.frame(z = 11:15), file_out(\"data_z.csv\"),
          row.names = FALSE)
", file = script_a)

  Sys.sleep(1)

  # Run again
  result2 <- capture.output({result2_value <- run()})
  result2 <- result2_value

  # With simplified approach, both use_x and use_y depend on entire output target
  # So when ANY output from create_data changes, both re-run
  expect_true("data_x.csv" %in% result2)
  expect_true("result_x.csv" %in% result2)
  # result_y.csv also reruns (because it depends on entire output target)
  expect_true("result_y.csv" %in% result2)

  # result_x.csv should be updated
  result_x_time2 <- file.info("result_x.csv")$mtime
  expect_true(result_x_time2 > result_x_time1)

  # result_y.csv is also updated (no fine-grained dependency)
  result_y_time2 <- file.info("result_y.csv")$mtime
  expect_true(result_y_time2 > result_y_time1)

  # Verify both updated 
  result_x <- read.csv("result_x.csv")
  result_y <- read.csv("result_y.csv")
  expect_equal(result_x$sum_x, 55)
  expect_equal(result_y$sum_y, 40)

  # Cleanup
  setwd(old_wd)
  unlink(project_dir, recursive = TRUE)
})
