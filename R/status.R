#' Show pipeline status
#'
#' Display the current state of all scripts in the pipeline (fresh/stale)
#'
#' @return NULL (invisibly). This function is called for its side effect of
#'   displaying pipeline status information to the console.
#' @examples
#' \dontrun{
#' # Display current pipeline status
#' bakepipe::status()
#' 
#' # This will show which scripts are fresh (up-to-date) 
#' # and which are stale (need to be re-run)
#' }
#' @export
status <- function() {
  # Parse the pipeline to get script dependencies
  pipeline_data <- parse()

  # Handle empty pipeline
  if (length(pipeline_data$scripts) == 0) {
    cat("\n[STATUS] \033[1;36mBakepipe Status\033[0m\n")
    cat("\033[33m   No scripts found in pipeline\033[0m\n\n")
    return(invisible(NULL))
  }

  # Display header
  cat("\n[STATUS] \033[1;36mBakepipe Status\033[0m\n")

  # Display Scripts table with state information
  display_scripts_table(pipeline_data)

  invisible(NULL)
}

#' Display the scripts table
#' @param pipeline_data Parsed pipeline data
display_scripts_table <- function(pipeline_data) {
  # Read state information
  state_obj <- read_state(file.path(root(), ".bakepipe.state"))

  # Create graph with state information
  graph_obj <- graph(pipeline_data, state_obj, validate_externals = FALSE)
  topo_order <- topological_sort(graph_obj, scripts_only = TRUE)

  # Scripts are already in the correct order
  scripts <- topo_order

  # Determine state for each script
  state_list <- lapply(scripts, function(script) {
    script_stale <- graph_obj$nodes$stale[graph_obj$nodes$file == script]
    if (length(script_stale) > 0 && script_stale) {
      "stale"
    } else {
      "fresh"
    }
  })

  state_vec <- unlist(state_list)
  
  # Count scripts by state
  fresh_count <- sum(state_vec == "fresh")
  stale_count <- sum(state_vec == "stale")
  
  # Display summary
  cat(paste0("\033[32m   ", fresh_count, " fresh script", if(fresh_count != 1) "s" else "", "\033[0m"))
  if (stale_count > 0) {
    cat(paste0(" - \033[33m", stale_count, " stale script", if(stale_count != 1) "s" else "", "\033[0m"))
  }
  cat("\n\n")

  # Calculate max script name width for alignment
  max_width <- max(nchar(scripts))

  # Display each script with status indicator
  for (i in seq_along(scripts)) {
    script <- scripts[i]
    state <- state_vec[i]
    
    if (state == "fresh") {
      cat(sprintf("\033[90m[OK] %-*s \033[2m(fresh)\033[0m\n", max_width, script))
    } else {
      cat(sprintf("\033[33m[!] %-*s \033[2m(stale)\033[0m\n", max_width, script))
    }
  }
  
  cat("\n")
}
