test_that("read_state() creates and reads state file with checksums", {
  temp_dir <- tempdir()
  old_wd <- getwd()
  setwd(temp_dir)

  writeLines("# Bakepipe root marker", "_bakepipe.R")

  # Create test files
  writeLines("data,value\nA,1\nB,2", "input.csv")
  writeLines('
library(bakepipe)
data <- read.csv(file_in("input.csv"))
write.csv(data, file_out("output.csv"), row.names = FALSE)
', "process.R")

  on.exit({
    setwd(old_wd)
    unlink(c(file.path(temp_dir, "_bakepipe.R"),
             file.path(temp_dir, "input.csv"),
             file.path(temp_dir, "process.R"),
             file.path(temp_dir, "output.csv"),
             file.path(temp_dir, ".bakepipe.state")))
  })

  # First cache call should not create cache file (only read_state)
  state_obj <- read_state()

  # Cache file doesn't exist yet - will be created by write_state
  expect_false(file.exists(".bakepipe.state"))
  
  # Run pipeline to create cache file
  run()
  expect_true(file.exists(".bakepipe.state"))
  expect_type(state_obj, "list")
  expect_true("process.R" %in% names(state_obj))
  expect_true("input.csv" %in% names(state_obj))

  # Each entry should have checksum, last_modified, and status
  expect_true("checksum" %in% names(state_obj$"process.R"))
  expect_true("last_modified" %in% names(state_obj$"process.R"))
  expect_true("status" %in% names(state_obj$"process.R"))

  # All files should initially be marked as stale
  expect_equal(state_obj$"process.R"$status, "stale")
  expect_equal(state_obj$"input.csv"$status, "stale")
})

test_that("read_state() detects when script content changes", {
  temp_dir <- tempdir()
  old_wd <- getwd()
  setwd(temp_dir)

  writeLines("# Bakepipe root marker", "_bakepipe.R")

  # Create initial script
  script_content <- '
library(bakepipe)
data <- read.csv(file_in("input.csv"))
write.csv(data, file_out("output.csv"), row.names = FALSE)
'
  writeLines(script_content, "process.R")
  writeLines("data,value\nA,1\nB,2", "input.csv")

  on.exit({
    setwd(old_wd)
    unlink(c(file.path(temp_dir, "_bakepipe.R"),
             file.path(temp_dir, "input.csv"),
             file.path(temp_dir, "process.R"),
             file.path(temp_dir, "output.csv"),
             file.path(temp_dir, ".bakepipe.state")))
  })

  # First cache - all stale
  state_obj1 <- read_state()
  expect_equal(state_obj1$"process.R"$status, "stale")

  # Simulate running pipeline - mark as fresh
  write_state(parse())

  # Second cache - should be fresh since no changes
  state_obj2 <- read_state()
  expect_equal(state_obj2$"process.R"$status, "fresh")

  # Modify script content
  modified_script <- '
library(bakepipe)
data <- read.csv(file_in("input.csv"))
data$doubled <- data$value * 2
write.csv(data, file_out("output.csv"), row.names = FALSE)
'
  writeLines(modified_script, "process.R")

  # Third cache - should detect change and mark as stale
  state_obj3 <- read_state()
  expect_equal(state_obj3$"process.R"$status, "stale")
})

test_that("read_state() detects when artifact is manually modified", {
  temp_dir <- tempdir()
  old_wd <- getwd()
  setwd(temp_dir)

  writeLines("# Bakepipe root marker", "_bakepipe.R")

  writeLines("data,value\nA,1\nB,2", "input.csv")
  writeLines('
library(bakepipe)
data <- read.csv(file_in("input.csv"))
write.csv(data, file_out("output.csv"), row.names = FALSE)
', "process.R")

  # Create initial output
  writeLines("data,value\nA,1\nB,2", "output.csv")

  on.exit({
    setwd(old_wd)
    unlink(c(file.path(temp_dir, "_bakepipe.R"),
             file.path(temp_dir, "input.csv"),
             file.path(temp_dir, "process.R"),
             file.path(temp_dir, "output.csv"),
             file.path(temp_dir, ".bakepipe.state")))
  })

  # First cache and mark as fresh
  state_obj1 <- read_state()
  write_state(c("process.R"))

  # Second cache - should be fresh
  state_obj2 <- read_state()
  expect_equal(state_obj2$"output.csv"$status, "fresh")

  # Manually modify output file
  writeLines("data,value\nA,1\nB,2\nC,3", "output.csv")

  # Third cache - should detect artifact change
  state_obj3 <- read_state()
  expect_equal(state_obj3$"output.csv"$status, "stale")
})

test_that("manually modified artifact marks parent script and descendants as stale", {
  temp_dir <- tempdir()
  old_wd <- getwd()
  setwd(temp_dir)

  writeLines("# Bakepipe root marker", "_bakepipe.R")

  writeLines("data,value\nA,1\nB,2", "input.csv")

  # script1.R -> file.csv -> script2.R
  writeLines('
library(bakepipe)
data <- read.csv(file_in("input.csv"))
write.csv(data, file_out("file.csv"), row.names = FALSE)
', "script1.R")

  writeLines('
library(bakepipe)
data <- read.csv(file_in("file.csv"))
write.csv(data, file_out("final.csv"), row.names = FALSE)
', "script2.R")

  on.exit({
    setwd(old_wd)
    unlink(c(file.path(temp_dir, "_bakepipe.R"),
             file.path(temp_dir, "input.csv"),
             file.path(temp_dir, "script1.R"),
             file.path(temp_dir, "script2.R"),
             file.path(temp_dir, "file.csv"),
             file.path(temp_dir, "final.csv"),
             file.path(temp_dir, ".bakepipe.state")))
  })

  # Run pipeline first time to create all files
  run()

  # Get fresh cache state after run
  pipeline_data <- parse()
  state_obj <- read_state()
  graph_obj <- graph(pipeline_data, state_obj)

  # Verify all are fresh initially (after running)
  expect_false("script1.R" %in% graph_obj$stale_nodes)
  expect_false("script2.R" %in% graph_obj$stale_nodes)
  expect_false("file.csv" %in% graph_obj$stale_nodes)

  # Manually modify file.csv (intermediate artifact)
  writeLines("data,value\nA,1\nB,2\nC,3", "file.csv")

  # Re-create graph with updated cache
  state_obj2 <- read_state()
  graph_obj2 <- graph(pipeline_data, state_obj2)

  # Should mark script1.R (parent), file.csv (modified artifact), and script2.R + final.csv (descendants) as stale
  expect_true("script1.R" %in% graph_obj2$stale_nodes)  # Parent script
  expect_true("file.csv" %in% graph_obj2$stale_nodes)   # Modified artifact
  expect_true("script2.R" %in% graph_obj2$stale_nodes)  # Descendant script
  expect_true("final.csv" %in% graph_obj2$stale_nodes)  # Descendant artifact

  # input.csv should remain fresh (it wasn't modified)
  expect_false("input.csv" %in% graph_obj2$stale_nodes)
})

test_that("graph() with cache marks stale nodes correctly", {
  temp_dir <- tempdir()
  old_wd <- getwd()
  setwd(temp_dir)

  writeLines("# Bakepipe root marker", "_bakepipe.R")

  writeLines("data,value\nA,1\nB,2", "input.csv")
  writeLines('
library(bakepipe)
data <- read.csv(file_in("input.csv"))
write.csv(data, file_out("intermediate.csv"), row.names = FALSE)
', "step1.R")
  writeLines('
library(bakepipe)
data <- read.csv(file_in("intermediate.csv"))
write.csv(data, file_out("final.csv"), row.names = FALSE)
', "step2.R")

  on.exit({
    setwd(old_wd)
    unlink(c(file.path(temp_dir, "_bakepipe.R"),
             file.path(temp_dir, "input.csv"),
             file.path(temp_dir, "step1.R"),
             file.path(temp_dir, "step2.R"),
             file.path(temp_dir, "intermediate.csv"),
             file.path(temp_dir, "final.csv"),
             file.path(temp_dir, ".bakepipe.state")))
  })

  pipeline_data <- parse()
  state_obj <- read_state()

  # Create graph with cache - should mark stale nodes
  graph_obj <- graph(pipeline_data, state_obj)

  expect_true("stale_nodes" %in% names(graph_obj))
  expect_true("step1.R" %in% graph_obj$stale_nodes)
  expect_true("step2.R" %in% graph_obj$stale_nodes)
  expect_true("input.csv" %in% graph_obj$stale_nodes)

  # Mark step1 as fresh and test propagation
  state_obj_fresh <- state_obj
  state_obj_fresh$"step1.R"$status <- "fresh"
  state_obj_fresh$"input.csv"$status <- "fresh"
  state_obj_fresh$"intermediate.csv"$status <- "fresh"

  # Modify step2 to make it stale
  state_obj_fresh$"step2.R"$status <- "stale"

  graph_obj2 <- graph(pipeline_data, state_obj_fresh)

  # Only step2 and its outputs should be stale
  expect_true("step2.R" %in% graph_obj2$stale_nodes)
  expect_true("final.csv" %in% graph_obj2$stale_nodes)
  expect_false("step1.R" %in% graph_obj2$stale_nodes)
  expect_false("intermediate.csv" %in% graph_obj2$stale_nodes)
})

test_that("run() with incremental builds only executes stale scripts", {
  temp_dir <- tempdir()
  old_wd <- getwd()
  setwd(temp_dir)

  writeLines("# Bakepipe root marker", "_bakepipe.R")

  writeLines("data,value\nA,1\nB,2", "input.csv")

  # Create scripts that write to log files so we can track execution
  writeLines('
library(bakepipe)
cat("step1 executed\\n", file = "step1.log", append = TRUE)
data <- read.csv(file_in("input.csv"))
write.csv(data, file_out("intermediate.csv"), row.names = FALSE)
', "step1.R")

  writeLines('
library(bakepipe)
cat("step2 executed\\n", file = "step2.log", append = TRUE)
data <- read.csv(file_in("intermediate.csv"))
write.csv(data, file_out("final.csv"), row.names = FALSE)
', "step2.R")

  on.exit({
    setwd(old_wd)
    unlink(c(file.path(temp_dir, "_bakepipe.R"),
             file.path(temp_dir, "input.csv"),
             file.path(temp_dir, "step1.R"),
             file.path(temp_dir, "step2.R"),
             file.path(temp_dir, "intermediate.csv"),
             file.path(temp_dir, "final.csv"),
             file.path(temp_dir, "step1.log"),
             file.path(temp_dir, "step2.log"),
             file.path(temp_dir, ".bakepipe.state")))
  })

  # First run - should execute all scripts
  result1 <- run()

  expect_true(file.exists("step1.log"))
  expect_true(file.exists("step2.log"))
  expect_equal(length(readLines("step1.log")), 1)
  expect_equal(length(readLines("step2.log")), 1)

  # Second run - should execute no scripts (all fresh)
  result2 <- run()

  # Log files should not have additional entries
  expect_equal(length(readLines("step1.log")), 1)
  expect_equal(length(readLines("step2.log")), 1)
  expect_length(result2, 0)  # No files created

  # Modify step2 and run again - should only execute step2
  writeLines('
library(bakepipe)
cat("step2 executed\\n", file = "step2.log", append = TRUE)
data <- read.csv(file_in("intermediate.csv"))
data$doubled <- data$value * 2
write.csv(data, file_out("final.csv"), row.names = FALSE)
', "step2.R")

  result3 <- run()

  # step1 should not have been executed again, step2 should have
  expect_equal(length(readLines("step1.log")), 1)
  expect_equal(length(readLines("step2.log")), 2)
  expect_true("final.csv" %in% result3)
})

test_that("status() shows Fresh/Stale status", {
  temp_dir <- tempdir()
  old_wd <- getwd()
  setwd(temp_dir)

  writeLines("# Bakepipe root marker", "_bakepipe.R")

  writeLines("data,value\nA,1\nB,2", "input.csv")
  writeLines('
library(bakepipe)
data <- read.csv(file_in("input.csv"))
write.csv(data, file_out("output.csv"), row.names = FALSE)
', "process.R")

  on.exit({
    setwd(old_wd)
    unlink(c(file.path(temp_dir, "_bakepipe.R"),
             file.path(temp_dir, "input.csv"),
             file.path(temp_dir, "process.R"),
             file.path(temp_dir, "output.csv"),
             file.path(temp_dir, ".bakepipe.state")))
  })

  # Capture status output
  status_output <- capture.output(status())
  status_text <- paste(status_output, collapse = "\n")

  # Should show stale status initially
  expect_true(grepl("Stale", status_text) || grepl("stale", status_text))

  # Run pipeline and check status again
  run()

  status_output2 <- capture.output(status())
  status_text2 <- paste(status_output2, collapse = "\n")

  # Should show fresh status after running
  expect_true(grepl("Fresh", status_text2) || grepl("fresh", status_text2))
})