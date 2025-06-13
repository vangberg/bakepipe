#' Create dependency graph from parsed script data
#'
#' Builds a Directed Acyclic Graph (DAG) where scripts are nodes and files are edges.
#' Each edge represents a file dependency between two scripts.
#'
#' @param parse_data Named list from parse() function, where each element
#'   represents a script with 'inputs' and 'outputs' character vectors.
#' @return List containing:
#'   \itemize{
#'     \item{nodes: Character vector of script names}
#'     \item{edges: Data frame with 'from', 'to', and 'file' columns}
#'   }
#' @importFrom stats setNames
#' @export
#' @examples
#' \dontrun{
#' # Parse scripts and create dependency graph
#' parsed <- parse()
#' graph_obj <- graph(parsed)
#' }
graph <- function(parse_data) {
  if (length(parse_data) == 0) {
    return(list(
      nodes = character(0),
      edges = data.frame(from = character(0), to = character(0), file = character(0), stringsAsFactors = FALSE)
    ))
  }
  
  # Validate single producer per artifact
  validate_single_producer(parse_data)
  
  # Collect script nodes
  nodes <- names(parse_data)
  
  # Build edges between scripts through files
  edges <- build_script_edges(parse_data)
  
  # Create graph object
  graph_obj <- list(
    nodes = nodes,
    edges = edges
  )
  
  # Detect cycles
  detect_cycles(graph_obj)
  
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

#' Build edges between scripts through file dependencies
#'
#' Creates edges where scripts are connected if one produces a file that
#' another consumes.
#'
#' @param parse_data Named list from parse() function
#' @return Data frame with 'from', 'to', and 'file' columns
#' @keywords internal
build_script_edges <- function(parse_data) {
  edges <- data.frame(from = character(0), to = character(0),
                      file = character(0), stringsAsFactors = FALSE)

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
        edges <- rbind(edges, data.frame(
          from = producer_script,
          to = script_name,
          file = input_file,
          stringsAsFactors = FALSE
        ))
      }
    }
  }

  edges
}


#' Detect cycles in the dependency graph using DFS
#'
#' @param graph_obj Graph object from graph() function
#' @keywords internal
detect_cycles <- function(graph_obj) {
  nodes <- graph_obj$nodes
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
  nodes <- graph_obj$nodes
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
  nodes <- graph_obj$nodes
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