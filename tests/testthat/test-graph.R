test_that("graph() creates correct DAG structure from parse output", {
  # Test data structure with new parse format
  parse_data <- list(
    scripts = list(
      "analysis.R" = list(
        inputs = character(0),
        outputs = c("monthly_sales.csv"),
        externals = c("sales.csv")
      ),
      "report_generation.R" = list(
        inputs = c("monthly_sales.csv"),
        outputs = c("quarterly_report.pdf"),
        externals = c("regions.csv")
      ),
      "data_cleaning.R" = list(
        inputs = character(0),
        outputs = c("cleaned_data.csv", "summary_stats.txt"),
        externals = c("raw_data.txt")
      )
    ),
    inputs = c("monthly_sales.csv"),
    outputs = c("monthly_sales.csv", "quarterly_report.pdf", "cleaned_data.csv", "summary_stats.txt"),
    externals = c("sales.csv", "regions.csv", "raw_data.txt")
  )
  
  graph <- graph(parse_data)
  
  # Should return a list with nodes and edges
  expect_type(graph, "list")
  expect_true("nodes" %in% names(graph))
  expect_true("edges" %in% names(graph))
  
  # Nodes should include all files (scripts, inputs, outputs)
  nodes <- graph$nodes
  expect_s3_class(nodes, "data.frame")
  expect_true("file" %in% names(nodes))
  expect_true("type" %in% names(nodes))
  expect_true("stale" %in% names(nodes))
  
  # Scripts should be present
  expect_true("analysis.R" %in% nodes$file)
  expect_true("report_generation.R" %in% nodes$file)
  expect_true("data_cleaning.R" %in% nodes$file)
  
  # Files should also be present as nodes
  expect_true("sales.csv" %in% nodes$file)
  expect_true("monthly_sales.csv" %in% nodes$file)
  expect_true("regions.csv" %in% nodes$file)
  expect_true("quarterly_report.pdf" %in% nodes$file)
  expect_true("raw_data.txt" %in% nodes$file)
  expect_true("cleaned_data.csv" %in% nodes$file)
  expect_true("summary_stats.txt" %in% nodes$file)
  
  # Check node types
  expect_equal(nodes$type[nodes$file == "analysis.R"], "script")
  expect_equal(nodes$type[nodes$file == "sales.csv"], "external")
  expect_equal(nodes$type[nodes$file == "regions.csv"], "external")
  expect_equal(nodes$type[nodes$file == "raw_data.txt"], "external")
  expect_equal(nodes$type[nodes$file == "monthly_sales.csv"], "output")
  expect_equal(nodes$type[nodes$file == "quarterly_report.pdf"], "output")
  expect_equal(nodes$type[nodes$file == "cleaned_data.csv"], "output")
  expect_equal(nodes$type[nodes$file == "summary_stats.txt"], "output")
  
  # Check edges connect files directly
  edges <- graph$edges
  expect_s3_class(edges, "data.frame")
  expect_true("from" %in% names(edges))
  expect_true("to" %in% names(edges))
  
  # Check specific edges: input -> script -> output
  expect_true(any(edges$from == "sales.csv" & edges$to == "analysis.R"))
  expect_true(any(edges$from == "analysis.R" & edges$to == "monthly_sales.csv"))
  expect_true(any(edges$from == "monthly_sales.csv" & edges$to == "report_generation.R"))
  expect_true(any(edges$from == "regions.csv" & edges$to == "report_generation.R"))
  expect_true(any(edges$from == "report_generation.R" & edges$to == "quarterly_report.pdf"))
})

test_that("graph() detects cyclic dependencies", {
  # Create cyclic dependency: A -> B -> C -> A
  parse_data <- list(
    scripts = list(
      "script_a.R" = list(
        inputs = c("file_c.csv"),
        outputs = c("file_a.csv"),
        externals = character(0)
      ),
      "script_b.R" = list(
        inputs = c("file_a.csv"),
        outputs = c("file_b.csv"),
        externals = character(0)
      ),
      "script_c.R" = list(
        inputs = c("file_b.csv"),
        outputs = c("file_c.csv"),
        externals = character(0)
      )
    ),
    inputs = c("file_c.csv", "file_a.csv", "file_b.csv"),
    outputs = c("file_a.csv", "file_b.csv", "file_c.csv"),
    externals = character(0)
  )
  
  expect_error(graph(parse_data), "Cycle detected")
})

test_that("graph() validates single producer per artifact", {
  # Two scripts producing the same output file
  parse_data <- list(
    scripts = list(
      "script1.R" = list(
        inputs = character(0),
        outputs = c("duplicate_output.csv"),
        externals = c("input.csv")
      ),
      "script2.R" = list(
        inputs = character(0),
        outputs = c("duplicate_output.csv"),
        externals = c("other_input.csv")
      )
    ),
    inputs = character(0),
    outputs = c("duplicate_output.csv"),
    externals = c("input.csv", "other_input.csv")
  )
  
  expect_error(graph(parse_data), "multiple producers")
})

test_that("graph() supports topological sorting", {
  parse_data <- list(
    scripts = list(
      "analysis.R" = list(
        inputs = character(0),
        outputs = c("monthly_sales.csv"),
        externals = c("sales.csv")
      ),
      "report_generation.R" = list(
        inputs = c("monthly_sales.csv"),
        outputs = c("quarterly_report.pdf"),
        externals = c("regions.csv")
      )
    ),
    inputs = c("monthly_sales.csv"),
    outputs = c("monthly_sales.csv", "quarterly_report.pdf"),
    externals = c("sales.csv", "regions.csv")
  )
  
  graph_obj <- graph(parse_data)
  topo_order <- topological_sort(graph_obj, scripts_only = TRUE)
  
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
    scripts = list(
      "analysis.R" = list(
        inputs = character(0),
        outputs = c("monthly_sales.csv"),
        externals = c("sales.csv")
      ),
      "report_generation.R" = list(
        inputs = c("monthly_sales.csv"),
        outputs = c("quarterly_report.pdf"),
        externals = c("regions.csv")
      )
    ),
    inputs = c("monthly_sales.csv"),
    outputs = c("monthly_sales.csv", "quarterly_report.pdf"),
    externals = c("sales.csv", "regions.csv")
  )
  
  graph_obj <- graph(parse_data)
  
  # Find descendants of analysis.R (should include files and scripts)
  descendants <- find_descendants(graph_obj, "analysis.R")
  
  expect_true("monthly_sales.csv" %in% descendants)
  expect_true("report_generation.R" %in% descendants)
  expect_true("quarterly_report.pdf" %in% descendants)
  expect_false("analysis.R" %in% descendants)
  
  # Find descendants of report_generation.R
  descendants2 <- find_descendants(graph_obj, "report_generation.R")
  expect_true("quarterly_report.pdf" %in% descendants2)
})

test_that("graph() handles empty parse data", {
  parse_data <- list(
    scripts = list(),
    inputs = character(0),
    outputs = character(0)
  )
  
  graph_obj <- graph(parse_data)
  
  expect_type(graph_obj, "list")
  expect_equal(nrow(graph_obj$nodes), 0)
  expect_equal(nrow(graph_obj$edges), 0)
})

test_that("graph() handles scripts with no dependencies", {
  parse_data <- list(
    scripts = list(
      "standalone.R" = list(
        inputs = character(0),
        outputs = character(0)
      ),
      "producer.R" = list(
        inputs = character(0),
        outputs = c("data.csv")
      )
    ),
    inputs = character(0),
    outputs = c("data.csv")
  )
  
  graph_obj <- graph(parse_data)
  
  expect_true("standalone.R" %in% graph_obj$nodes$file)
  expect_true("producer.R" %in% graph_obj$nodes$file)
  expect_true("data.csv" %in% graph_obj$nodes$file)  # Files are now nodes
  
  # Check edges - standalone script should have no edges
  standalone_edges <- graph_obj$edges[graph_obj$edges$from == "standalone.R" | 
                                     graph_obj$edges$to == "standalone.R", ]
  expect_equal(nrow(standalone_edges), 0)
  
  # Producer script should have edge to its output
  producer_edges <- graph_obj$edges[graph_obj$edges$from == "producer.R" | 
                                   graph_obj$edges$to == "producer.R", ]
  expect_equal(nrow(producer_edges), 1)  # Should have edge to data.csv
})

test_that("topological_sort() returns scripts in dependency order", {
  parse_data <- list(
    scripts = list(
      "step3.R" = list(
        inputs = c("intermediate2.csv"),
        outputs = c("final.csv"),
        externals = character(0)
      ),
      "step1.R" = list(
        inputs = character(0),
        outputs = c("intermediate1.csv"),
        externals = c("raw.csv")
      ),
      "step2.R" = list(
        inputs = c("intermediate1.csv"),
        outputs = c("intermediate2.csv"),
        externals = character(0)
      )
    ),
    inputs = c("intermediate2.csv", "intermediate1.csv"),
    outputs = c("final.csv", "intermediate1.csv", "intermediate2.csv"),
    externals = c("raw.csv")
  )
  
  graph_obj <- graph(parse_data)
  topo_order <- topological_sort(graph_obj, scripts_only = TRUE)
  
  # All nodes should be scripts
  expect_true(all(grepl("\\.R$", topo_order)))
  
  expect_equal(topo_order, c("step1.R", "step2.R", "step3.R"))
})

test_that("graph() with state_obj marks nodes as stale correctly", {
  parse_data <- list(
    scripts = list(
      "script1.R" = list(inputs = character(0), outputs = c("intermediate.csv"), externals = c("input.csv")),
      "script2.R" = list(inputs = c("intermediate.csv"), outputs = c("output.csv"), externals = character(0)),
      "script3.R" = list(inputs = character(0), outputs = c("final.csv"), externals = c("other.csv"))
    ),
    inputs = c("intermediate.csv"),
    outputs = c("intermediate.csv", "output.csv", "final.csv"),
    externals = c("input.csv", "other.csv")
  )
  
  # Create state object with mixed fresh/stale files (new data frame format)
  state_obj <- data.frame(
    file = c("script1.R", "input.csv", "intermediate.csv", "script2.R", 
             "output.csv", "script3.R", "other.csv", "final.csv"),
    stale = c(FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE),
    stringsAsFactors = FALSE
  )
  
  graph_obj <- graph(parse_data, state_obj)
  
  # Check that nodes data frame has stale information
  expect_true("nodes" %in% names(graph_obj))
  expect_s3_class(graph_obj$nodes, "data.frame")
  expect_true("stale" %in% names(graph_obj$nodes))
  
  # script1.R should be stale because its input (input.csv) is stale
  script1_stale <- graph_obj$nodes$stale[graph_obj$nodes$file == "script1.R"]
  expect_true(script1_stale)
  
  # script2.R should be stale because script1.R (which produces its input) is stale
  script2_stale <- graph_obj$nodes$stale[graph_obj$nodes$file == "script2.R"]
  expect_true(script2_stale)
  
  # script3.R should be fresh because its dependencies are fresh
  script3_stale <- graph_obj$nodes$stale[graph_obj$nodes$file == "script3.R"]
  expect_false(script3_stale)
})

test_that("graph() without state_obj works as before", {
  parse_data <- list(
    scripts = list(
      "script1.R" = list(inputs = character(0), outputs = c("output.csv"), externals = c("input.csv"))
    ),
    inputs = character(0),
    outputs = c("output.csv"),
    externals = c("input.csv")
  )
  
  # Should work without state_obj parameter - all nodes should be stale
  graph_obj <- graph(parse_data)
  
  expect_true("nodes" %in% names(graph_obj))
  expect_true("edges" %in% names(graph_obj))
  expect_s3_class(graph_obj$nodes, "data.frame")
  expect_true("stale" %in% names(graph_obj$nodes))
  # Without state_obj, all nodes should be marked as stale
  expect_true(all(graph_obj$nodes$stale))
})

test_that("graph() marks all nodes as fresh when no stale files", {
  parse_data <- list(
    scripts = list(
      "script1.R" = list(inputs = character(0), outputs = c("output.csv"), externals = c("input.csv")),
      "script2.R" = list(inputs = c("output.csv"), outputs = c("final.csv"), externals = character(0))
    ),
    inputs = c("output.csv"),
    outputs = c("output.csv", "final.csv"),
    externals = c("input.csv")
  )
  
  # State object with no stale files (new data frame format)
  state_obj <- data.frame(
    file = c("script1.R", "script2.R", "input.csv", "output.csv", "final.csv"),
    stale = c(FALSE, FALSE, FALSE, FALSE, FALSE),
    stringsAsFactors = FALSE
  )
  
  graph_obj <- graph(parse_data, state_obj)
  
  # All scripts should be fresh when no stale files
  expect_true(all(!graph_obj$nodes$stale))
})

test_that("graph() marks nodes as stale when files not in state", {
  parse_data <- list(
    scripts = list(
      "script1.R" = list(inputs = character(0), outputs = c("output.csv"), externals = c("input.csv")),
      "script2.R" = list(inputs = c("output.csv"), outputs = c("final.csv"), externals = character(0))
    ),
    inputs = c("output.csv"),
    outputs = c("output.csv", "final.csv"),
    externals = c("input.csv")
  )
  
  # State object with some files marked as stale (new data frame format)
  state_obj <- data.frame(
    file = c("script1.R", "script2.R", "input.csv", "output.csv", "final.csv"),
    stale = c(FALSE, TRUE, TRUE, TRUE, TRUE),
    stringsAsFactors = FALSE
  )
  
  graph_obj <- graph(parse_data, state_obj)
  
  # script1.R should be stale due to input.csv being stale, script2.R should be stale
  script1_stale <- graph_obj$nodes$stale[graph_obj$nodes$file == "script1.R"]
  script2_stale <- graph_obj$nodes$stale[graph_obj$nodes$file == "script2.R"]
  expect_true(script1_stale)
  expect_true(script2_stale)
})

test_that("graph() propagates staleness correctly via DFS", {
  # Linear pipeline: script1 -> script2 -> script3
  parse_data <- list(
    scripts = list(
      "script1.R" = list(inputs = character(0), outputs = c("clean.csv"), externals = c("raw.csv")),
      "script2.R" = list(inputs = c("clean.csv"), outputs = c("processed.csv"), externals = character(0)),
      "script3.R" = list(inputs = c("processed.csv"), outputs = c("final.csv"), externals = character(0))
    ),
    inputs = c("clean.csv", "processed.csv"),
    outputs = c("clean.csv", "processed.csv", "final.csv"),
    externals = c("raw.csv")
  )
  
  # State where only script1.R is stale (new data frame format)
  state_obj <- data.frame(
    file = c("script1.R", "script2.R", "script3.R", "raw.csv", "clean.csv", "processed.csv", "final.csv"),
    stale = c(TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE),
    stringsAsFactors = FALSE
  )
  
  graph_obj <- graph(parse_data, state_obj)
  
  # All scripts should be stale due to propagation
  script1_stale <- graph_obj$nodes$stale[graph_obj$nodes$file == "script1.R"]
  script2_stale <- graph_obj$nodes$stale[graph_obj$nodes$file == "script2.R"]
  script3_stale <- graph_obj$nodes$stale[graph_obj$nodes$file == "script3.R"]
  expect_true(script1_stale)
  expect_true(script2_stale)
  expect_true(script3_stale)
})

test_that("graph() handles disconnected components correctly", {
  # Two independent pipelines
  parse_data <- list(
    scripts = list(
      "pipeline1_step1.R" = list(inputs = character(0), outputs = c("result1.csv"), externals = c("data1.csv")),
      "pipeline1_step2.R" = list(inputs = c("result1.csv"), outputs = c("final1.csv"), externals = character(0)),
      "pipeline2_step1.R" = list(inputs = character(0), outputs = c("final2.csv"), externals = c("data2.csv"))
    ),
    inputs = c("result1.csv"),
    outputs = c("result1.csv", "final1.csv", "final2.csv"),
    externals = c("data1.csv", "data2.csv")
  )
  
  # Only pipeline1 has stale data (new data frame format)
  state_obj <- data.frame(
    file = c("pipeline1_step1.R", "pipeline1_step2.R", "pipeline2_step1.R", 
             "data1.csv", "result1.csv", "final1.csv", "data2.csv", "final2.csv"),
    stale = c(FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE),
    stringsAsFactors = FALSE
  )
  
  graph_obj <- graph(parse_data, state_obj)
  
  # Only pipeline1 scripts should be stale
  pipeline1_step1_stale <- graph_obj$nodes$stale[graph_obj$nodes$file == "pipeline1_step1.R"]
  pipeline1_step2_stale <- graph_obj$nodes$stale[graph_obj$nodes$file == "pipeline1_step2.R"]
  pipeline2_step1_stale <- graph_obj$nodes$stale[graph_obj$nodes$file == "pipeline2_step1.R"]
  expect_true(pipeline1_step1_stale)
  expect_true(pipeline1_step2_stale)
  expect_false(pipeline2_step1_stale)
})