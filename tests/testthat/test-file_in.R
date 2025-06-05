test_that("file_in returns path unchanged", {
  expect_equal(file_in("test.csv"), "test.csv")
  expect_equal(file_in("data/input.rds"), "data/input.rds")
  expect_equal(file_in("/absolute/path/file.txt"), "/absolute/path/file.txt")
})

test_that("file_in works with different file types", {
  expect_equal(file_in("data.csv"), "data.csv")
  expect_equal(file_in("results.rds"), "results.rds")
  expect_equal(file_in("analysis.fst"), "analysis.fst")
})

test_that("file_in preserves exact input", {
  path_with_spaces <- "file with spaces.csv"
  expect_equal(file_in(path_with_spaces), path_with_spaces)
  
  empty_string <- ""
  expect_equal(file_in(empty_string), empty_string)
})