#' Create dependency graph from parsed script data
#'
#' Builds a Directed Acyclic Graph (DAG) representing the dependencies between
#' scripts and data files. The graph is represented using an edges data frame.
#' Optionally accepts a cache object to mark stale nodes.
#'
#' @param parse_data Named list from parse() function, where each element
#'   represents a script with 'inputs' and 'outputs' character vectors.
#' @param cache_obj Optional state object from read_state() function to determine
#'   which nodes are stale.
#' @return List containing:
#'   \itemize{
#'     \item{nodes: Character vector of all nodes (scripts and artifacts)}
#'     \item{edges: Data frame with 'from' and 'to' columns representing edges}
#'     \item{stale_nodes: Character vector of nodes marked as stale (if cache_obj provided)}
#'   }
#' @importFrom stats setNames
#' @export
#' @examples
#' \dontrun{
#' # Parse scripts and create dependency graph
#' parsed <- parse()
#' graph_obj <- graph(parsed)
#' 
#' # Create graph with state information
#' state_obj <- read_state()
#' graph_obj <- graph(parsed, state_obj)
#' }
graph <- function(parse_data, cache_obj = NULL) {
  if (length(parse_data) == 0) {
    result <- list(
      nodes = character(0),
      edges = data.frame(from = character(0), to = character(0), stringsAsFactors = FALSE)
    )
    if (!is.null(cache_obj)) {
      result$stale_nodes <- character(0)
    }
    return(result)
  }
  
  # Validate single producer per artifact
  validate_single_producer(parse_data)
  
  # Collect all nodes (scripts and artifacts)
  nodes <- collect_all_nodes(parse_data)
  
  # Build edges
  edges <- build_edges(parse_data)
  
  # Create graph object
  graph_obj <- list(
    nodes = nodes,
    edges = edges
  )
  
  # Detect cycles
  detect_cycles(graph_obj)
  
  # Add stale node information if cache is provided
  if (!is.null(cache_obj)) {
    graph_obj$stale_nodes <- determine_stale_nodes(graph_obj, cache_obj, parse_data)
  }
  
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

#' Collect all unique nodes from parse data
#'
#' @param parse_data Named list from parse() function
#' @return Character vector of all unique nodes
#' @keywords internal
collect_all_nodes <- function(parse_data) {
  nodes <- character(0)
  
  # Add all scripts
  nodes <- c(nodes, names(parse_data))
  
  # Add all input and output artifacts
  for (script_data in parse_data) {
    nodes <- c(nodes, script_data$inputs, script_data$outputs)
  }
  
  # Return unique nodes
  unique(nodes)
}

#' Build edges from parse data
#'
#' @param parse_data Named list from parse() function
#' @return Data frame with 'from' and 'to' columns representing edges
#' @keywords internal
build_edges <- function(parse_data) {
  edges <- data.frame(from = character(0), to = character(0), stringsAsFactors = FALSE)
  
  # Build edges: artifact -> script (inputs) and script -> artifact (outputs)
  for (script_name in names(parse_data)) {
    script_data <- parse_data[[script_name]]
    
    # Edges from input artifacts to script
    for (input in script_data$inputs) {
      edges <- rbind(edges, data.frame(from = input, to = script_name, stringsAsFactors = FALSE))
    }
    
    # Edges from script to output artifacts
    for (output in script_data$outputs) {
      edges <- rbind(edges, data.frame(from = script_name, to = output, stringsAsFactors = FALSE))
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
#' Returns nodes in topological order using Kahn's algorithm. Scripts will
#' appear in an order where all dependencies come before the script.
#'
#' @param graph_obj Graph object from graph() function
#' @return Character vector of nodes in topological order
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

#' Find all descendants of a node in the dependency graph
#'
#' Returns all nodes that are reachable from the given node by following
#' the directed edges. Useful for marking nodes as stale when an upstream
#' dependency changes.
#'
#' @param graph_obj Graph object from graph() function
#' @param node Starting node to find descendants from
#' @return Character vector of all descendant nodes
#' @export
#' @examples
#' \dontrun{
#' parsed <- parse()
#' graph_obj <- graph(parsed)
#' stale_nodes <- find_descendants(graph_obj, "input_data.csv")
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

#' Determine which nodes are stale based on cache information
#'
#' Implements the stale marking logic:
#' - If a script is stale, mark it and all descendants as stale
#' - If an artifact is stale (manually modified), mark its parent script and all descendants as stale
#'
#' @param graph_obj Graph object with nodes and edges
#' @param cache_obj State object from read_state() function
#' @param parse_data Parsed script data to identify script-artifact relationships
#' @return Character vector of stale node names
#' @keywords internal
determine_stale_nodes <- function(graph_obj, cache_obj, parse_data) {
  stale_nodes <- character(0)
  
  # Get all nodes that are directly marked as stale in cache
  directly_stale <- names(cache_obj)[sapply(cache_obj, function(x) x$status == "stale")]
  
  # Also check for missing output files that should exist but aren't in cache
  all_outputs <- character(0)
  for (script_data in parse_data) {
    all_outputs <- c(all_outputs, script_data$outputs)
  }
  all_outputs <- unique(all_outputs)
  
  # Missing output files are implicitly stale
  missing_outputs <- all_outputs[!file.exists(all_outputs)]
  missing_stale <- missing_outputs[!missing_outputs %in% names(cache_obj)]
  
  # Combine directly stale and missing files
  all_stale <- unique(c(directly_stale, missing_stale))
  
  for (stale_node in all_stale) {
    if (stale_node %in% graph_obj$nodes) {
      # Check if this is a script or artifact
      if (stale_node %in% names(parse_data)) {
        # It's a script - mark it and all descendants as stale
        stale_nodes <- c(stale_nodes, stale_node)
        descendants <- find_descendants(graph_obj, stale_node)
        stale_nodes <- c(stale_nodes, descendants)
      } else {
        # It's an artifact - find its parent script and mark parent + descendants as stale
        parent_script <- find_parent_script(stale_node, parse_data)
        
        # Mark the artifact itself as stale
        stale_nodes <- c(stale_nodes, stale_node)
        
        # Mark parent script (if exists) and all descendants as stale
        if (!is.null(parent_script) && parent_script %in% graph_obj$nodes) {
          stale_nodes <- c(stale_nodes, parent_script)
          parent_descendants <- find_descendants(graph_obj, parent_script)
          stale_nodes <- c(stale_nodes, parent_descendants)
        }
        
        # Also mark direct descendants of the artifact as stale
        artifact_descendants <- find_descendants(graph_obj, stale_node)
        stale_nodes <- c(stale_nodes, artifact_descendants)
      }
    }
  }
  
  unique(stale_nodes)
}

#' Find the parent script that produces a given artifact
#'
#' @param artifact_name Name of the artifact file
#' @param parse_data Parsed script data
#' @return Script name that produces the artifact, or NULL if not found
#' @keywords internal
find_parent_script <- function(artifact_name, parse_data) {
  for (script_name in names(parse_data)) {
    if (artifact_name %in% parse_data[[script_name]]$outputs) {
      return(script_name)
    }
  }
  NULL
}