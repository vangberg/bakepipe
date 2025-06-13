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
  
  # Nodes should only include scripts, not files
  nodes <- graph$nodes
  expect_true("analysis.R" %in% nodes)
  expect_true("report_generation.R" %in% nodes)
  expect_true("data_cleaning.R" %in% nodes)
  expect_false("sales.csv" %in% nodes)
  expect_false("monthly_sales.csv" %in% nodes)
  expect_false("regions.csv" %in% nodes)
  expect_false("quarterly_report.pdf" %in% nodes)
  expect_false("raw_data.txt" %in% nodes)
  expect_false("cleaned_data.csv" %in% nodes)
  expect_false("summary_stats.txt" %in% nodes)
  
  # Check edges connect scripts through files
  edges <- graph$edges
  expect_true("file" %in% names(edges))
  # analysis.R produces monthly_sales.csv, report_generation.R consumes it
  expect_true(any(edges$from == "analysis.R" & edges$to == "report_generation.R" & edges$file == "monthly_sales.csv"))
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
  
  # Only scripts should be in the topological order
  expect_equal(length(topo_order), 2)
  expect_true(all(grepl("\\.R$", topo_order)))
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
  
  # Find descendants of analysis.R
  descendants <- find_descendants(graph_obj, "analysis.R")
  
  expect_true("report_generation.R" %in% descendants)
  expect_false("analysis.R" %in% descendants)
  
  # Find descendants of report_generation.R (should be empty)
  descendants2 <- find_descendants(graph_obj, "report_generation.R")
  expect_equal(length(descendants2), 0)
})

test_that("graph() handles empty parse data", {
  parse_data <- list()
  
  graph_obj <- graph(parse_data)
  
  expect_type(graph_obj, "list")
  expect_equal(length(graph_obj$nodes), 0)
  expect_equal(nrow(graph_obj$edges), 0)
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
  expect_false("data.csv" %in% graph_obj$nodes)
  
  # Check edges - standalone script should have no edges
  standalone_edges <- graph_obj$edges[graph_obj$edges$from == "standalone.R" | 
                                     graph_obj$edges$to == "standalone.R", ]
  expect_equal(nrow(standalone_edges), 0)
  
  # Producer script with no consumers should have no edges
  producer_edges <- graph_obj$edges[graph_obj$edges$from == "producer.R" | 
                                   graph_obj$edges$to == "producer.R", ]
  expect_equal(nrow(producer_edges), 0)
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
  
  # All nodes should be scripts
  expect_true(all(grepl("\\.R$", topo_order)))
  
  expect_equal(topo_order, c("step1.R", "step2.R", "step3.R"))
})