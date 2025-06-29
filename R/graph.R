#' Create dependency graph from parsed script data
#'
#' Builds a Directed Acyclic Graph (DAG) where all files are nodes.
#' Node types are determined from parse data:
#' - Inputs: files only in parse_data$inputs (external inputs)
#' - Outputs: files in parse_data$outputs (includes intermediates)
#' - Scripts: script file names
#'
#' @param parse_data List from parse() function with 'scripts', 'inputs', 'outputs'
#' @param state_obj Optional. Data frame from read_state() function with 'file'
#'   and 'stale' columns. If provided, will mark nodes as stale/fresh.
#' @return List containing:
#'   \itemize{
#'     \item{nodes: Data frame with 'file', 'type', and 'stale' columns}
#'     \item{edges: Data frame with 'from' and 'to' columns}
#'   }
#' @importFrom stats setNames
graph <- function(parse_data, state_obj = NULL) {
  if (length(parse_data$scripts) == 0) {
    return(list(
      nodes = data.frame(file = character(0), type = character(0),
                        stale = logical(0), stringsAsFactors = FALSE),
      edges = data.frame(from = character(0), to = character(0),
                        stringsAsFactors = FALSE)
    ))
  }

  # Build edges first
  edges <- build_file_edges(parse_data$scripts)

  # Collect all files as nodes and determine types from graph structure
  nodes <- build_file_nodes(parse_data, edges, state_obj)

  # Create graph object
  graph_obj <- list(
    nodes = nodes,
    edges = edges
  )

  # Validate artifact producers (each artifact has exactly one producer)
  validate_artifact_producers(graph_obj, parse_data)


  # Detect cycles
  detect_cycles(graph_obj)

  # Propagate staleness to descendants
  graph_obj <- propagate_staleness(graph_obj)

  return(graph_obj)
}

#' Validate that each artifact has exactly one producer
#'
#' Ensures that every artifact (file referenced by file_in()) has exactly one producer.
#' This means each artifact should have exactly one script that produces it - not zero
#' (orphaned) and not more than one (multiple producers).
#'
#' @param graph_obj Graph object from graph() function
#' @param parse_data Parse result with scripts, inputs, outputs
#' @keywords internal
validate_artifact_producers <- function(graph_obj, parse_data) {
  nodes <- graph_obj$nodes
  edges <- graph_obj$edges

  # Get inputs from parse_data (these need producers)
  inputs <- setdiff(parse_data$inputs, parse_data$outputs)
  # Find input nodes that need producers
  input_nodes <- nodes$file[nodes$type == "artifact" & nodes$file %in% inputs]
  
  # Find all artifact nodes for multiple producer check
  artifact_nodes <- nodes$file[nodes$type == "artifact"]

  # Check for orphaned inputs (zero producers)
  orphaned_inputs <- character(0)
  for (input_file in input_nodes) {
    script_producers <- edges$from[edges$to == input_file &
                                  edges$from %in% nodes$file[nodes$type == "script"]]
    if (length(script_producers) == 0) {
      orphaned_inputs <- c(orphaned_inputs, input_file)
    }
  }

  # Check for multiple producers
  multiple_producer_artifacts <- character(0)
  for (artifact_file in artifact_nodes) {
    script_producers <- edges$from[edges$to == artifact_file &
                                  edges$from %in% nodes$file[nodes$type == "script"]]
    if (length(script_producers) > 1) {
      multiple_producer_artifacts <- c(multiple_producer_artifacts, artifact_file)
    }
  }

  # Report orphaned inputs
  if (length(orphaned_inputs) > 0) {
    cat("\n\033[31m[INVALID]\033[0m Pipeline validation failed\n")
    cat("The following file_in() calls reference files that are not produced",
        "by any file_out() call:\n")
    cat(paste("\033[33m  -", orphaned_inputs, "\033[0m", collapse = "\n"),
        "\n\n")
    cat("Either:\n")
    cat("1. Add a script that produces these files with file_out(), or\n")
    cat("2. Change file_in() to external_in() if these are external files",
        "provided by the user\n")
    stop("Pipeline validation failed: ",
         paste(orphaned_inputs, collapse = ", "), call. = FALSE)
  }

  # Report multiple producers
  if (length(multiple_producer_artifacts) > 0) {
    cat("\n\033[31m[INVALID]\033[0m Pipeline validation failed\n")
    cat("The following artifacts have multiple producers:\n")
    for (artifact in multiple_producer_artifacts) {
      producers <- edges$from[edges$to == artifact &
                             edges$from %in% nodes$file[nodes$type == "script"]]
      cat(sprintf("\033[33m  - %s\033[0m produced by: %s\n", 
                  artifact, paste(producers, collapse = ", ")))
    }
    cat("\nEach artifact should have exactly one producer script.\n")
    stop("Pipeline validation failed: ",
         paste(multiple_producer_artifacts, collapse = ", "), call. = FALSE)
  }

  TRUE
}


#' Build file nodes from graph structure and parse data
#'
#' Creates nodes for all files with types determined from parse data:
#' - Scripts: script file names
#' - Inputs: files only in inputs (external inputs)
#' - Outputs: files in outputs (includes intermediates)
#'
#' @param parse_data Parse result with scripts, inputs, outputs
#' @param edges Data frame with 'from' and 'to' columns
#' @param state_obj Optional state object from read_state()
#' @return Data frame with 'file', 'type', and 'stale' columns
#' @keywords internal
build_file_nodes <- function(parse_data, edges, state_obj = NULL) {
  # Get all unique files mentioned in the graph
  all_files <- unique(c(edges$from, edges$to, names(parse_data$scripts)))

  # Determine file types
  scripts <- names(parse_data$scripts)
  artifacts <- unique(c(parse_data$inputs, parse_data$outputs))
  externals <- parse_data$externals

  # Create types vector
  file_types <- character(length(all_files))
  for (i in seq_along(all_files)) {
    file <- all_files[i]
    if (file %in% scripts) {
      file_types[i] <- "script"
    } else if (file %in% externals) {
      file_types[i] <- "external"
    } else if (file %in% artifacts) {
      file_types[i] <- "artifact"
    } else {
      file_types[i] <- "unknown"
    }
  }

  # Create nodes data frame - all default to stale = TRUE
  nodes <- data.frame(
    file = all_files,
    type = file_types,
    stale = rep(TRUE, length(all_files)),
    stringsAsFactors = FALSE
  )

  # Update staleness based on state_obj
  if (!is.null(state_obj)) {
    for (i in seq_len(nrow(nodes))) {
      file <- nodes$file[i]
      if (file %in% state_obj$file) {
        nodes$stale[i] <- state_obj$stale[state_obj$file == file][1]
      }
    }
  }

  nodes
}


#' Build edges between files for the new graph structure
#'
#' Creates edges directly between files: input -> script -> output
#' This creates a linear chain for each script's file dependencies.
#'
#' @param scripts_data Named list of scripts from parse()$scripts
#' @return Data frame with 'from' and 'to' columns
#' @keywords internal
build_file_edges <- function(scripts_data) {
  edges <- data.frame(from = character(0), to = character(0),
                      stringsAsFactors = FALSE)

  for (script_name in names(scripts_data)) {
    script_data <- scripts_data[[script_name]]

    # Create edges from input files to script
    for (input_file in script_data$inputs) {
      edges <- rbind(edges, data.frame(
        from = input_file,
        to = script_name,
        stringsAsFactors = FALSE
      ))
    }

    # Create edges from external files to script
    for (external_file in script_data$externals) {
      edges <- rbind(edges, data.frame(
        from = external_file,
        to = script_name,
        stringsAsFactors = FALSE
      ))
    }

    # Create edges from script to output files
    for (output_file in script_data$outputs) {
      edges <- rbind(edges, data.frame(
        from = script_name,
        to = output_file,
        stringsAsFactors = FALSE
      ))
    }
  }

  edges
}

#' Detect cycles in the dependency graph using DFS
#'
#' @param graph_obj Graph object from graph() function
#' @keywords internal
detect_cycles <- function(graph_obj) {
  nodes <- graph_obj$nodes$file
  edges <- graph_obj$edges

  # DFS state: 0 = unvisited, 1 = visiting, 2 = visited
  state <- setNames(rep(0, length(nodes)), nodes)

  # Get neighbors from edges
  get_neighbors <- function(node) {
    edges$to[edges$from == node]
  }

  # Recursive DFS function
  dfs <- function(node) {
    if (state[node] == 1) {
      # Back edge found - cycle detected
      stop("Cycle detected in dependency graph involving node: ", node)
    }

    if (state[node] == 2) {
      # Already processed
      return()
    }

    # Mark as visiting
    state[node] <<- 1

    # Visit all neighbors
    for (neighbor in get_neighbors(node)) {
      dfs(neighbor)
    }

    # Mark as visited
    state[node] <<- 2
  }

  # Run DFS from all unvisited nodes
  for (node in nodes) {
    if (state[node] == 0) {
      dfs(node)
    }
  }
}

#' Topological sort of the dependency graph
#'
#' Returns files in topological order using Kahn's algorithm. Files will
#' appear in an order where all dependencies come before the file.
#' Only returns scripts in execution order when filtering by type.
#'
#' @param graph_obj Graph object from graph() function
#' @param scripts_only Logical. If TRUE, returns only script nodes in order
#' @return Character vector of file names in topological order
topological_sort <- function(graph_obj, scripts_only = FALSE) {
  nodes <- graph_obj$nodes$file
  edges <- graph_obj$edges

  if (length(nodes) == 0) {
    return(character(0))
  }

  # Calculate in-degree for each node
  in_degree <- setNames(rep(0, length(nodes)), nodes)
  for (i in seq_len(nrow(edges))) {
    to_node <- edges$to[i]
    in_degree[to_node] <- in_degree[to_node] + 1
  }

  # Get neighbors from edges
  get_neighbors <- function(node) {
    edges$to[edges$from == node]
  }

  # Initialize queue with nodes that have no incoming edges
  queue <- names(in_degree)[in_degree == 0]
  result <- character(0)

  while (length(queue) > 0) {
    # Remove node with no incoming edges
    current <- queue[1]
    queue <- queue[-1]
    result <- c(result, current)

    # Remove edges from current node
    for (neighbor in get_neighbors(current)) {
      in_degree[neighbor] <- in_degree[neighbor] - 1
      if (in_degree[neighbor] == 0) {
        queue <- c(queue, neighbor)
      }
    }
  }

  # If result doesn't contain all nodes, there was a cycle
  if (length(result) != length(nodes)) {
    stop("Cannot perform topological sort: graph contains cycles")
  }

  # Filter to scripts only if requested
  if (scripts_only) {
    script_nodes <- graph_obj$nodes$file[graph_obj$nodes$type == "script"]
    result <- result[result %in% script_nodes]
  }

  result
}

#' Find all descendants of a file in the dependency graph
#'
#' Returns all files that depend on the given file by following
#' the directed edges. Useful for marking files as stale when an upstream
#' dependency changes.
#'
#' @param graph_obj Graph object from graph() function
#' @param node Starting file to find descendants from
#' @param scripts_only Logical. If TRUE, returns only script descendants
#' @return Character vector of all descendant file names
find_descendants <- function(graph_obj, node, scripts_only = FALSE) {
  nodes <- graph_obj$nodes$file
  edges <- graph_obj$edges

  if (!node %in% nodes) {
    stop("Node '", node, "' not found in graph")
  }

  # Get neighbors from edges
  get_neighbors <- function(n) {
    edges$to[edges$from == n]
  }

  visited <- character(0)
  to_visit <- get_neighbors(node)

  while (length(to_visit) > 0) {
    current <- to_visit[1]
    to_visit <- to_visit[-1]

    if (!current %in% visited) {
      visited <- c(visited, current)
      # Add neighbors to visit queue
      to_visit <- c(to_visit, get_neighbors(current))
    }
  }

  # Filter to scripts only if requested
  if (scripts_only) {
    script_nodes <- graph_obj$nodes$file[graph_obj$nodes$type == "script"]
    visited <- visited[visited %in% script_nodes]
  }

  sort(unique(visited))
}

#' Propagate staleness through the dependency graph
#'
#' Implements the logic:
#' - If node is stale AND output: mark parent + descendants as stale
#' - If node is stale otherwise: mark self + descendants as stale
#'
#' @param graph_obj Graph object with nodes and edges data frames
#' @keywords internal
propagate_staleness <- function(graph_obj) {
  nodes <- graph_obj$nodes
  edges <- graph_obj$edges

  # Get neighbors and parents from edges
  get_neighbors <- function(node) {
    edges$to[edges$from == node]
  }

  get_parents <- function(node) {
    edges$from[edges$to == node]
  }

  # DFS to mark descendants as stale
  mark_descendants_stale <- function(node, visited = character(0)) {
    if (node %in% visited) {
      return(visited)
    }

    visited <- c(visited, node)

    # Mark current node as stale
    nodes$stale[nodes$file == node] <<- TRUE

    # Recursively mark all descendants
    for (neighbor in get_neighbors(node)) {
      visited <- mark_descendants_stale(neighbor, visited)
    }

    visited
  }

  # Process each node with new logic
  for (i in seq_len(nrow(nodes))) {
    node_name <- nodes$file[i]
    node_is_stale <- nodes$stale[i]
    node_type <- nodes$type[i]

    if (node_is_stale) {
      if (node_type == "artifact") {
        # If node is stale AND output: mark parent + descendants as stale
        parents <- get_parents(node_name)
        for (parent in parents) {
          mark_descendants_stale(parent)
        }
        mark_descendants_stale(node_name)
      } else {
        # If node is stale otherwise: mark self + descendants as stale
        mark_descendants_stale(node_name)
      }
    }
  }

  # Update the graph object and return it
  graph_obj$nodes <- nodes
  graph_obj
}
