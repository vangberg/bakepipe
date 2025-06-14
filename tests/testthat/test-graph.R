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

test_that("graph() with state_obj marks nodes as stale correctly", {
  parse_data <- list(
    "script1.R" = list(inputs = c("input.csv"), outputs = c("intermediate.csv")),
    "script2.R" = list(inputs = c("intermediate.csv"), outputs = c("output.csv")),
    "script3.R" = list(inputs = c("other.csv"), outputs = c("final.csv"))
  )
  
  # Create state object with mixed fresh/stale files
  state_obj <- list(
    "script1.R" = list(checksum = "a1", last_modified = "2023-01-01", status = "fresh", current_checksum = "a1"),
    "input.csv" = list(checksum = "b1", last_modified = "2023-01-01", status = "stale", current_checksum = "b2"),
    "intermediate.csv" = list(checksum = "c1", last_modified = "2023-01-01", status = "fresh", current_checksum = "c1"),
    "script2.R" = list(checksum = "d1", last_modified = "2023-01-01", status = "fresh", current_checksum = "d1"),
    "output.csv" = list(checksum = "e1", last_modified = "2023-01-01", status = "fresh", current_checksum = "e1"),
    "script3.R" = list(checksum = "f1", last_modified = "2023-01-01", status = "fresh", current_checksum = "f1"),
    "other.csv" = list(checksum = "g1", last_modified = "2023-01-01", status = "fresh", current_checksum = "g1"),
    "final.csv" = list(checksum = "h1", last_modified = "2023-01-01", status = "fresh", current_checksum = "h1")
  )
  
  graph_obj <- graph(parse_data, state_obj)
  
  expect_true("stale_nodes" %in% names(graph_obj))
  
  # script1.R should be stale because its input (input.csv) is stale
  expect_true("script1.R" %in% graph_obj$stale_nodes)
  
  # script2.R should be stale because script1.R (which produces its input) is stale
  expect_true("script2.R" %in% graph_obj$stale_nodes)
  
  # script3.R should be fresh because its dependencies are fresh
  expect_false("script3.R" %in% graph_obj$stale_nodes)
})

test_that("graph() without state_obj works as before", {
  parse_data <- list(
    "script1.R" = list(inputs = c("input.csv"), outputs = c("output.csv"))
  )
  
  # Should work without state_obj parameter
  graph_obj <- graph(parse_data)
  
  expect_true("nodes" %in% names(graph_obj))
  expect_true("edges" %in% names(graph_obj))
  expect_false("stale_nodes" %in% names(graph_obj))
})

test_that("graph() marks all nodes as fresh when no stale files", {
  parse_data <- list(
    "script1.R" = list(inputs = c("input.csv"), outputs = c("output.csv")),
    "script2.R" = list(inputs = c("output.csv"), outputs = c("final.csv"))
  )
  
  # State object with no stale files
  state_obj <- list(
    "script1.R" = list(checksum = "a1", last_modified = "2023-01-01", status = "fresh", current_checksum = "a1"),
    "script2.R" = list(checksum = "b1", last_modified = "2023-01-01", status = "fresh", current_checksum = "b1"),
    "input.csv" = list(checksum = "c1", last_modified = "2023-01-01", status = "fresh", current_checksum = "c1"),
    "output.csv" = list(checksum = "d1", last_modified = "2023-01-01", status = "fresh", current_checksum = "d1"),
    "final.csv" = list(checksum = "e1", last_modified = "2023-01-01", status = "fresh", current_checksum = "e1")
  )
  
  graph_obj <- graph(parse_data, state_obj)
  
  # All scripts should be fresh when no stale files
  expect_equal(length(graph_obj$stale_nodes), 0)
})

test_that("graph() marks nodes as stale when files not in state", {
  parse_data <- list(
    "script1.R" = list(inputs = c("input.csv"), outputs = c("output.csv")),
    "script2.R" = list(inputs = c("output.csv"), outputs = c("final.csv"))
  )
  
  # State object missing some files (they should be considered stale)
  state_obj <- list(
    "script1.R" = list(checksum = "a1", last_modified = "2023-01-01", status = "fresh", current_checksum = "a1"),
    "script2.R" = list(checksum = "missing", last_modified = "2023-01-01", status = "stale", current_checksum = NA_character_),
    "input.csv" = list(checksum = "missing", last_modified = "2023-01-01", status = "stale", current_checksum = NA_character_),
    "output.csv" = list(checksum = "missing", last_modified = "2023-01-01", status = "stale", current_checksum = NA_character_),
    "final.csv" = list(checksum = "missing", last_modified = "2023-01-01", status = "stale", current_checksum = NA_character_)
  )
  
  graph_obj <- graph(parse_data, state_obj)
  
  # script2.R should be stale (not in state), script1.R should also be stale due to input.csv being stale
  expect_true("script1.R" %in% graph_obj$stale_nodes)
  expect_true("script2.R" %in% graph_obj$stale_nodes)
})

test_that("graph() propagates staleness correctly via DFS", {
  # Linear pipeline: script1 -> script2 -> script3
  parse_data <- list(
    "script1.R" = list(inputs = c("raw.csv"), outputs = c("clean.csv")),
    "script2.R" = list(inputs = c("clean.csv"), outputs = c("processed.csv")),
    "script3.R" = list(inputs = c("processed.csv"), outputs = c("final.csv"))
  )
  
  # State where only script1.R is stale
  state_obj <- list(
    "script1.R" = list(checksum = "a1", last_modified = "2023-01-01", status = "stale", current_checksum = "a2"),
    "script2.R" = list(checksum = "b1", last_modified = "2023-01-01", status = "fresh", current_checksum = "b1"),
    "script3.R" = list(checksum = "c1", last_modified = "2023-01-01", status = "fresh", current_checksum = "c1"),
    "raw.csv" = list(checksum = "d1", last_modified = "2023-01-01", status = "fresh", current_checksum = "d1"),
    "clean.csv" = list(checksum = "e1", last_modified = "2023-01-01", status = "fresh", current_checksum = "e1"),
    "processed.csv" = list(checksum = "f1", last_modified = "2023-01-01", status = "fresh", current_checksum = "f1"),
    "final.csv" = list(checksum = "g1", last_modified = "2023-01-01", status = "fresh", current_checksum = "g1")
  )
  
  graph_obj <- graph(parse_data, state_obj)
  
  # All scripts should be stale due to propagation
  expect_true("script1.R" %in% graph_obj$stale_nodes)
  expect_true("script2.R" %in% graph_obj$stale_nodes)
  expect_true("script3.R" %in% graph_obj$stale_nodes)
})

test_that("graph() handles disconnected components correctly", {
  # Two independent pipelines
  parse_data <- list(
    "pipeline1_step1.R" = list(inputs = c("data1.csv"), outputs = c("result1.csv")),
    "pipeline1_step2.R" = list(inputs = c("result1.csv"), outputs = c("final1.csv")),
    "pipeline2_step1.R" = list(inputs = c("data2.csv"), outputs = c("final2.csv"))
  )
  
  # Only pipeline1 has stale data
  state_obj <- list(
    "pipeline1_step1.R" = list(checksum = "a1", last_modified = "2023-01-01", status = "fresh", current_checksum = "a1"),
    "pipeline1_step2.R" = list(checksum = "b1", last_modified = "2023-01-01", status = "fresh", current_checksum = "b1"),
    "pipeline2_step1.R" = list(checksum = "c1", last_modified = "2023-01-01", status = "fresh", current_checksum = "c1"),
    "data1.csv" = list(checksum = "d1", last_modified = "2023-01-01", status = "stale", current_checksum = "d2"),
    "result1.csv" = list(checksum = "e1", last_modified = "2023-01-01", status = "fresh", current_checksum = "e1"),
    "final1.csv" = list(checksum = "f1", last_modified = "2023-01-01", status = "fresh", current_checksum = "f1"),
    "data2.csv" = list(checksum = "g1", last_modified = "2023-01-01", status = "fresh", current_checksum = "g1"),
    "final2.csv" = list(checksum = "h1", last_modified = "2023-01-01", status = "fresh", current_checksum = "h1")
  )
  
  graph_obj <- graph(parse_data, state_obj)
  
  # Only pipeline1 scripts should be stale
  expect_true("pipeline1_step1.R" %in% graph_obj$stale_nodes)
  expect_true("pipeline1_step2.R" %in% graph_obj$stale_nodes)
  expect_false("pipeline2_step1.R" %in% graph_obj$stale_nodes)
})