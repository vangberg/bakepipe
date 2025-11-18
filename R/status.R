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

  # Generate _targets.R file
  generate_targets_file()

  # Display header and Scripts table with state information
  if (verbose) {
    message("\n[STATUS] \033[1;36mBakepipe Status\033[0m")
    display_scripts_table_targets(pipeline_data)
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

#' Display the scripts table using targets backend
#' @param pipeline_data Parsed pipeline data
display_scripts_table_targets <- function(pipeline_data) {
  # Get outdated targets from targets package
  outdated <- tryCatch(
    {
      targets::tar_outdated(callr_function = NULL)
    },
    error = function(e) {
      # If targets hasn't run yet, all are outdated
      character(0)
    }
  )

  # Get script names in order they appear in pipeline_data
  script_names <- names(pipeline_data$scripts)
  
  # Create a map from output target names back to script names
  target_to_script <- setNames(script_names, sapply(script_names, function(s) {
    path_to_target_name(s, "output")
  }))

  # Determine state for each script based on output target
  state_vec <- character(length(script_names))
  for (i in seq_along(script_names)) {
    script <- script_names[i]
    # Convert script name to output target name
    target_name <- path_to_target_name(script, "output")

    # Check if this output target is outdated
    if (target_name %in% outdated) {
      state_vec[i] <- "stale"
    } else {
      state_vec[i] <- "fresh"
    }
  }

  # Count scripts by state
  fresh_count <- sum(state_vec == "fresh")
  stale_count <- sum(state_vec == "stale")

  # Display summary
  message(paste0(
    "\033[32m   ", fresh_count, " fresh script",
    if (fresh_count != 1) "s" else "", "\033[0m"
  ), appendLF = FALSE)
  if (stale_count > 0) {
    message(paste0(
      " - \033[33m", stale_count, " stale script",
      if (stale_count != 1) "s" else "", "\033[0m"
    ), appendLF = FALSE)
  }
  message("\n")

  # Calculate max script name width for alignment
  max_width <- max(nchar(script_names))

  # Display each script with status indicator, inputs, outputs, and externals
  for (i in seq_along(script_names)) {
    script <- script_names[i]
    state <- state_vec[i]
    script_info <- pipeline_data$scripts[[script]]
    
    # Determine staleness of inputs from other scripts
    input_states <- character(0)
    
    # Check input files from other scripts
    for (input_file in script_info$inputs) {
      for (producer_script in script_names) {
        if (input_file %in% pipeline_data$scripts[[producer_script]]$outputs) {
          input_target_name <- path_to_target_name(producer_script, "output")
          if (input_target_name %in% outdated) {
            input_states <- c(input_states, sprintf("%s \033[33m(stale)\033[0m", input_file))
          } else {
            input_states <- c(input_states, sprintf("%s \033[32m(fresh)\033[0m", input_file))
          }
          break
        }
      }
    }
    
    # Determine staleness of externals
    external_states <- character(0)
    
    for (ext_file in script_info$externals) {
      ext_target_name <- path_to_target_name(ext_file, "")
      if (ext_target_name %in% outdated) {
        external_states <- c(external_states, sprintf("%s \033[33m(stale)\033[0m", ext_file))
      } else {
        external_states <- c(external_states, sprintf("%s \033[32m(fresh)\033[0m", ext_file))
      }
    }
    
    # Determine staleness of outputs
    output_states <- character(0)
    for (output_file in script_info$outputs) {
      output_target_name <- path_to_target_name(script, "output")
      if (output_target_name %in% outdated) {
        output_states <- c(output_states, sprintf("%s \033[33m(stale)\033[0m", output_file))
      } else {
        output_states <- c(output_states, sprintf("%s \033[32m(fresh)\033[0m", output_file))
      }
    }

    if (state == "fresh") {
      message(sprintf(
        "\033[90m[OK] %-*s \033[32m(fresh)\033[0m",
        max_width, script
      ))
    } else {
      message(sprintf(
        "\033[33m[!] %-*s \033[33m(stale)\033[0m",
        max_width, script
      ))
    }
    
    # Display inputs as nested list
    if (length(input_states) > 0) {
      message("       inputs:")
      for (input_item in input_states) {
        message(sprintf("         - %s", input_item))
      }
    } else {
      message("       inputs: (none)")
    }
    
    # Display externals as nested list
    if (length(external_states) > 0) {
      message("       externals:")
      for (ext_item in external_states) {
        message(sprintf("         - %s", ext_item))
      }
    } else {
      message("       externals: (none)")
    }
    
    # Display outputs as nested list
    if (length(output_states) > 0) {
      message("       outputs:")
      for (output_item in output_states) {
        message(sprintf("         - %s", output_item))
      }
    } else {
      message("       outputs: (none)")
    }
  }

  message("")
}
