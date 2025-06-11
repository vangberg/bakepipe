test_that("run() executes scripts in topological order", {
  temp_dir <- tempdir()
  old_wd <- getwd()
  setwd(temp_dir)

  writeLines("# Bakepipe root marker", "_bakepipe.R")

  writeLines("data,value\nA,1\nB,2", "input.csv")

  script1_content <- '
library(bakepipe)
data <- read.csv(file_in("input.csv"))
data$processed <- data$value * 2
write.csv(data, file_out("intermediate.csv"), row.names = FALSE)
'
  writeLines(script1_content, "01_process.R")

  script2_content <- '
library(bakepipe)
data <- read.csv(file_in("intermediate.csv"))
summary_data <- data.frame(total = sum(data$processed))
write.csv(summary_data, file_out("final.csv"), row.names = FALSE)
'
  writeLines(script2_content, "02_summarize.R")

  on.exit({
    setwd(old_wd)
    unlink(c(file.path(temp_dir, "_bakepipe.R"),
             file.path(temp_dir, "input.csv"),
             file.path(temp_dir, "01_process.R"),
             file.path(temp_dir, "02_summarize.R"),
             file.path(temp_dir, "intermediate.csv"),
             file.path(temp_dir, "final.csv")))
  })

  result <- run()

  expect_true(file.exists("intermediate.csv"))
  expect_true(file.exists("final.csv"))

  final_data <- read.csv("final.csv")
  expect_equal(final_data$total, 6)

  expect_type(result, "character")
  expect_true("intermediate.csv" %in% result)
  expect_true("final.csv" %in% result)
})

test_that("run() returns empty vector when no scripts exist", {
  temp_dir <- tempdir()
  old_wd <- getwd()
  setwd(temp_dir)

  writeLines("# Bakepipe root marker", "_bakepipe.R")

  on.exit({
    setwd(old_wd)
    unlink(file.path(temp_dir, "_bakepipe.R"))
  })

  result <- run()
  expect_type(result, "character")
  expect_length(result, 0)
})

test_that("run() handles scripts with no outputs", {
  temp_dir <- tempdir()
  old_wd <- getwd()
  setwd(temp_dir)

  writeLines("# Bakepipe root marker", "_bakepipe.R")

  writeLines("data,value\nA,1\nB,2", "input.csv")

  script_content <- '
library(bakepipe)
data <- read.csv(file_in("input.csv"))
cat("Processing", nrow(data), "rows\n")
'
  writeLines(script_content, "process.R")

  on.exit({
    setwd(old_wd)
    unlink(c(file.path(temp_dir, "_bakepipe.R"),
             file.path(temp_dir, "input.csv"),
             file.path(temp_dir, "process.R")))
  })

  result <- run()
  expect_type(result, "character")
  expect_length(result, 0)
})

test_that("run() stops on script execution error", {
  temp_dir <- tempdir()
  old_wd <- getwd()
  setwd(temp_dir)

  writeLines("# Bakepipe root marker", "_bakepipe.R")

  script_content <- '
library(bakepipe)
stop("Script error for testing")
'
  writeLines(script_content, "error_script.R")

  on.exit({
    setwd(old_wd)
    unlink(c(file.path(temp_dir, "_bakepipe.R"),
             file.path(temp_dir, "error_script.R")))
  })

  expect_error(run(), "Script error for testing")
})

test_that("run() respects dependency order", {
  temp_dir <- tempdir()
  old_wd <- getwd()
  setwd(temp_dir)

  writeLines("# Bakepipe root marker", "_bakepipe.R")

  writeLines("1,2,3", "data.csv")

  script1_content <- '
library(bakepipe)
data <- readLines(file_in("data.csv"))
writeLines(paste("step1:", data), file_out("step1.txt"))
'
  writeLines(script1_content, "01_first.R")

  script2_content <- '
library(bakepipe)
data <- readLines(file_in("step1.txt"))
writeLines(paste("step2:", data), file_out("step2.txt"))
'
  writeLines(script2_content, "02_second.R")

  on.exit({
    setwd(old_wd)
    unlink(c(file.path(temp_dir, "_bakepipe.R"),
             file.path(temp_dir, "data.csv"),
             file.path(temp_dir, "01_first.R"),
             file.path(temp_dir, "02_second.R"),
             file.path(temp_dir, "step1.txt"),
             file.path(temp_dir, "step2.txt")))
  })

  result <- run()

  expect_true(file.exists("step1.txt"))
  expect_true(file.exists("step2.txt"))

  step2_content <- readLines("step2.txt")
  expect_true(grepl("step2: step1: 1,2,3", step2_content))

  expect_true("step1.txt" %in% result)
  expect_true("step2.txt" %in% result)
})