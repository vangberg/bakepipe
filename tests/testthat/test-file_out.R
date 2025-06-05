test_that("file_out returns path unchanged", {
  expect_equal(file_out("output.csv"), "output.csv")
  expect_equal(file_out("results/final.rds"), "results/final.rds")
  expect_equal(file_out("/tmp/processed_data.txt"), "/tmp/processed_data.txt")
})

test_that("file_out works with different file types", {
  expect_equal(file_out("analysis.csv"), "analysis.csv")
  expect_equal(file_out("model.rds"), "model.rds")
  expect_equal(file_out("plot.png"), "plot.png")
})

test_that("file_out preserves exact input", {
  path_with_spaces <- "final results.csv"
  expect_equal(file_out(path_with_spaces), path_with_spaces)
  
  empty_string <- ""
  expect_equal(file_out(empty_string), empty_string)
})