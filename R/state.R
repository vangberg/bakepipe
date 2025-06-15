#' Read pipeline state from disk
#'
#' Reads the .bakepipe.state file and computes current checksums to
#' determine which files are stale. A file is considered stale if its
#' current checksum differs from the stored checksum.
#'
#' @param state_file Path to the state file (typically ".bakepipe.state")
#' @return List where each file is a named element containing file information,
#'   plus a special 'stale_files' element containing character vector of stale files
#' @export  
read_state <- function(state_file) {
  # Initialize empty state if file doesn't exist
  if (!file.exists(state_file)) {
    return(list(
      stale_files = character(0)
    ))
  }

  # Read existing state file
  state_data <- read.csv(state_file, stringsAsFactors = FALSE)

  # Get current checksums for all files in state
  current_checksums <- character(0)
  for (file_path in state_data$file) {
    if (file.exists(file_path)) {
      current_checksums[file_path] <- compute_file_checksum(file_path)
    } else {
      current_checksums[file_path] <- NA_character_
    }
  }

  # Determine which files are stale based on checksum comparison
  stale_files <- character(0)
  for (i in seq_len(nrow(state_data))) {
    file_path <- state_data$file[i]
    stored_checksum <- state_data$checksum[i]
    current_checksum <- current_checksums[file_path]

    # File is stale if checksum differs or file is missing
    # Don't mark missing files as stale if they were stored as "missing"
    if (is.na(current_checksum) && stored_checksum != "missing") {
      stale_files <- c(stale_files, file_path)
    } else if (!is.na(current_checksum) &&
                 current_checksum != stored_checksum) {
      stale_files <- c(stale_files, file_path)
    }
  }

  # Create result list with file names as keys
  result <- list()
  
  # Add each file as a list element
  for (i in seq_len(nrow(state_data))) {
    file_path <- state_data$file[i]
    
    # Compute status based on staleness
    computed_status <- if (file_path %in% stale_files) "stale" else "fresh"
    
    result[[file_path]] <- list(
      checksum = state_data$checksum[i],
      last_modified = state_data$last_modified[i], 
      status = computed_status,
      current_checksum = current_checksums[file_path]
    )
  }
  
  result
}

#' Extract stale files from state object
#'
#' Helper function to get list of stale files from the new state format.
#'
#' @param state_obj State object from read_state()
#' @return Character vector of stale file names
#' @keywords internal
get_stale_files <- function(state_obj) {
  stale_files <- character(0)
  for (file_name in names(state_obj)) {
    if (is.list(state_obj[[file_name]]) && 
        !is.null(state_obj[[file_name]]$status) &&
        state_obj[[file_name]]$status == "stale") {
      stale_files <- c(stale_files, file_name)
    }
  }
  stale_files
}

#' Extract fresh files from state object
#'
#' Helper function to get list of fresh files from the new state format.
#'
#' @param state_obj State object from read_state()
#' @return Character vector of fresh file names
#' @keywords internal
get_fresh_files <- function(state_obj) {
  fresh_files <- character(0)
  for (file_name in names(state_obj)) {
    if (is.list(state_obj[[file_name]]) &&
          !is.null(state_obj[[file_name]]$status) &&
          state_obj[[file_name]]$status == "fresh") {
      fresh_files <- c(fresh_files, file_name)
    }
  }
  fresh_files
}

#' Write pipeline state to disk
#'
#' Writes the current state of all files in the pipeline to a CSV file.
#' This includes scripts and all their input/output files with their
#' current checksums and timestamps.
#'
#' @param state_file Path to the state file to write 
#'   (typically ".bakepipe.state")
#' @param parse_data Named list from parse() function containing 
#'   script dependencies
#' @export
write_state <- function(state_file, parse_data) {
  # Collect all unique files from parse_data
  all_files <- character(0)
  
  for (script_name in names(parse_data)) {
    script_data <- parse_data[[script_name]]
    all_files <- c(all_files, script_name)
    all_files <- c(all_files, script_data$inputs)
    all_files <- c(all_files, script_data$outputs)
  }

  all_files <- unique(all_files)

  # Create state data frame
  state_data <- data.frame(
    file = all_files,
    checksum = character(length(all_files)),
    last_modified = character(length(all_files)),
    stringsAsFactors = FALSE
  )

  # Compute checksums and timestamps for existing files
  for (i in seq_len(nrow(state_data))) {
    file_path <- state_data$file[i]

    if (file.exists(file_path)) {
      state_data$checksum[i] <- compute_file_checksum(file_path)
      file_info <- file.info(file_path)
      state_data$last_modified[i] <- as.character(file_info$mtime)
    } else {
      # For missing files, use placeholder checksum and current timestamp
      state_data$checksum[i] <- "missing"
      state_data$last_modified[i] <- as.character(Sys.time())
    }
  }

  # Write to CSV file
  write.csv(state_data, state_file, row.names = FALSE)
}

#' Compute MD5 checksum for a file
#'
#' @param file_path Path to the file
#' @return Character string containing the MD5 checksum
#' @keywords internal
compute_file_checksum <- function(file_path) {
  if (!file.exists(file_path)) {
    return(NA_character_)
  }

  # Use tools::md5sum for consistency with base R
  checksum <- tools::md5sum(file_path)
  as.character(checksum)
}