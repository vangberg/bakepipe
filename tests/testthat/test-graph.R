test_that("graph() creates correct DAG structure from parse output", {
  # Test data structure from the GitHub issue
  parse_data <- list(
    "analysis.R" = list(
      inputs = c("sales.csv"),
      outputs = c("monthly_sales.csv")
    ),
    "report_generation.R" = list(
      inputs = c("monthly_sales.csv", "regions.csv"),
      outputs = c("quarterly_report.pdf")
    ),
    "data_cleaning.R" = list(
      inputs = c("raw_data.txt"),
      outputs = c("cleaned_data.csv", "summary_stats.txt")
    )
  )
  
  graph <- graph(parse_data)
  
  # Should return a list with nodes and edges
  expect_type(graph, "list")
  expect_true("nodes" %in% names(graph))
  expect_true("edges" %in% names(graph))
  expect_true("adjacency_list" %in% names(graph))
  
  # Nodes should include both scripts and artifacts
  nodes <- graph$nodes
  expect_true("analysis.R" %in% nodes)
  expect_true("report_generation.R" %in% nodes)
  expect_true("data_cleaning.R" %in% nodes)
  expect_true("sales.csv" %in% nodes)
  expect_true("monthly_sales.csv" %in% nodes)
  expect_true("regions.csv" %in% nodes)
  expect_true("quarterly_report.pdf" %in% nodes)
  expect_true("raw_data.txt" %in% nodes)
  expect_true("cleaned_data.csv" %in% nodes)
  expect_true("summary_stats.txt" %in% nodes)
  
  # Should have adjacency list for efficient graph operations
  adj_list <- graph$adjacency_list
  expect_type(adj_list, "list")
  
  # Check specific dependencies
  # sales.csv -> analysis.R -> monthly_sales.csv -> report_generation.R
  expect_true("analysis.R" %in% adj_list[["sales.csv"]])
  expect_true("monthly_sales.csv" %in% adj_list[["analysis.R"]])
  expect_true("report_generation.R" %in% adj_list[["monthly_sales.csv"]])
})

test_that("graph() detects cyclic dependencies", {
  # Create cyclic dependency: A -> B -> C -> A
  parse_data <- list(
    "script_a.R" = list(
      inputs = c("file_c.csv"),
      outputs = c("file_a.csv")
    ),
    "script_b.R" = list(
      inputs = c("file_a.csv"),
      outputs = c("file_b.csv")
    ),
    "script_c.R" = list(
      inputs = c("file_b.csv"),
      outputs = c("file_c.csv")
    )
  )
  
  expect_error(graph(parse_data), "Cycle detected")
})

test_that("graph() validates single producer per artifact", {
  # Two scripts producing the same output file
  parse_data <- list(
    "script1.R" = list(
      inputs = c("input.csv"),
      outputs = c("duplicate_output.csv")
    ),
    "script2.R" = list(
      inputs = c("other_input.csv"),
      outputs = c("duplicate_output.csv")
    )
  )
  
  expect_error(graph(parse_data), "multiple producers")
})

test_that("graph() supports topological sorting", {
  parse_data <- list(
    "analysis.R" = list(
      inputs = c("sales.csv"),
      outputs = c("monthly_sales.csv")
    ),
    "report_generation.R" = list(
      inputs = c("monthly_sales.csv", "regions.csv"),
      outputs = c("quarterly_report.pdf")
    )
  )
  
  graph_obj <- graph(parse_data)
  topo_order <- topological_sort(graph_obj)
  
  expect_type(topo_order, "character")
  
  # Scripts should be in correct order
  analysis_pos <- which(topo_order == "analysis.R")
  report_pos <- which(topo_order == "report_generation.R")
  expect_true(analysis_pos < report_pos)
  
  # Input artifacts should come before scripts that use them
  sales_pos <- which(topo_order == "sales.csv")
  regions_pos <- which(topo_order == "regions.csv")
  expect_true(sales_pos < analysis_pos)
  expect_true(regions_pos < report_pos)
  
  # Output artifacts should come after scripts that produce them
  monthly_pos <- which(topo_order == "monthly_sales.csv")
  report_file_pos <- which(topo_order == "quarterly_report.pdf")
  expect_true(analysis_pos < monthly_pos)
  expect_true(report_pos < report_file_pos)
})

test_that("graph() finds descendants for stale marking", {
  parse_data <- list(
    "analysis.R" = list(
      inputs = c("sales.csv"),
      outputs = c("monthly_sales.csv")
    ),
    "report_generation.R" = list(
      inputs = c("monthly_sales.csv", "regions.csv"),
      outputs = c("quarterly_report.pdf")
    )
  )
  
  graph_obj <- graph(parse_data)
  
  # Find descendants of sales.csv
  descendants <- find_descendants(graph_obj, "sales.csv")
  
  expect_true("analysis.R" %in% descendants)
  expect_true("monthly_sales.csv" %in% descendants)
  expect_true("report_generation.R" %in% descendants)
  expect_true("quarterly_report.pdf" %in% descendants)
  
  # Find descendants of monthly_sales.csv (should not include analysis.R)
  descendants2 <- find_descendants(graph_obj, "monthly_sales.csv")
  expect_false("analysis.R" %in% descendants2)
  expect_true("report_generation.R" %in% descendants2)
  expect_true("quarterly_report.pdf" %in% descendants2)
})

test_that("graph() handles empty parse data", {
  parse_data <- list()
  
  graph_obj <- graph(parse_data)
  
  expect_type(graph_obj, "list")
  expect_equal(length(graph_obj$nodes), 0)
  expect_equal(length(graph_obj$adjacency_list), 0)
})

test_that("graph() handles scripts with no dependencies", {
  parse_data <- list(
    "standalone.R" = list(
      inputs = character(0),
      outputs = character(0)
    ),
    "producer.R" = list(
      inputs = character(0),
      outputs = c("data.csv")
    )
  )
  
  graph_obj <- graph(parse_data)
  
  expect_true("standalone.R" %in% graph_obj$nodes)
  expect_true("producer.R" %in% graph_obj$nodes)
  expect_true("data.csv" %in% graph_obj$nodes)
  
  # Standalone script should have no connections
  expect_equal(length(graph_obj$adjacency_list[["standalone.R"]]), 0)
  
  # Producer should connect to its output
  expect_true("data.csv" %in% graph_obj$adjacency_list[["producer.R"]])
})

test_that("topological_sort() returns scripts in dependency order", {
  parse_data <- list(
    "step3.R" = list(
      inputs = c("intermediate2.csv"),
      outputs = c("final.csv")
    ),
    "step1.R" = list(
      inputs = c("raw.csv"),
      outputs = c("intermediate1.csv")
    ),
    "step2.R" = list(
      inputs = c("intermediate1.csv"),
      outputs = c("intermediate2.csv")
    )
  )
  
  graph_obj <- graph(parse_data)
  topo_order <- topological_sort(graph_obj)
  
  # Extract just the scripts
  script_order <- topo_order[grepl("\\.R$", topo_order)]
  
  expect_equal(script_order, c("step1.R", "step2.R", "step3.R"))
})