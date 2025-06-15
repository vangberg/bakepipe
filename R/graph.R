#' Create dependency graph from parsed script data
#'
#' Builds a Directed Acyclic Graph (DAG) where scripts are nodes and files are edges.
#' Each edge represents a file dependency between two scripts. Optionally accepts
#' a state object to mark nodes as stale or fresh based on file changes.
#'
#' @param parse_data Named list from parse() function, where each element
#'   represents a script with 'inputs' and 'outputs' character vectors.
#' @param state_obj Optional. Data frame from read_state() function with 'file'
#'   and 'stale' columns. If provided, will mark nodes as stale/fresh.
#' @return List containing:
#'   \itemize{
#'     \item{nodes: Data frame with 'file' and 'stale' columns}
#'     \item{edges: Data frame with 'from', 'to', 'file', and 'stale' columns}
#'   }
#' @importFrom stats setNames
#' @export
#' @examples
#' \dontrun{
#' # Parse scripts and create dependency graph
#' parsed <- parse()
#' graph_obj <- graph(parsed)
#' 
#' # With state information
#' state_obj <- read_state(".bakepipe.state")
#' graph_obj <- graph(parsed, state_obj)
#' }
graph <- function(parse_data, state_obj = NULL) {
  if (length(parse_data) == 0) {
    return(list(
      nodes = data.frame(file = character(0), stale = logical(0), stringsAsFactors = FALSE),
      edges = data.frame(from = character(0), to = character(0), 
                        file = character(0), stale = logical(0), stringsAsFactors = FALSE)
    ))
  }
  
  # Validate single producer per artifact
  validate_single_producer(parse_data)
  
  # Collect script nodes and mark staleness based on dependencies
  script_names <- names(parse_data)
  nodes <- data.frame(
    file = script_names,
    stale = determine_node_staleness(script_names, parse_data, state_obj),
    stringsAsFactors = FALSE
  )
  
  # Build edges between scripts through files
  edges <- build_script_edges(parse_data, state_obj)
  
  # Create graph object
  graph_obj <- list(
    nodes = nodes,
    edges = edges
  )
  
  # Detect cycles (using node names)
  detect_cycles_with_df(graph_obj)
  
  # Propagate staleness to descendants
  graph_obj <- propagate_staleness(graph_obj)
  
  return(graph_obj)
}

#' Validate that each artifact has at most one producer
#'
#' @param parse_data Named list from parse() function
#' @keywords internal
validate_single_producer <- function(parse_data) {
  artifact_producers <- list()
  
  for (script_name in names(parse_data)) {
    script_data <- parse_data[[script_name]]
    
    for (output in script_data$outputs) {
      if (output %in% names(artifact_producers)) {
        stop("Artifact '", output, "' has multiple producers: '", 
             artifact_producers[[output]], "' and '", script_name, "'")
      }
      artifact_producers[[output]] <- script_name
    }
  }
}

#' Determine staleness for files
#'
#' @param files Character vector of file names
#' @param state_obj Optional state object from read_state()
#' @return Logical vector indicating staleness
#' @keywords internal
determine_staleness <- function(files, state_obj = NULL) {
  if (is.null(state_obj)) {
    return(rep(TRUE, length(files)))
  }
  
  # For each file, check if it's in state_obj and mark accordingly
  stale <- logical(length(files))
  for (i in seq_along(files)) {
    file <- files[i]
    if (file %in% state_obj$file) {
      # Use the stale status from state_obj
      stale[i] <- state_obj$stale[state_obj$file == file][1]
    } else {
      # File not in state_obj, mark as stale
      stale[i] <- TRUE
    }
  }
  
  stale
}

#' Determine staleness for script nodes based on their dependencies
#'
#' @param script_names Character vector of script names
#' @param parse_data Named list from parse() function
#' @param state_obj Optional state object from read_state()
#' @return Logical vector indicating staleness for each script
#' @keywords internal
determine_node_staleness <- function(script_names, parse_data,
                                     state_obj = NULL) {
  if (is.null(state_obj)) {
    return(rep(TRUE, length(script_names)))
  }

  stale <- logical(length(script_names))

  for (i in seq_along(script_names)) {
    script_name <- script_names[i]
    script_data <- parse_data[[script_name]]
    script_is_stale <- FALSE

    # Check if script itself is stale
    if (script_name %in% state_obj$file) {
      script_is_stale <- state_obj$stale[state_obj$file == script_name][1]
    } else {
      script_is_stale <- TRUE  # Not in state, mark as stale
    }

    # Check if any input files are stale
    if (!script_is_stale) {
      for (input_file in script_data$inputs) {
        if (input_file %in% state_obj$file) {
          if (state_obj$stale[state_obj$file == input_file][1]) {
            script_is_stale <- TRUE
            break
          }
        } else {
          script_is_stale <- TRUE  # Input not in state, mark as stale
          break
        }
      }
    }

    # Check if any output files are stale (manually modified)
    if (!script_is_stale) {
      for (output_file in script_data$outputs) {
        if (output_file %in% state_obj$file) {
          if (state_obj$stale[state_obj$file == output_file][1]) {
            script_is_stale <- TRUE
            break
          }
        } else {
          script_is_stale <- TRUE  # Output not in state, mark as stale
          break
        }
      }
    }

    stale[i] <- script_is_stale
  }

  stale
}

#' Build edges between scripts through file dependencies
#'
#' Creates edges where scripts are connected if one produces a file that
#' another consumes. Includes staleness information for each edge.
#'
#' @param parse_data Named list from parse() function
#' @param state_obj Optional state object from read_state()
#' @return Data frame with 'from', 'to', 'file', and 'stale' columns
#' @keywords internal
build_script_edges <- function(parse_data, state_obj = NULL) {
  edges <- data.frame(from = character(0), to = character(0),
                      file = character(0), stale = logical(0),
                      stringsAsFactors = FALSE)

  # Create a mapping of files to their producers
  file_producers <- list()
  for (script_name in names(parse_data)) {
    for (output in parse_data[[script_name]]$outputs) {
      file_producers[[output]] <- script_name
    }
  }

  # For each script, find dependencies through input files
  for (script_name in names(parse_data)) {
    script_data <- parse_data[[script_name]]

    for (input_file in script_data$inputs) {
      # If this input file is produced by another script, create an edge
      if (input_file %in% names(file_producers)) {
        producer_script <- file_producers[[input_file]]
        file_stale <- determine_staleness(input_file, state_obj)[1]
        edges <- rbind(edges, data.frame(
          from = producer_script,
          to = script_name,
          file = input_file,
          stale = file_stale,
          stringsAsFactors = FALSE
        ))
      }
    }
  }

  edges
}


#' Detect cycles in the dependency graph using DFS (with data frame nodes)
#'
#' @param graph_obj Graph object from graph() function
#' @keywords internal
detect_cycles_with_df <- function(graph_obj) {
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
#' Returns scripts in topological order using Kahn's algorithm. Scripts will
#' appear in an order where all dependencies come before the script.
#'
#' @param graph_obj Graph object from graph() function
#' @return Character vector of script names in topological order
#' @export
#' @examples
#' \dontrun{
#' parsed <- parse()
#' graph_obj <- graph(parsed)
#' execution_order <- topological_sort(graph_obj)
#' }
topological_sort <- function(graph_obj) {
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

  result
}

#' Find all descendants of a script in the dependency graph
#'
#' Returns all scripts that depend on the given script by following
#' the directed edges. Useful for marking scripts as stale when an upstream
#' dependency changes.
#'
#' @param graph_obj Graph object from graph() function
#' @param node Starting script to find descendants from
#' @return Character vector of all descendant script names
#' @export
#' @examples
#' \dontrun{
#' parsed <- parse()
#' graph_obj <- graph(parsed)
#' stale_scripts <- find_descendants(graph_obj, "data_cleaning.R")
#' }
find_descendants <- function(graph_obj, node) {
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

  sort(unique(visited))
}

#' Propagate staleness to descendants using DFS traversal
#'
#' If a node itself OR any edges from or to the node is stale,
#' mark all descendants as stale using DFS traversal.
#'
#' @param graph_obj Graph object with nodes and edges data frames
#' @keywords internal
propagate_staleness <- function(graph_obj) {
  nodes <- graph_obj$nodes
  edges <- graph_obj$edges

  # Get neighbors from edges
  get_neighbors <- function(node) {
    edges$to[edges$from == node]
  }

  # Check if a node has any stale edges (from or to)
  has_stale_edges <- function(node) {
    # Check edges from this node
    from_edges_stale <- any(edges$stale[edges$from == node])
    # Check edges to this node
    to_edges_stale <- any(edges$stale[edges$to == node])

    from_edges_stale || to_edges_stale
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

  # Process each node
  for (i in seq_len(nrow(nodes))) {
    node_name <- nodes$file[i]
    node_is_stale <- nodes$stale[i]

    # If node itself is stale OR has stale edges, mark descendants as stale
    if (node_is_stale || has_stale_edges(node_name)) {
      mark_descendants_stale(node_name)
    }
  }

  # Update the graph object and return it
  graph_obj$nodes <- nodes
  graph_obj
}
