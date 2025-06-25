#' Show pipeline status
#'
#' Display the current state of all scripts in the pipeline (fresh/stale)
#'
#' @param verbose Logical. If TRUE (default), prints status information to console.
#' @return NULL (invisibly). This function is called for its side effect of
#'   displaying pipeline status information to the console.
#' @examples
#' # Copy sample project to temp directory  
#' temp_dir <- tempfile()
#' dir.create(temp_dir)
#' sample_proj <- system.file("extdata", "sample-project", package = "bakepipe")
#' file.copy(sample_proj, temp_dir, recursive = TRUE)
#' 
#' # Change to the sample project directory
#' old_wd <- getwd()
#' setwd(file.path(temp_dir, "sample-project"))
#' 
#' # Display current pipeline status
#' status()
#' 
#' # This will show which scripts are fresh (up-to-date) 
#' # and which are stale (need to be re-run)
#' 
#' # Restore working directory and clean up
#' setwd(old_wd)
#' unlink(temp_dir, recursive = TRUE)
#' @export
status <- function(verbose = TRUE) {
  # Parse the pipeline to get script dependencies
  pipeline_data <- parse()

  # Handle empty pipeline
  if (length(pipeline_data$scripts) == 0) {
    if (verbose) {
      message("\n[STATUS] \033[1;36mBakepipe Status\033[0m")
      message("\033[33m   No scripts found in pipeline\033[0m\n")
    }
    return(invisible(NULL))
  }

  # Display header and Scripts table with state information
  if (verbose) {
    message("\n[STATUS] \033[1;36mBakepipe Status\033[0m")
    display_scripts_table(pipeline_data)
  }

  invisible(NULL)
}

#' Display the scripts table
#' @param pipeline_data Parsed pipeline data
display_scripts_table <- function(pipeline_data) {
  # Read state information
  state_obj <- read_state(file.path(root(), ".bakepipe.state"))

  # Create graph with state information
  graph_obj <- graph(pipeline_data, state_obj)
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
  message(paste0("\033[32m   ", fresh_count, " fresh script", if(fresh_count != 1) "s" else "", "\033[0m"), appendLF = FALSE)
  if (stale_count > 0) {
    message(paste0(" - \033[33m", stale_count, " stale script", if(stale_count != 1) "s" else "", "\033[0m"), appendLF = FALSE)
  }
  message("\n")

  # Calculate max script name width for alignment
  max_width <- max(nchar(scripts))

  # Display each script with status indicator
  for (i in seq_along(scripts)) {
    script <- scripts[i]
    state <- state_vec[i]
    
    if (state == "fresh") {
      message(sprintf("\033[90m[OK] %-*s \033[2m(fresh)\033[0m", max_width, script))
    } else {
      message(sprintf("\033[33m[!] %-*s \033[2m(stale)\033[0m", max_width, script))
    }
  }
  
  message("")
}
